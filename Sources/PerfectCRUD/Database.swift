//
//  PerfectCRUDDatabase.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

/// Tracks transaction nesting depth for one `Database` value (see
/// `Database.transactionDepth`'s doc comment for why it's per-value, not
/// per-physical-connection). `NSLock`-guarded rather than an `actor`:
/// `transaction()` must stay synchronous (its non-nested behavior is
/// byte-for-byte unchanged from before nesting support existed), and an
/// actor's isolated methods can't be called without `await`. The lock is
/// load-bearing, not defensive paranoia -- `Database` is `Sendable`
/// (conditionally, on `C: Sendable`), so nothing prevents a caller from
/// using one checked-out `Database` value concurrently from two tasks.
final class CRUDTransactionDepth: @unchecked Sendable {
	private let lock = NSLock()
	private var depth = 0
	func increment() -> Int {
		lock.lock(); defer { lock.unlock() }
		depth += 1
		return depth
	}
	func decrement() {
		lock.lock(); defer { lock.unlock() }
		depth -= 1
	}
}

public struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	public typealias Configuration = C
	public let configuration: Configuration
	// One box per `Database` value (created fresh in `init`, then shared by
	// every copy of that value via the class reference) -- not global, and
	// not per-physical-connection either. This self-heals across a
	// connection-pool checkout/checkin cycle: `DatabaseConnectionPool`
	// constructs a fresh `Database<C>` per checkout (see Pool.swift), so a
	// bug that somehow left a prior checkout's depth non-zero can't leak
	// into the next caller -- that `Database` value, and its depth box, are
	// simply discarded, not reused.
	let transactionDepth = CRUDTransactionDepth()
	public init(configuration c: Configuration) {
		configuration = c
	}
	public func table<T: Codable>(_ form: T.Type) -> Table<T, Database> {
		return .init(database: self)
	}
}

extension Database: Sendable where C: Sendable {}

public extension Database {
	func sql(_ sql: String, bindings: Bindings = []) throws {
		CRUDLogging.log(.query, sql)
		let delegate = try configuration.sqlExeDelegate(forSQL: sql)
		try delegate.bind(bindings, skip: 0)
		_ = try delegate.hasNext()
	}
	func sql<A: Codable>(_ sql: String, bindings: Bindings = [], _ type: A.Type) throws -> [A] {
		CRUDLogging.log(.query, sql)
		let delegate = try configuration.sqlExeDelegate(forSQL: sql)
		try delegate.bind(bindings, skip: 0)
		var ret: [A] = []
		while try delegate.hasNext() {
			let rowDecoder: CRUDRowDecoder<ColumnKey> = CRUDRowDecoder(delegate: delegate)
			ret.append(try A(from: rowDecoder))
		}
		return ret
	}
}

public extension Database {
	/// Runs `body` inside a transaction (or, if already inside one on this
	/// same `Database` value, a `SAVEPOINT`). Top-level (non-nested) calls
	/// are byte-for-byte unchanged from before nesting support existed:
	/// `BEGIN`/`COMMIT`/`ROLLBACK`, nothing more. `isolation` is only
	/// consulted at the outermost level -- nested `SAVEPOINT`s don't have
	/// their own isolation level in standard SQL -- and only takes effect on
	/// connectors whose `SQLGenDelegate.setIsolationLevelSQL(_:)` returns
	/// non-`nil`; it's a silent no-op otherwise.
	func transaction<T>(isolation: TransactionIsolationLevel? = nil, _ body: () throws -> T) throws -> T {
		let depth = transactionDepth.increment()
		defer { transactionDepth.decrement() }
		if depth == 1 {
			if let isolation, let isolationSQL = configuration.sqlGenDelegate.setIsolationLevelSQL(isolation) {
				try sql(isolationSQL)
			}
			try sql("BEGIN")
		} else {
			try sql("SAVEPOINT crud_sp_\(depth)")
		}
		do {
			let r = try body()
			try sql(depth == 1 ? "COMMIT" : "RELEASE SAVEPOINT crud_sp_\(depth)")
			return r
		} catch {
			// Matches pre-nesting behavior exactly at depth == 1: if the
			// rollback itself throws, that error propagates (not `error`) --
			// not `try?`'d away, so this isn't a silent behavior change.
			try sql(depth == 1 ? "ROLLBACK" : "ROLLBACK TO SAVEPOINT crud_sp_\(depth)")
			throw error
		}
	}
}
