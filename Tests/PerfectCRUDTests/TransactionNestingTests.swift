import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - Stub connector with SQL capture
//
// Pure SQL-shape assertions only -- proving *what PerfectCRUD emits* at each
// transaction depth, not that a real database actually honors SAVEPOINT/
// ROLLBACK TO semantics (that's database-engine behavior a stub can't fake
// without effectively reimplementing a transaction engine; per ADR-0001's
// implementation-plan review, real rollback behavior belongs in a connector
// package's own integration tests, not here).

private final class TxnStubGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	var isolationLevelRequested: TransactionIsolationLevel?
	func getBinding(for expr: CRUDExpression) throws -> String { "?" }
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
	func setIsolationLevelSQL(_ level: TransactionIsolationLevel) -> String? {
		isolationLevelRequested = level
		return "SET TRANSACTION ISOLATION LEVEL \(level)"
	}
}

private struct TxnStubExeDelegate: SQLExeDelegate {
	func bind(_ bindings: Bindings, skip: Int) throws {}
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

private final class TxnStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let generator = TxnStubGenDelegate()
	var capturedSQL: [String] = []

	var sqlGenDelegate: SQLGenDelegate { generator }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		capturedSQL.append(sql)
		return TxnStubExeDelegate()
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

private func makeTxnDB() throws -> (Database<TxnStubConfig>, TxnStubConfig) {
	let config = try TxnStubConfig()
	return (Database(configuration: config), config)
}

@Suite("Transaction nesting and isolation")
struct TransactionNestingTests {

	@Test("a top-level (non-nested) transaction is byte-for-byte unchanged: BEGIN/COMMIT only")
	func topLevelUnchanged() throws {
		let (db, config) = try makeTxnDB()
		try db.transaction { }
		#expect(config.capturedSQL == ["BEGIN", "COMMIT"])
	}

	@Test("a top-level transaction that throws emits BEGIN/ROLLBACK, not COMMIT")
	func topLevelRollbackOnThrow() {
		struct Boom: Error {}
		let (db, config) = try! makeTxnDB()
		#expect(throws: Boom.self) {
			try db.transaction { throw Boom() }
		}
		#expect(config.capturedSQL == ["BEGIN", "ROLLBACK"])
	}

	@Test("a nested transaction emits SAVEPOINT/RELEASE SAVEPOINT, not a second BEGIN")
	func nestedEmitsSavepoint() throws {
		let (db, config) = try makeTxnDB()
		try db.transaction {
			try db.transaction { }
		}
		#expect(config.capturedSQL == ["BEGIN", "SAVEPOINT crud_sp_2", "RELEASE SAVEPOINT crud_sp_2", "COMMIT"])
	}

	@Test("a failing nested transaction rolls back only to its savepoint, not the whole outer transaction")
	func nestedRollbackToSavepoint() throws {
		struct Boom: Error {}
		let (db, config) = try makeTxnDB()
		// The outer transaction itself succeeds -- only the inner one throws,
		// and the outer body catches it, so the outer still COMMITs.
		try db.transaction {
			#expect(throws: Boom.self) {
				try db.transaction { throw Boom() }
			}
		}
		#expect(config.capturedSQL == [
			"BEGIN",
			"SAVEPOINT crud_sp_2",
			"ROLLBACK TO SAVEPOINT crud_sp_2",
			"COMMIT",
		])
	}

	@Test("three levels of nesting number savepoints by depth")
	func threeLevelsNumberedByDepth() throws {
		let (db, config) = try makeTxnDB()
		try db.transaction {
			try db.transaction {
				try db.transaction { }
			}
		}
		#expect(config.capturedSQL == [
			"BEGIN",
			"SAVEPOINT crud_sp_2",
			"SAVEPOINT crud_sp_3",
			"RELEASE SAVEPOINT crud_sp_3",
			"RELEASE SAVEPOINT crud_sp_2",
			"COMMIT",
		])
	}

	@Test("depth self-heals: after a failed inner transaction, a later top-level transaction on the same Database value still emits plain BEGIN")
	func depthSelfHealsAfterFailure() throws {
		struct Boom: Error {}
		let (db, config) = try makeTxnDB()

		try db.transaction {
			#expect(throws: Boom.self) {
				try db.transaction { throw Boom() }
			}
		}
		config.capturedSQL.removeAll()

		// A completely separate, later top-level transaction -- proves
		// increment/decrement is `defer`-paired (not success-path-only),
		// so a prior failure doesn't permanently wedge this Database value
		// into always emitting SAVEPOINT instead of BEGIN.
		try db.transaction { }
		#expect(config.capturedSQL == ["BEGIN", "COMMIT"])
	}

	@Test("isolation level SQL is only emitted at depth == 1, and only when requested")
	func isolationLevelOnlyAtTopLevel() throws {
		let (db, config) = try makeTxnDB()
		try db.transaction(isolation: .serializable) {
			try db.transaction { } // nested -- must NOT re-request isolation
		}
		#expect(config.generator.isolationLevelRequested == .serializable)
		#expect(config.capturedSQL == [
			"SET TRANSACTION ISOLATION LEVEL serializable",
			"BEGIN",
			"SAVEPOINT crud_sp_2",
			"RELEASE SAVEPOINT crud_sp_2",
			"COMMIT",
		])
	}

	@Test("no isolation requested means no isolation SQL at all")
	func noIsolationRequestedMeansNoSQL() throws {
		let (db, config) = try makeTxnDB()
		try db.transaction { }
		#expect(config.generator.isolationLevelRequested == nil)
		#expect(config.capturedSQL == ["BEGIN", "COMMIT"])
	}

	@Test("SQLGenDelegate's default setIsolationLevelSQL is a no-op (connectors that don't implement it stay silent)")
	func defaultIsolationIsNoOp() {
		struct DefaultDelegate: SQLGenDelegate {
			var bindings: Bindings = []
			func getBinding(for expr: CRUDExpression) throws -> String { "?" }
			func quote(identifier: String) throws -> String { identifier }
			func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
			func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
		}
		#expect(DefaultDelegate().setIsolationLevelSQL(.serializable) == nil)
	}

	@Test("transactionAsync produces identical SQL to the sync transaction()")
	func asyncTransactionMatchesSyncShape() async throws {
		let (db, config) = try makeTxnDB()
		_ = try await db.transactionAsync { 42 }
		#expect(config.capturedSQL == ["BEGIN", "COMMIT"])
	}
}
