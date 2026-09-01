import Testing
import Foundation
import Dispatch
@testable import PerfectCRUD

// MARK: - Stub connector

private final class PoolStubGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	func getBinding(for expr: CRUDExpression) throws -> String { "?" }
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
}

private struct PoolStubExeDelegate: SQLExeDelegate {
	func bind(_ bindings: Bindings, skip: Int) throws {}
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

/// A distinct `id` per instance lets tests confirm the pool is actually
/// reusing/checking-out real connection identities, not just any value.
private final class PoolStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let id: Int
	init(id: Int) { self.id = id }
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {
		id = -1
	}
	var sqlGenDelegate: SQLGenDelegate { PoolStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate { PoolStubExeDelegate() }
}

// MARK: - Test suite

@Suite("DatabaseConnectionPool")
struct PoolTests {

	@Test("sequential acquire/release reuses the same connection identity")
	func sequentialReuse() async throws {
		let nextID = Counter()
		let pool = try DatabaseConnectionPool(
			configuration: .init(minConnections: 0, maxConnections: 3),
			makeConnection: { PoolStubConfig(id: nextID.next()) }
		)

		let firstID = try await pool.withConnection { db in db.configuration.id }
		let secondID = try await pool.withConnection { db in db.configuration.id }

		#expect(firstID == secondID) // same connection checked back in and reused
		#expect(await pool.currentSize == 1)
	}

	@Test("minConnections pre-warms exactly that many connections")
	func prewarming() async throws {
		let nextID = Counter()
		let pool = try DatabaseConnectionPool(
			configuration: .init(minConnections: 3, maxConnections: 5),
			makeConnection: { PoolStubConfig(id: nextID.next()) }
		)
		try await pool.prewarm()
		#expect(await pool.currentSize == 3)
		#expect(await pool.availableCount == 3)
	}

	@Test("a thrown error inside the body still checks the connection back in")
	func errorStillReleases() async throws {
		struct Boom: Error {}
		let nextID = Counter()
		let pool = try DatabaseConnectionPool(
			configuration: .init(minConnections: 0, maxConnections: 2),
			makeConnection: { PoolStubConfig(id: nextID.next()) }
		)

		await #expect(throws: Boom.self) {
			try await pool.withConnection { _ in throw Boom() }
		}

		#expect(await pool.availableCount == 1)
		#expect(await pool.currentSize == 1)
	}

	@Test("concurrent withConnection calls beyond maxConnections queue and are served FIFO", .timeLimit(.minutes(1)))
	func concurrentCheckoutsQueueInOrder() async throws {
		let nextID = Counter()
		let pool = try DatabaseConnectionPool(
			configuration: .init(minConnections: 0, maxConnections: 1),
			makeConnection: { PoolStubConfig(id: nextID.next()) }
		)

		// Task 1 holds the pool's only connection until we explicitly let it go,
		// via a gate the test controls -- no sleeps, no timing guesses.
		let holderReady = Gate()
		let releaseHolder = Gate()
		let order = OrderLog()

		let holderTask = Task {
			try await pool.withConnection { _ in
				await holderReady.open()
				await releaseHolder.wait()
			}
		}
		await holderReady.wait()

		// Two more callers now queue behind the held connection. Start them in a
		// known order and poll `waitingCount` (the internal testability seam)
		// until both have genuinely registered as waiters -- no sleep-based guess.
		let waiterATask = Task {
			try await pool.withConnection { _ in await order.record("A") }
		}
		while await pool.waitingCount < 1 { await Task.yield() }

		let waiterBTask = Task {
			try await pool.withConnection { _ in await order.record("B") }
		}
		while await pool.waitingCount < 2 { await Task.yield() }

		await releaseHolder.open()
		try await holderTask.value
		try await waiterATask.value
		try await waiterBTask.value

		#expect(await order.entries == ["A", "B"])
	}

	@Test("task cancellation while waiting doesn't leak a slot", .timeLimit(.minutes(1)))
	func cancellationDoesNotLeakASlot() async throws {
		let nextID = Counter()
		let pool = try DatabaseConnectionPool(
			configuration: .init(minConnections: 0, maxConnections: 1),
			makeConnection: { PoolStubConfig(id: nextID.next()) }
		)

		let holderReady = Gate()
		let releaseHolder = Gate()

		let holderTask = Task {
			try await pool.withConnection { _ in
				await holderReady.open()
				await releaseHolder.wait()
			}
		}
		await holderReady.wait()

		let waiterTask = Task {
			try await pool.withConnection { _ in () }
		}
		while await pool.waitingCount < 1 { await Task.yield() }

		waiterTask.cancel()
		var caughtCancellation = false
		do {
			try await waiterTask.value
		} catch is CancellationError {
			caughtCancellation = true
		}
		#expect(caughtCancellation)

		// The cancelled waiter must not have left a phantom entry behind --
		// a fresh caller after it should queue cleanly (waitingCount back to 0)
		// and be served once the original holder releases.
		#expect(await pool.waitingCount == 0)

		await releaseHolder.open()
		try await holderTask.value
		#expect(await pool.availableCount == 1)
	}
}

// MARK: - Test helpers (actor-isolated, no data races, no sleeps)

private final class Counter: @unchecked Sendable {
	private let lock = NSLock()
	private var value = 0
	func next() -> Int {
		lock.lock(); defer { lock.unlock() }
		value += 1
		return value
	}
}

private actor OrderLog {
	private(set) var entries: [String] = []
	func record(_ entry: String) { entries.append(entry) }
}

/// A single-fire, single-waiter gate for coordinating test tasks without
/// sleeps or arbitrary timing assumptions.
private actor Gate {
	private var isOpen = false
	private var continuation: CheckedContinuation<Void, Never>?

	func open() {
		isOpen = true
		continuation?.resume()
		continuation = nil
	}

	func wait() async {
		if isOpen { return }
		await withCheckedContinuation { continuation = $0 }
	}
}
