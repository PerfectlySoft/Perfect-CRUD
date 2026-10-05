import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - tableStructureCache key collisions
//
// The cache used to be keyed by `"\(type(of: Self.self))"`, which is the unqualified
// type name. Distinct types that share a name (function-local or nested types in
// different scopes, or the same name in two modules) then reused whichever structure
// was cached first. Perfect-MySQL and Perfect-MariaDB hit this with test-local `Me`
// and `Top` structs: the second test created its table with the first one's columns.
//
// These tests don't clear the cache: every type here is unique to this file, and
// clearing the global cache could disturb suites running in parallel.

private enum ScopeA {
	struct CacheKeyProbe: Codable {
		let id: Int
		let name: String
	}
}

private enum ScopeB {
	struct CacheKeyProbe: Codable {
		let id: Int
		let parentId: Int
		let note: String?
	}
}

@Suite("tableStructureCache key")
struct TableStructureCacheKeyTests {

	@Test("same-named nested types in different scopes get their own structures")
	func nestedTypesWithSameName() throws {
		let a = try ScopeA.CacheKeyProbe.CRUDTableStructure()
		let b = try ScopeB.CacheKeyProbe.CRUDTableStructure()
		#expect(a.tableName == "CacheKeyProbe")
		#expect(b.tableName == "CacheKeyProbe")
		#expect(a.columns.map(\.name) == ["id", "name"])
		#expect(b.columns.map(\.name) == ["id", "parentId", "note"])
		// Asking again (now cached) must still return each type's own columns.
		#expect(try ScopeA.CacheKeyProbe.CRUDTableStructure().columns.map(\.name) == ["id", "name"])
		#expect(try ScopeB.CacheKeyProbe.CRUDTableStructure().columns.map(\.name) == ["id", "parentId", "note"])
	}

	// The shape that broke Perfect-MySQL's `selfJoin` / `selfJunctionJoin`: two
	// function-local structs with the same name in different functions.
	private func localMeWithoutParent() throws -> [String] {
		struct LocalMe: Codable {
			let id: Int
			let name: String
		}
		return try LocalMe.CRUDTableStructure().columns.map(\.name)
	}

	private func localMeWithParent() throws -> [String] {
		struct LocalMe: Codable {
			let id: Int
			let parentId: Int
		}
		return try LocalMe.CRUDTableStructure().columns.map(\.name)
	}

	@Test("same-named function-local types get their own structures")
	func functionLocalTypesWithSameName() throws {
		#expect(try localMeWithoutParent() == ["id", "name"])
		#expect(try localMeWithParent() == ["id", "parentId"])
		#expect(try localMeWithoutParent() == ["id", "name"])
	}

	// The same name used both as a top-level model and as a nested sub-table type,
	// so the collision would happen during the recursive sub-table computation.
	private enum ScopeC {
		struct Child: Codable {
			let id: Int
			let parentId: Int
		}
		struct Parent: Codable {
			let id: Int
			let children: [Child]?
		}
	}
	private enum ScopeD {
		struct Child: Codable {
			let id: Int
			let label: String
		}
	}

	@Test("a sub-table type doesn't collide with a same-named model elsewhere")
	func subTableTypeWithSameName() throws {
		#expect(try ScopeD.Child.CRUDTableStructure().columns.map(\.name) == ["id", "label"])
		let parent = try ScopeC.Parent.CRUDTableStructure()
		let sub = try #require(parent.subTables.first)
		#expect(sub.tableName == "Child")
		#expect(sub.columns.map(\.name) == ["id", "parentId"])
	}
}
