import Testing
import Foundation
@testable import PerfectCRUD

// The throwing ways to read a Select added in 3.1.0: all(), forEachRow(_:) and rows().
// Fixtures are in SelectErrorTests.swift.

@Suite("Select's throwing read API", .serialized)
struct SelectThrowingReadTests {

	@Test func allThrowsOnUndecodableRow() throws {
		let select = try goodBadGoodDatabase().table(SelectErrorRow.self).select()
		#expect(throws: CRUDDecoderError.self) { _ = try select.all() }
	}

	@Test func allReturnsEveryRow() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		config.store.insert(table: "SelectErrorRow", row: ["id": .integer(1), "name": .string("a")])
		config.store.insert(table: "SelectErrorRow", row: ["id": .integer(2), "name": .string("b")])
		let rows = try Database(configuration: config).table(SelectErrorRow.self).select().all()
		#expect(rows == [SelectErrorRow(id: 1, name: "a"), SelectErrorRow(id: 2, name: "b")])
	}

	@Test func forEachRowThrowsAfterTheGoodRows() throws {
		let select = try goodBadGoodDatabase().table(SelectErrorRow.self).select()
		var seen: [Int] = []
		#expect(throws: CRUDDecoderError.self) {
			try select.forEachRow { seen.append($0.id) }
		}
		#expect(seen == [1])
	}

	@Test func forEachRowPassesOnTheBodysError() throws {
		struct Stop: Error {}
		let select = try goodBadGoodDatabase().table(SelectErrorRow.self).select()
		var seen: [Int] = []
		#expect(throws: Stop.self) {
			try select.forEachRow { seen.append($0.id); throw Stop() }
		}
		#expect(seen == [1])
	}

	@Test func rowsThrowsFromNextElementAndCanStopEarly() throws {
		let select = try goodBadGoodDatabase().table(SelectErrorRow.self).select()
		var rows = try select.rows()
		#expect(try rows.nextElement()?.id == 1)
		#expect(throws: CRUDDecoderError.self) { _ = try rows.nextElement() }
	}

	@Test func everyFormThrowsWhenTheQueryFails() throws {
		let select = try Database(configuration: try FailingExeConfig()).table(SelectErrorRow.self).select()
		#expect(throws: ExeDelegateFailure.self) { _ = try select.all() }
		#expect(throws: ExeDelegateFailure.self) { try select.forEachRow { _ in } }
		#expect(throws: ExeDelegateFailure.self) { _ = try select.rows() }
	}

	@Test func everyFormThrowsOnAnUndecodableJoinedChild() throws {
		let select = try badChildDatabase().table(SelectErrorParent.self)
			.join(\.kids, on: \.id, equals: \.parentId).select()
		#expect(throws: CRUDDecoderError.self) { _ = try select.all() }
		#expect(throws: CRUDDecoderError.self) { try select.forEachRow { _ in } }
		#expect(throws: CRUDDecoderError.self) { _ = try select.rows() }
	}
}
