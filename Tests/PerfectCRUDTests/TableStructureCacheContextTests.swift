import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - tableStructureCache context
//
// The cache is keyed by type only, but a structure also depends on the context it was
// computed in: an explicit `primaryKey` (from `create(primaryKey:)`), and the decoder depth
// (a sub-table's structure is computed at depth 1, where its own arrays are truncated, so
// it has no `subTables`). Caching those structures handed them to later, unrelated calls.
//
// Like TableStructureCacheKeyTests, these don't clear the cache: every type is unique to
// one test, so the order within a test is what sets up the cache state.

private enum PKHitScope {
	struct Model: Codable {
		let id: Int
		let code: String
	}
}

private enum PKFirstScope {
	struct Model: Codable {
		let id: Int
		let code: String
	}
}

// Mutually referencing sub-tables: A has [B], B has [A].
private enum DepthScope {
	struct MA: Codable {
		let id: Int
		let bs: [MB]?
	}
	struct MB: Codable {
		let id: Int
		let as_: [MA]?
	}
}

private enum ReverseDepthScope {
	struct MA: Codable {
		let id: Int
		let bs: [MB]?
	}
	struct MB: Codable {
		let id: Int
		let as_: [MA]?
	}
}

// A sub-table with a foreign key back to its parent: computing the parent's sub-tables
// reaches the parent again through the foreign key.
private enum ForeignKeyScope {
	struct Parent: Codable {
		let id: Int
		let code: String
		let kids: [Kid]?
	}
	struct Kid: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var parentRef: String
	}
}

// A third type reaches the parent through a foreign key while the parent's explicit-key
// structure is being computed: Parent has [Kid], Kid has a FK to Other, Other has a FK to
// Parent. Other must not be cached with that explicit key.
private enum ThirdTypeScope {
	struct Parent: Codable {
		let id: Int
		let code: String
		let kids: [Kid]?
	}
	struct Kid: Codable {
		let id: Int
		@ForeignKey(Other.self, onDelete: cascade, onUpdate: cascade)
		var otherRef: Int
	}
	struct Other: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var parentRef: String
	}
}

private func names(_ tables: [TableStructure]) -> [String] {
	tables.map(\.tableName)
}

@Suite("tableStructureCache context")
struct TableStructureCacheContextTests {

	@Test("an explicit primary key is honoured after the type was cached without one")
	func primaryKeyAfterCacheHit() throws {
		#expect(try PKHitScope.Model.CRUDTableStructure().primaryKeyName == "id")
		#expect(try PKHitScope.Model.CRUDTableStructure(primaryKey: \.code).primaryKeyName == "code")
		// The explicit-key structure doesn't replace the default one.
		#expect(try PKHitScope.Model.CRUDTableStructure().primaryKeyName == "id")
	}

	@Test("a structure computed for an explicit primary key isn't cached as the default")
	func primaryKeyFirst() throws {
		#expect(try PKFirstScope.Model.CRUDTableStructure(primaryKey: \.code).primaryKeyName == "code")
		#expect(try PKFirstScope.Model.CRUDTableStructure().primaryKeyName == "id")
	}

	@Test("a type first seen as a sub-table still gets its own sub-tables at top level")
	func subTableDoesNotPoisonTopLevel() throws {
		let a = try DepthScope.MA.CRUDTableStructure()
		#expect(names(a.subTables) == ["MB"])
		// As a sub-table, MB's own array is truncated.
		#expect(names(try #require(a.subTables.first).subTables) == [])
		// At top level, MB must have its sub-table, as it does with a cold cache.
		let b = try DepthScope.MB.CRUDTableStructure()
		#expect(names(b.subTables) == ["MA"])
		#expect(b.columns.map(\.name) == ["id"])
	}

	@Test("a sub-table's structure doesn't depend on its type being cached at top level")
	func topLevelDoesNotLeakIntoSubTable() throws {
		let b = try ReverseDepthScope.MB.CRUDTableStructure()
		#expect(names(b.subTables) == ["MA"])
		let a = try ReverseDepthScope.MA.CRUDTableStructure()
		#expect(names(a.subTables) == ["MB"])
		// Same as with a cold cache: MB as a sub-table has no sub-tables of its own.
		// Getting the cached top-level MB here would make create(MA) create MA twice.
		let aSub = try #require(a.subTables.first)
		#expect(names(aSub.subTables) == [])
		#expect(aSub !== b)
	}

	@Test("a foreign key back to the parent sees the parent's explicit primary key")
	func foreignKeyBackToParentWithExplicitPrimaryKey() throws {
		// Cache the default structure first; the explicit-key computation must not use it.
		let plain = try ForeignKeyScope.Parent.CRUDTableStructure()
		#expect(plain.primaryKeyName == "id")
		let plainKid = try #require(plain.subTables.first)
		let plainRef = try #require(plainKid.columns.first { $0.name == "parentRef" })
		#expect(plainRef.properties.contains(.foreignKey("Parent", "id", .cascade, .cascade)))

		let keyed = try ForeignKeyScope.Parent.CRUDTableStructure(primaryKey: \.code)
		#expect(keyed.primaryKeyName == "code")
		let kid = try #require(keyed.subTables.first)
		let ref = try #require(kid.columns.first { $0.name == "parentRef" })
		#expect(ref.properties.contains(.foreignKey("Parent", "code", .cascade, .cascade)))

		// And the default structure is unaffected afterwards.
		#expect(try ForeignKeyScope.Parent.CRUDTableStructure().primaryKeyName == "id")
	}

	@Test("a type computed during an explicit-key computation isn't cached with that key")
	func explicitPrimaryKeyDoesNotLeakThroughAThirdType() throws {
		let keyed = try ThirdTypeScope.Parent.CRUDTableStructure(primaryKey: \.code)
		#expect(keyed.primaryKeyName == "code")
		let other = try ThirdTypeScope.Other.CRUDTableStructure()
		let ref = try #require(other.columns.first { $0.name == "parentRef" })
		// As with a cold cache: Other on its own references Parent's default key.
		#expect(ref.properties.contains(.foreignKey("Parent", "id", .cascade, .cascade)))
	}
}
