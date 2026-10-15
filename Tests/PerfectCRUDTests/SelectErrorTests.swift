import Testing
import Foundation
@testable import PerfectCRUD

// A failed query or a row that can't be decoded used to vanish: SelectIterator.next() and
// Select.makeIterator() log the error and end the sequence. fetchAll() went through both, so it
// returned the rows before the bad one; first() went through makeIterator(), so a query that
// failed, or a join whose child rows didn't decode, returned nil. These tests use only API that
// already existed in 3.0.1; all but firstThrowsOnUndecodableRow, typedSQLThrowsOnUndecodableRow
// and forInStopsAtTheFirstError (which guard behaviour 3.0.1 already had) fail against it.

struct SelectErrorRow: Codable, Equatable {
	var id: Int
	var name: String
}

struct SelectErrorKid: Codable {
	var id: Int
	var parentId: Int
}

struct SelectErrorParent: Codable {
	var id: Int
	var kids: [SelectErrorKid]?
}

/// Three rows: good, one whose `name` isn't a string (so it can't decode), good.
func goodBadGoodDatabase() throws -> Database<StatefulStubConfig> {
	CRUDClearTableStructureCache()
	let config = try StatefulStubConfig()
	config.store.insert(table: "SelectErrorRow", row: ["id": .integer(1), "name": .string("a")])
	config.store.insert(table: "SelectErrorRow", row: ["id": .integer(2), "name": .integer(5)])
	config.store.insert(table: "SelectErrorRow", row: ["id": .integer(3), "name": .string("c")])
	return Database(configuration: config)
}

/// One parent, whose joined children are good, bad (`id` isn't an integer), good.
func badChildDatabase() throws -> Database<StatefulStubConfig> {
	CRUDClearTableStructureCache()
	let config = try StatefulStubConfig()
	config.store.insert(table: "SelectErrorParent", row: ["id": .integer(1)])
	config.store.insert(table: "SelectErrorKid", row: ["id": .integer(1), "parentId": .integer(1)])
	config.store.insert(table: "SelectErrorKid", row: ["id": .string("x"), "parentId": .integer(1)])
	config.store.insert(table: "SelectErrorKid", row: ["id": .integer(3), "parentId": .integer(1)])
	return Database(configuration: config)
}

struct ExeDelegateFailure: Error {}

/// A connector whose every query fails before returning a delegate, as bad SQL or a lost
/// connection would.
final class FailingExeConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		throw ExeDelegateFailure()
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

@Suite("Select errors reach first() and fetchAll()", .serialized)
struct SelectErrorTests {

	// first() already threw here in 3.0.1 (it used nextElement()); kept as a guard.
	@Test func firstThrowsOnUndecodableRow() throws {
		let db = try goodBadGoodDatabase()
		// The stub ignores WHERE, so the bad row is the second one returned.
		#expect(try db.table(SelectErrorRow.self).first() == SelectErrorRow(id: 1, name: "a"))
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		config.store.insert(table: "SelectErrorRow", row: ["id": .integer(2), "name": .integer(5)])
		#expect(throws: CRUDDecoderError.self) {
			_ = try Database(configuration: config).table(SelectErrorRow.self).first()
		}
	}

	@Test func fetchAllThrowsOnUndecodableRow() async throws {
		let db = try goodBadGoodDatabase()
		// 3.0.1 returned [row 1] here.
		await #expect(throws: CRUDDecoderError.self) {
			_ = try await db.table(SelectErrorRow.self).fetchAll()
		}
	}

	@Test func firstAndFetchAllThrowWhenTheQueryFails() async throws {
		let db = Database(configuration: try FailingExeConfig())
		let table = db.table(SelectErrorRow.self)
		// 3.0.1 returned nil and [].
		#expect(throws: ExeDelegateFailure.self) { _ = try table.first() }
		#expect(throws: ExeDelegateFailure.self) { _ = try table.where(\SelectErrorRow.id == 1).first() }
		await #expect(throws: ExeDelegateFailure.self) { _ = try await table.fetchAll() }
		await #expect(throws: ExeDelegateFailure.self) { _ = try await table.firstAsync() }
	}

	@Test func joinWithUndecodableChildThrows() async throws {
		let db = try badChildDatabase()
		let join = try db.table(SelectErrorParent.self).join(\.kids, on: \.id, equals: \.parentId)
		// 3.0.1 returned nil and [], dropping the parent along with its children.
		#expect(throws: CRUDDecoderError.self) { _ = try join.first() }
		await #expect(throws: CRUDDecoderError.self) { _ = try await join.fetchAll() }
	}

	@Test func typedSQLThrowsOnUndecodableRow() throws {
		let db = try goodBadGoodDatabase()
		#expect(throws: CRUDDecoderError.self) {
			_ = try db.sql("SELECT * FROM \"SelectErrorRow\"", SelectErrorRow.self)
		}
	}

	// Unchanged, and documented on Select: `for … in` can't throw, so it logs the error and
	// stops at the first bad row, and a query that can't run yields nothing.
	@Test func forInStopsAtTheFirstError() throws {
		let db = try goodBadGoodDatabase()
		var seen: [Int] = []
		for row in try db.table(SelectErrorRow.self).select() {
			seen.append(row.id)
		}
		#expect(seen == [1])

		let failing = Database(configuration: try FailingExeConfig())
		#expect(try failing.table(SelectErrorRow.self).select().map(\.id).isEmpty)

		let join = try badChildDatabase().table(SelectErrorParent.self).join(\.kids, on: \.id, equals: \.parentId)
		#expect(try join.select().map(\.id).isEmpty)
	}
}
