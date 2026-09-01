import Testing
import Foundation
import Dispatch
@testable import PerfectCRUD

@Suite("Async execution boundary")
struct AsyncExecutionTests {

	@Test("withCRUDExecutor's body genuinely runs on CRUDBlockingQueue, not just off the caller's thread")
	func executorRoutesThroughBlockingQueue() async throws {
		// A DispatchSpecificKey set on the queue itself is a direct, deterministic
		// proof of which queue is executing -- unlike inferring from Thread.current,
		// which can't distinguish "off the cooperative pool" from "coincidentally
		// the same OS thread as some other pool."
		let key = DispatchSpecificKey<Bool>()
		CRUDBlockingQueue.shared.setSpecific(key: key, value: true)

		let onQueue = try await withCRUDExecutor { () -> Bool in
			DispatchQueue.getSpecific(key: key) ?? false
		}
		#expect(onQueue == true)
	}

	@Test("a thrown error inside the body propagates through the continuation")
	func errorPropagates() async throws {
		struct Boom: Error, Equatable {}
		await #expect(throws: Boom.self) {
			try await withCRUDExecutor { throw Boom() }
		}
	}

	@Test("the sync API is untouched, and the renamed *Async twin is independently callable")
	func syncApiUntouchedAndAsyncTwinWorks() async throws {
		// Compile-time proof: `sqlAsync` (not an overload of `sql`) is what
		// makes this reliable -- see AsyncExecution.swift's header comment
		// for why plain overloading-by-async was tried and reverted. No
		// server/connector needed since these are structural stubs.
		let config = try AsyncStubConfig()
		let db = Database(configuration: config)

		// Sync -- completely unaffected by Phase 2, same call as always.
		try db.sql("SELECT 1")

		// Async -- distinct name, no ambiguity with the sync method above.
		try await db.sqlAsync("SELECT 1")
	}
}

// MARK: - Minimal Sendable stub for compile-time / dispatch-proof tests
// (doesn't need real row data -- these tests only exercise the async
// dispatch plumbing, not query semantics).

private final class AsyncStubGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	func getBinding(for expr: CRUDExpression) throws -> String { "?" }
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
}

private struct AsyncStubExeDelegate: SQLExeDelegate {
	func bind(_ bindings: Bindings, skip: Int) throws {}
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

private final class AsyncStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { AsyncStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate { AsyncStubExeDelegate() }
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}
