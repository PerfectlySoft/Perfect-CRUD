import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - A pivot join followed by another join
//
// A pivot join adds two tables to the generation state (the joined type, then the pivot
// table) but generates only one statement, for the joined type. The executor paired tables
// with statements by position, so any join after a pivot join was paired with the pivot
// table's slot: the next join's SQL ran against the pivot table, the pivot table had no join
// data, and `SQLTopExeDelegate.init` threw "No join data on <Pivot>". `Select.makeIterator()`
// swallows that, so the select silently returned no rows. A pivot join *last* worked only
// because the trailing pivot table fell off the end of the `zip`.
//
// StatefulStubConfig returns every stored row of the first table named after FROM,
// unfiltered, so the pivot rows are seeded directly with the `_crud_pivot_id_` column the
// pivot SELECT would produce; the parent-side filtering is PerfectCRUD's own.

private enum PivotThenJoinScope {
	struct Parent: Codable {
		let id: Int
		let tags: [Tag]?
		let kids: [Kid]?
		let notes: [Note]?
	}
	// Two arrays of the same element type, which need distinct join targets.
	struct TwinParent: Codable {
		let id: Int
		let tags: [Tag]?
		let tags2: [Tag]?
	}
	struct Tag: Codable {
		let id: Int
		let name: String
	}
	struct ParentTag: Codable {
		let parentId: Int
		let tagId: Int
	}
	struct Kid: Codable {
		let id: Int
		let parentId: Int
	}
	struct Note: Codable {
		let id: Int
		let name: String
	}
	struct ParentNote: Codable {
		let parentId: Int
		let noteId: Int
	}
}

@Suite("A pivot join followed by another join")
struct PivotJoinOrderTests {
	fileprivate typealias Parent = PivotThenJoinScope.Parent
	fileprivate typealias Tag = PivotThenJoinScope.Tag
	fileprivate typealias ParentTag = PivotThenJoinScope.ParentTag
	fileprivate typealias Kid = PivotThenJoinScope.Kid
	fileprivate typealias Note = PivotThenJoinScope.Note
	fileprivate typealias ParentNote = PivotThenJoinScope.ParentNote
	fileprivate typealias TwinParent = PivotThenJoinScope.TwinParent

	private func seededDatabase() -> Database<StatefulStubConfig> {
		let config = try! StatefulStubConfig()
		let store = config.store
		for id in [1, 2] {
			store.insert(table: "Parent", row: ["id": .integer(id)])
		}
		// Parent 1 has tags 10 and 11; parent 2 has tag 10.
		for (parentId, tagId, name) in [(1, 10, "a"), (1, 11, "b"), (2, 10, "a")] {
			store.insert(table: "Tag", row: ["id": .integer(tagId), "name": .string(name),
											 joinPivotIdColumnName: .integer(parentId)])
		}
		for (parentId, noteId, name) in [(2, 30, "n")] {
			store.insert(table: "Note", row: ["id": .integer(noteId), "name": .string(name),
											  joinPivotIdColumnName: .integer(parentId)])
		}
		// Parent 1 has kid 20; parent 2 has kids 21 and 22.
		for (kidId, parentId) in [(20, 1), (21, 2), (22, 2)] {
			store.insert(table: "Kid", row: ["id": .integer(kidId), "parentId": .integer(parentId)])
		}
		return Database(configuration: config)
	}

	private func check(_ parents: [Parent], notes: Bool = false) {
		#expect(parents.map(\.id) == [1, 2])
		guard parents.count == 2 else { return }
		#expect(parents[0].tags?.map(\.id) == [10, 11])
		#expect(parents[1].tags?.map(\.id) == [10])
		#expect(parents[0].kids?.map(\.id) == [20])
		#expect(parents[1].kids?.map(\.id) == [21, 22])
		if notes {
			#expect(parents[0].notes?.map(\.id) == [])
			#expect(parents[1].notes?.map(\.id) == [30])
		}
	}

	@Test("pivot join, then join")
	func pivotThenJoin() throws {
		let parents = try seededDatabase().table(Parent.self)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.select().map { $0 }
		check(parents)
	}

	@Test("join, then pivot join (worked before the fix)")
	func joinThenPivot() throws {
		let parents = try seededDatabase().table(Parent.self)
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.select().map { $0 }
		check(parents)
	}

	@Test("pivot join, then pivot join, then join")
	func pivotThenPivotThenJoin() throws {
		let parents = try seededDatabase().table(Parent.self)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.notes, with: ParentNote.self, on: \.id, equals: \.parentId, and: \.id, is: \.noteId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.select().map { $0 }
		check(parents, notes: true)
	}

	@Test("pivot join, then join, then pivot join")
	func pivotThenJoinThenPivot() throws {
		let parents = try seededDatabase().table(Parent.self)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.notes, with: ParentNote.self, on: \.id, equals: \.parentId, and: \.id, is: \.noteId)
			.select().map { $0 }
		check(parents, notes: true)
	}

	@Test("pivot join, then join, with a where clause and ordering")
	func pivotThenJoinFiltered() throws {
		// The stub ignores WHERE, so this only checks that a where/order chain on the
		// pivot-then-join shape still generates and pairs its statements.
		let parents = try seededDatabase().table(Parent.self)
			.order(by: \.id)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.where(\Parent.id > 0)
			.select().map { $0 }
		check(parents)
	}

	// Joined objects are keyed by their target property's name, so two joins into one name
	// trapped in Dictionary(uniqueKeysWithValues:).

	@Test("two pivot joins into same-type arrays fill both")
	func sameTypePivotTargets() throws {
		let config = try StatefulStubConfig()
		config.store.insert(table: "TwinParent", row: ["id": .integer(1)])
		for tagId in [10, 11] {
			config.store.insert(table: "Tag", row: ["id": .integer(tagId), "name": .string("t"),
													joinPivotIdColumnName: .integer(1)])
		}
		let parents = try Database(configuration: config).table(TwinParent.self)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.tags2, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.select().map { $0 }
		// The stub doesn't filter by pivot, so both arrays get every Tag row.
		#expect(parents.map(\.id) == [1])
		#expect(parents.first?.tags?.map(\.id) == [10, 11])
		#expect(parents.first?.tags2?.map(\.id) == [10, 11])
	}

	@Test("the same join twice throws from select()")
	func duplicateJoinTargetsThrow() throws {
		let table = try seededDatabase().table(Parent.self)
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.kids, on: \.id, equals: \.parentId)
		#expect(throws: CRUDSQLGenError.self) { _ = try table.select() }
	}
}
