import Testing
import Foundation
@testable import PerfectCRUD

/// Thread-safe mutable box for test state captured by `@Sendable` migration
/// closures. These closures run strictly sequentially in every test here,
/// but `@Sendable` requires provable safety, not "happens to be sequential."
private final class Box<T>: @unchecked Sendable {
	private let lock = NSLock()
	private var value: T
	init(_ value: T) { self.value = value }
	func get() -> T { lock.lock(); defer { lock.unlock() }; return value }
	func set(_ newValue: T) { lock.lock(); defer { lock.unlock() }; value = newValue }
	func mutate(_ body: (inout T) -> Void) { lock.lock(); defer { lock.unlock() }; body(&value) }
}

@Suite("DatabaseMigrator")
struct MigrationTests {

	private func makeMigrationDB() throws -> Database<StatefulStubConfig> {
		Database(configuration: try StatefulStubConfig())
	}

	@Test("migrations apply in registration order, not lexical order")
	func appliesInRegistrationOrder() throws {
		let db = try makeMigrationDB()
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		let applied = Box<[String]>([])

		// Registered deliberately out of "logical" (lexical) order.
		try migrator.register("z_last") { _ in applied.mutate { $0.append("z_last") } }
		try migrator.register("a_first") { _ in applied.mutate { $0.append("a_first") } }
		try migrator.register("m_middle") { _ in applied.mutate { $0.append("m_middle") } }

		let newly = try migrator.migrate(db)
		#expect(newly == ["z_last", "a_first", "m_middle"])
		#expect(applied.get() == ["z_last", "a_first", "m_middle"])
	}

	@Test("registering a duplicate identifier throws")
	func duplicateIdentifierRejected() throws {
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		try migrator.register("only_once") { _ in }
		#expect(throws: CRUDSQLGenError.self) {
			try migrator.register("only_once") { _ in }
		}
	}

	@Test("already-applied migrations are not re-run")
	func alreadyAppliedFiltered() throws {
		let db = try makeMigrationDB()
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		let runCount = Box(0)
		try migrator.register("idempotency_check") { _ in runCount.mutate { $0 += 1 } }

		let firstRun = try migrator.migrate(db)
		let secondRun = try migrator.migrate(db)

		#expect(firstRun == ["idempotency_check"])
		#expect(secondRun == [])
		#expect(runCount.get() == 1)
	}

	@Test("a fresh migrator instance against a partially-migrated database only applies what's missing")
	func partialApplyThenResume() throws {
		let db = try makeMigrationDB()
		let applied = Box<[String]>([])

		let firstMigrator = DatabaseMigrator<StatefulStubConfig>()
		try firstMigrator.register("step_1") { _ in applied.mutate { $0.append("step_1") } }
		try firstMigrator.register("step_2") { _ in applied.mutate { $0.append("step_2") } }
		_ = try firstMigrator.migrate(db)

		// A completely fresh migrator instance -- proves state lives in the
		// database's tracking table, not in the DatabaseMigrator object.
		let secondMigrator = DatabaseMigrator<StatefulStubConfig>()
		try secondMigrator.register("step_1") { _ in applied.mutate { $0.append("step_1") } }
		try secondMigrator.register("step_2") { _ in applied.mutate { $0.append("step_2") } }
		try secondMigrator.register("step_3") { _ in applied.mutate { $0.append("step_3") } }
		let newly = try secondMigrator.migrate(db)

		#expect(newly == ["step_3"])
		#expect(applied.get() == ["step_1", "step_2", "step_3"])
	}

	@Test("a failing migration rolls back its own transaction and leaves no tracking row, so a retry re-attempts it")
	func failureMidMigrationLeavesNoTrackingRow() throws {
		let db = try makeMigrationDB()
		struct Boom: Error {}
		let attempts = Box(0)

		let migrator = DatabaseMigrator<StatefulStubConfig>()
		try migrator.register("flaky") { _ in
			attempts.mutate { $0 += 1 }
			if attempts.get() == 1 { throw Boom() }
		}

		#expect(throws: Boom.self) { try migrator.migrate(db) }
		#expect(attempts.get() == 1)

		// Retry: no tracking row was left behind by the failed attempt, so
		// this must actually re-run the migration, not silently no-op.
		let newly = try migrator.migrate(db)
		#expect(newly == ["flaky"])
		#expect(attempts.get() == 2)
	}

	@Test("rollbackLast throws when nothing has been applied")
	func rollbackLastWithNothingAppliedThrows() throws {
		let db = try makeMigrationDB()
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		try migrator.register("never_applied") { _ in }
		#expect(throws: CRUDSQLGenError.self) {
			try migrator.rollbackLast(db)
		}
	}

	@Test("rollbackLast throws when the applied migration has no down")
	func rollbackLastWithNoDownThrows() throws {
		let db = try makeMigrationDB()
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		try migrator.register("no_down_provided") { _ in } // no `down` argument
		_ = try migrator.migrate(db)
		#expect(throws: CRUDSQLGenError.self) {
			try migrator.rollbackLast(db)
		}
	}

	// Note: `StatefulStubExeDelegate` only simulates INSERT and SELECT, not
	// DELETE (see its doc comment) -- so this proves rollbackLast() finds
	// the right migration, calls its `down`, and returns its identifier,
	// but does NOT prove the tracking row is actually removed from a real
	// database. That's exactly the gap ADR-0001's implementation plan
	// flags as deferred to a real SQLite-backed integration test.
	@Test("rollbackLast succeeds and runs the down closure when a down is provided")
	func rollbackLastRunsDownClosure() throws {
		let db = try makeMigrationDB()
		let downRan = Box(false)
		let migrator = DatabaseMigrator<StatefulStubConfig>()
		try migrator.register("reversible", up: { _ in }, down: { _ in downRan.set(true) })
		_ = try migrator.migrate(db)

		let rolledBack = try migrator.rollbackLast(db)
		#expect(rolledBack == "reversible")
		#expect(downRan.get() == true)
	}
}
