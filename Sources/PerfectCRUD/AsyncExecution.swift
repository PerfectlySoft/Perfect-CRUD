//
//  AsyncExecution.swift
//  PerfectCRUD
//
//  Shared blocking-dispatch primitive for moving synchronous, blocking
//  connector work (opening a connection, running a query) off whatever
//  executor called into PerfectCRUD -- critically, off Swift's default
//  cooperative thread pool, which must never block on C-library I/O
//  (libmysqlclient/libpq/sqlite3 have no async story of their own).
//
//  Introduced in Phase 1 (ADR-0001) for DatabaseConnectionPool's connection
//  creation, and reused as-is by Phase 2's async Database/Table/Selectable
//  overloads. Continuation-based dispatch, not a custom TaskExecutor: per
//  ADR-0001's implementation-plan review, the two approaches are equally
//  safe here, and this one is simpler, keeps the caller's own task
//  suspended (no extra unstructured Task per call), and gets the Swift
//  runtime's double-resume/never-resumed detection for free.
//
//  Cancellation is best-effort only: neither this design nor a custom
//  TaskExecutor can interrupt a blocking C call already in flight -- there
//  is no suspension point inside e.g. mysql_stmt_execute() for Swift's
//  cooperative cancellation to act on. A cancelled caller's task simply
//  keeps waiting for the underlying work to finish.
//

import Dispatch

enum CRUDBlockingQueue {
	static let shared = DispatchQueue(label: "PerfectCRUD.blocking", qos: .userInitiated, attributes: .concurrent)
}

func withCRUDExecutor<T: Sendable>(_ body: @Sendable @escaping () throws -> T) async throws -> T {
	try await withCheckedThrowingContinuation { continuation in
		CRUDBlockingQueue.shared.async {
			do {
				continuation.resume(returning: try body())
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
}

// MARK: - Async surface (Phase 2)
//
// **Deviates from ADR-0001's original implementation plan, which called for
// overloading by `async` presence (same name, resolved by call-site
// `await`) rather than renaming.** That assumption was verified wrong by
// direct testing against this toolchain (Swift 6.2, strict concurrency): in
// an isolated minimal reproduction, calling a sync method with no `await`
// from inside an `async` function, while an identically-named `async`
// overload also exists *anywhere in scope* (even with matching generic
// constraints, even declared directly in the same struct with no
// extensions involved), fails to compile -- Swift requires `await` and
// does not silently prefer the sync candidate. Confirmed reproducible
// twice, independent of the extra `Sendable` constraints these particular
// overloads happen to need.
//
// This matters concretely: `PerfectNIOCRUD.Routes.db()`'s route-handler
// closures are already `async throws` (Phase 1 and earlier). Any existing
// caller inside one of those closures that invokes e.g. `table.first()`
// synchronously, with no `await`, would have broken the moment an
// identically-named async `first()` was added anywhere -- the exact
// "zero source breaks" guarantee the ADR is built around. So: every async
// method below that has an existing sync counterpart gets an `Async`
// suffix, which sidesteps the ambiguity entirely rather than relying on
// disambiguation that doesn't actually hold. `fetchAll()` has no sync
// counterpart to collide with, so it keeps its plain name.
//
// `Select`'s lazy `Sequence` conformance is deliberately left alone: making
// it an `AsyncSequence` would mean suspending mid-cursor across a raw C
// statement handle bound to one OS thread, a real correctness hazard.
// `fetchAll()` below keeps the fetch itself synchronous, inside the
// executor -- only the hop on/off the calling task is async, matching how
// GRDB's and SQLAlchemy's async layers actually work under the hood.
//
// Async insert/update/delete return `Void`, not `Insert<Form,Table>`/
// `Update<...>`/`Delete<...>` the way their sync counterparts do: those
// command types carry a `SQLGenState` (which nests `Codable`/`Any.Type`
// existentials with no Sendable story) and have no public API beyond being
// `@discardableResult` today, so requiring them to cross the executor
// boundary would mean solving a much larger Sendable problem for zero
// actual caller value. Revisit if a real use for the returned command value
// ever appears.

public extension Database where C: Sendable {
	func transactionAsync<T: Sendable>(isolation: TransactionIsolationLevel? = nil,
										_ body: @Sendable @escaping () throws -> T) async throws -> T {
		try await withCRUDExecutor { try self.transaction(isolation: isolation, body) }
	}
	func sqlAsync(_ sql: String, bindings: Bindings = []) async throws {
		try await withCRUDExecutor { try self.sql(sql, bindings: bindings) }
	}
	func sqlAsync<A: Codable & Sendable>(_ sql: String, bindings: Bindings = [], _ type: A.Type) async throws -> [A] {
		try await withCRUDExecutor { try self.sql(sql, bindings: bindings, type) }
	}
}

public extension Selectable where Self: Sendable, OverAllForm: Sendable {
	func firstAsync() async throws -> OverAllForm? {
		try await withCRUDExecutor { try self.first() }
	}
	/// Collects the full result set. No sync equivalent -- see this file's
	/// header comment for why `Select`'s `Sequence` conformance isn't made
	/// `async` directly, and why this one keeps its plain name (no
	/// collision to avoid).
	func fetchAll() async throws -> [OverAllForm] {
		try await withCRUDExecutor { Array(try self.select()) }
	}
}

public extension Selectable where Self: Sendable & Limitable, OverAllForm: Sendable {
	func firstAsync() async throws -> OverAllForm? {
		try await withCRUDExecutor { try self.first() }
	}
}

public extension Table where A: Codable & Sendable, C: Sendable {
	// The result is explicitly discarded (`_ =`) inside the closure, not just
	// left as `@discardableResult` -- `withCRUDExecutor<T: Sendable>` would
	// otherwise infer T as the sync method's actual return type
	// (Insert<Form,Table>, not Sendable -- see this file's header comment),
	// not Void.
	func insertAsync(_ instance: Form) async throws {
		try await withCRUDExecutor { _ = try self.insert(instance) }
	}
	func insertAsync(_ instances: [Form]) async throws {
		try await withCRUDExecutor { _ = try self.insert(instances) }
	}
}

public extension Updatable where Self: Sendable, OverAllForm: Sendable {
	func updateAsync(_ instance: OverAllForm) async throws {
		try await withCRUDExecutor { _ = try self.update(instance) }
	}
}

public extension Deleteable where Self: Sendable {
	func deleteAsync() async throws {
		try await withCRUDExecutor { _ = try self.delete() }
	}
}
