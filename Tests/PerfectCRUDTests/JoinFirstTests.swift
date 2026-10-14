import Testing
import Foundation
@testable import PerfectCRUD

// first() appended limit(1) to the query. A limit applies to the most recent table or join, so
// on a join it became LIMIT 1 on the joined table's statement: the parent got at most one child,
// the first child row overall, which might belong to a different parent.

private struct JFKid: Codable, Equatable {
	var id: Int
	var parentId: Int
}

private struct JFParent: Codable {
	var id: Int
	var kids: [JFKid]?
}

@Suite("first() on a join keeps every joined object", .serialized)
struct JoinFirstTests {
	private func database() throws -> Database<StatefulStubConfig> {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		config.store.insert(table: "JFParent", row: ["id": .integer(1)])
		config.store.insert(table: "JFParent", row: ["id": .integer(2)])
		config.store.insert(table: "JFKid", row: ["id": .integer(1), "parentId": .integer(2)])
		config.store.insert(table: "JFKid", row: ["id": .integer(2), "parentId": .integer(1)])
		config.store.insert(table: "JFKid", row: ["id": .integer(3), "parentId": .integer(1)])
		return Database(configuration: config)
	}

	@Test func joinFirstHasAllItsChildren() throws {
		let join = try database().table(JFParent.self).join(\.kids, on: \.id, equals: \.parentId)
		let parent = try #require(try join.first())
		#expect(parent.id == 1)
		// 3.0.1: [] (the one child fetched belonged to parent 2).
		#expect(parent.kids?.map(\.id) == [2, 3])
	}

	@Test func orderedJoinFirstHasAllItsChildren() async throws {
		let join = try database().table(JFParent.self).join(\.kids, on: \.id, equals: \.parentId).order(by: \.id)
		#expect(try join.first()?.kids?.map(\.id) == [2, 3])
		#expect(try await join.firstAsync()?.kids?.map(\.id) == [2, 3])
	}

	@Test func tableFirstStillLimitsToOneRow() throws {
		let db = try database()
		#expect(try db.table(JFParent.self).first()?.id == 1)
		#expect(try db.table(JFParent.self).limit(1, skip: 0).first()?.id == 1)
	}
}
