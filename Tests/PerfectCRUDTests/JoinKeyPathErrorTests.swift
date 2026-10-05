import Testing
import Foundation
@testable import PerfectCRUD

// A join's `to` key path was only resolved when the query ran, inside
// SQLTopExeDelegate.init. Select.makeIterator() catches and logs anything
// thrown there, so a join whose `to` can't be resolved silently returned no
// rows. select() must throw instead. (`\.family?.list` throws only because
// Parent has no top-level `[Kid]?` column; with one, it currently resolves
// to that column instead, which is a separate bug.)

private struct Kid: Codable {
	var id: Int
	var parentId: Int
}

private struct Kids: Codable {
	var count: Int
	var list: [Kid]?
}

private struct Parent: Codable {
	var id: Int
	var name: String
	var family: Kids?
}

private struct Family: Codable {
	var id: Int
	var kids: [Kid]?
}

private struct Tag: Codable {
	var id: Int
}

private struct ParentTag: Codable {
	var parentId: Int
	var tagId: Int
}

private struct Tags: Codable {
	var count: Int
	var list: [Tag]?
}

private struct Tagged: Codable {
	var id: Int
	var group: Tags?
}

private struct TagSet: Codable {
	var id: Int
	var tags: [Tag]?
}

private func seededDatabase() throws -> Database<StatefulStubConfig> {
	CRUDClearTableStructureCache()
	let config = try StatefulStubConfig()
	config.store.insert(table: "Parent", row: ["id": .integer(1), "name": .string("p")])
	config.store.insert(table: "Tagged", row: ["id": .integer(1)])
	config.store.insert(table: "Family", row: ["id": .integer(1)])
	config.store.insert(table: "TagSet", row: ["id": .integer(1)])
	return Database(configuration: config)
}

private func expectJoinError(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
	let error = #expect(throws: CRUDSQLGenError.self, sourceLocation: sourceLocation) {
		try body()
	}
	#expect(error?.description.contains("Join key path") == true, sourceLocation: sourceLocation)
}

@Suite("Join key path errors reach the caller", .serialized)
struct JoinKeyPathErrorTests {

	@Test func nestedJoinTargetThrowsFromSelect() throws {
		let db = try seededDatabase()
		let join = try db.table(Parent.self).join(\.family?.list, on: \.id, equals: \.parentId)
		// Used to return [] here, with the error only logged.
		expectJoinError { _ = try join.select().map { $0 } }
		expectJoinError { _ = try join.first() }
	}

	@Test func nestedPivotJoinTargetThrowsFromSelect() throws {
		let db = try seededDatabase()
		let join = try db.table(Tagged.self).join(\.group?.list, with: ParentTag.self,
												  on: \.id, equals: \.parentId,
												  and: \.id, is: \.tagId)
		expectJoinError { _ = try join.select().map { $0 } }
	}

	@Test func topLevelJoinsStillReturnRows() throws {
		let db = try seededDatabase()
		let parents = try db.table(Family.self).join(\.kids, on: \.id, equals: \.parentId).select().map { $0 }
		#expect(parents.map(\.id) == [1])
		#expect(parents.first?.kids?.isEmpty == true)
		let tagged = try db.table(TagSet.self).join(\.tags, with: ParentTag.self,
													on: \.id, equals: \.parentId,
													and: \.id, is: \.tagId).select().map { $0 }
		#expect(tagged.map(\.id) == [1])
	}
}
