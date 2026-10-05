import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - foreign key cycles among a type's own columns
//
// A `@ForeignKey` column is resolved while its type's columns are being built, before the
// structure is published to the cache. A cycle among the columns (a type referencing itself,
// or two or three types referencing each other) used to recompute the structure forever and
// crash with a stack overflow. A foreign key back to the parent from a sub-table already
// terminated, because the parent is published before its sub-tables are filled in.
//
// Like TableStructureCacheContextTests, these don't clear the cache: every type is unique to
// one test, so the order within a test is what sets up the cache state.

private enum SelfScope {
	struct Employee: Codable {
		let id: Int
		@ForeignKey(Employee.self, onDelete: cascade, onUpdate: cascade)
		var managerId: Int
	}
}

// An optional self-reference with different actions, as a real tree table would declare it.
private enum OptionalSelfScope {
	struct Node: Codable {
		let id: Int
		@ForeignKey(Node.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
	}
}

private enum SelfPKScope {
	struct Employee: Codable {
		let id: Int
		let code: String
		@ForeignKey(Employee.self, onDelete: cascade, onUpdate: cascade)
		var managerCode: String
	}
}

private enum SelfPKFirstScope {
	struct Employee: Codable {
		let id: Int
		let code: String
		@ForeignKey(Employee.self, onDelete: cascade, onUpdate: cascade)
		var managerCode: String
	}
}

private enum WrappedPKScope {
	struct Category: Codable {
		@PrimaryKey var key: String
		@ForeignKey(Category.self, onDelete: restrict, onUpdate: cascade)
		var parentKey: String
	}
}

private enum MutualScope {
	struct A: Codable {
		let id: Int
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bId: Int
	}
	struct B: Codable {
		let id: Int
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aId: Int
	}
}

private enum MutualPKScope {
	struct A: Codable {
		let id: Int
		let code: String
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bId: Int
	}
	struct B: Codable {
		let id: Int
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aCode: String
	}
}

private enum TriangleScope {
	struct A: Codable {
		let id: Int
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bId: Int
	}
	struct B: Codable {
		let id: Int
		@ForeignKey(C.self, onDelete: cascade, onUpdate: cascade)
		var cId: Int
	}
	struct C: Codable {
		let id: Int
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aId: Int
	}
}

// A self-referencing type used as a sub-table: its column-level cycle is resolved from a
// depth-1 computation, which doesn't record a target of its own.
private enum SubTableSelfScope {
	struct Parent: Codable {
		let id: Int
		let nodes: [Node]?
	}
	struct Node: Codable {
		let id: Int
		@ForeignKey(Node.self, onDelete: cascade, onUpdate: cascade)
		var nextId: Int
	}
}

// No primary key on either side: the foreign keys are dropped, as before, without recursing.
private enum NoKeyScope {
	struct A: Codable {
		let name: String
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bName: String
	}
	struct B: Codable {
		let name: String
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aName: String
	}
}

// A type reached through a foreign key during an explicit-key computation reaches the
// explicit key again through one of its sub-tables: A (explicit key) -> B, B has [C], C -> A.
private enum SubTableThroughForeignKeyScope {
	struct A: Codable {
		let id: Int
		let code: String
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bId: Int
	}
	struct B: Codable {
		let id: Int
		let cs: [C]?
	}
	struct C: Codable {
		let id: Int
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aCode: String
	}
}

// Every type in a layer references both types in the next one, so the last layer is reached
// along 2^22 paths. Each type must be computed once per call, not once per path.
private enum LayeredScope {
	struct Root: Codable {
		let id: Int
		let code: String
		@ForeignKey(X0.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y0.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X0: Codable {
		let id: Int
		@ForeignKey(X1.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y1.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y0: Codable {
		let id: Int
		@ForeignKey(X1.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y1.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X1: Codable {
		let id: Int
		@ForeignKey(X2.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y2.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y1: Codable {
		let id: Int
		@ForeignKey(X2.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y2.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X2: Codable {
		let id: Int
		@ForeignKey(X3.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y3.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y2: Codable {
		let id: Int
		@ForeignKey(X3.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y3.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X3: Codable {
		let id: Int
		@ForeignKey(X4.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y4.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y3: Codable {
		let id: Int
		@ForeignKey(X4.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y4.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X4: Codable {
		let id: Int
		@ForeignKey(X5.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y5.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y4: Codable {
		let id: Int
		@ForeignKey(X5.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y5.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X5: Codable {
		let id: Int
		@ForeignKey(X6.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y6.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y5: Codable {
		let id: Int
		@ForeignKey(X6.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y6.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X6: Codable {
		let id: Int
		@ForeignKey(X7.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y7.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y6: Codable {
		let id: Int
		@ForeignKey(X7.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y7.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X7: Codable {
		let id: Int
		@ForeignKey(X8.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y8.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y7: Codable {
		let id: Int
		@ForeignKey(X8.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y8.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X8: Codable {
		let id: Int
		@ForeignKey(X9.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y9.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y8: Codable {
		let id: Int
		@ForeignKey(X9.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y9.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X9: Codable {
		let id: Int
		@ForeignKey(X10.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y10.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y9: Codable {
		let id: Int
		@ForeignKey(X10.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y10.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X10: Codable {
		let id: Int
		@ForeignKey(X11.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y11.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y10: Codable {
		let id: Int
		@ForeignKey(X11.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y11.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X11: Codable {
		let id: Int
		@ForeignKey(X12.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y12.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y11: Codable {
		let id: Int
		@ForeignKey(X12.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y12.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X12: Codable {
		let id: Int
		@ForeignKey(X13.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y13.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y12: Codable {
		let id: Int
		@ForeignKey(X13.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y13.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X13: Codable {
		let id: Int
		@ForeignKey(X14.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y14.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y13: Codable {
		let id: Int
		@ForeignKey(X14.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y14.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X14: Codable {
		let id: Int
		@ForeignKey(X15.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y15.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y14: Codable {
		let id: Int
		@ForeignKey(X15.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y15.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X15: Codable {
		let id: Int
		@ForeignKey(X16.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y16.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y15: Codable {
		let id: Int
		@ForeignKey(X16.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y16.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X16: Codable {
		let id: Int
		@ForeignKey(X17.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y17.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y16: Codable {
		let id: Int
		@ForeignKey(X17.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y17.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X17: Codable {
		let id: Int
		@ForeignKey(X18.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y18.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y17: Codable {
		let id: Int
		@ForeignKey(X18.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y18.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X18: Codable {
		let id: Int
		@ForeignKey(X19.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y19.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y18: Codable {
		let id: Int
		@ForeignKey(X19.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y19.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X19: Codable {
		let id: Int
		@ForeignKey(X20.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y20.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y19: Codable {
		let id: Int
		@ForeignKey(X20.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y20.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X20: Codable {
		let id: Int
		@ForeignKey(X21.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y21.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y20: Codable {
		let id: Int
		@ForeignKey(X21.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y21.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X21: Codable {
		let id: Int
		@ForeignKey(X22.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y22.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct Y21: Codable {
		let id: Int
		@ForeignKey(X22.self, onDelete: cascade, onUpdate: cascade)
		var x: Int
		@ForeignKey(Y22.self, onDelete: cascade, onUpdate: cascade)
		var y: Int
	}
	struct X22: Codable {
		let id: Int
	}
	struct Y22: Codable {
		let id: Int
	}
}

private enum ConcurrentScope {
	struct Employee: Codable {
		let id: Int
		@ForeignKey(Employee.self, onDelete: cascade, onUpdate: cascade)
		var managerId: Int
	}
	struct A: Codable {
		let id: Int
		@ForeignKey(B.self, onDelete: cascade, onUpdate: cascade)
		var bId: Int
	}
	struct B: Codable {
		let id: Int
		@ForeignKey(A.self, onDelete: cascade, onUpdate: cascade)
		var aId: Int
	}
}

private func reference(_ table: TableStructure, _ column: String) throws -> TableStructure.Column.Property? {
	let col = try #require(table.columns.first { $0.name == column })
	return col.properties.first {
		if case .foreignKey = $0 { return true }
		return false
	}
}

@Suite("foreign key cycles")
struct ForeignKeyCycleTests {

	@Test("a self-referencing foreign key column")
	func selfReference() throws {
		let e = try SelfScope.Employee.CRUDTableStructure()
		#expect(e.primaryKeyName == "id")
		#expect(try reference(e, "managerId") == .foreignKey("Employee", "id", .cascade, .cascade))
		// The same afterwards, from the cache. (Not checked with `===`: the concurrency suite
		// clears the cache while other suites run.)
		#expect(try reference(SelfScope.Employee.CRUDTableStructure(), "managerId") == .foreignKey("Employee", "id", .cascade, .cascade))
	}

	@Test("an optional self-reference keeps its own actions")
	func optionalSelfReference() throws {
		let n = try OptionalSelfScope.Node.CRUDTableStructure()
		#expect(try reference(n, "parentId") == .foreignKey("Node", "id", .setNull, .restrict))
	}

	@Test("a self-reference sees an explicit primary key")
	func selfReferenceWithExplicitPrimaryKey() throws {
		let plain = try SelfPKScope.Employee.CRUDTableStructure()
		#expect(try reference(plain, "managerCode") == .foreignKey("Employee", "id", .cascade, .cascade))

		let keyed = try SelfPKScope.Employee.CRUDTableStructure(primaryKey: \.code)
		#expect(keyed.primaryKeyName == "code")
		#expect(try reference(keyed, "managerCode") == .foreignKey("Employee", "code", .cascade, .cascade))

		// The default structure is unaffected.
		let again = try SelfPKScope.Employee.CRUDTableStructure()
		#expect(again.primaryKeyName == "id")
		#expect(try reference(again, "managerCode") == .foreignKey("Employee", "id", .cascade, .cascade))
	}

	@Test("an explicit-key self-reference computed first doesn't leak into the default")
	func selfReferenceWithExplicitPrimaryKeyFirst() throws {
		let keyed = try SelfPKFirstScope.Employee.CRUDTableStructure(primaryKey: \.code)
		#expect(try reference(keyed, "managerCode") == .foreignKey("Employee", "code", .cascade, .cascade))
		let plain = try SelfPKFirstScope.Employee.CRUDTableStructure()
		#expect(plain.primaryKeyName == "id")
		#expect(try reference(plain, "managerCode") == .foreignKey("Employee", "id", .cascade, .cascade))
	}

	@Test("a self-reference to a @PrimaryKey column")
	func selfReferenceToWrappedPrimaryKey() throws {
		let c = try WrappedPKScope.Category.CRUDTableStructure()
		#expect(c.primaryKeyName == "key")
		#expect(try reference(c, "parentKey") == .foreignKey("Category", "key", .restrict, .cascade))
	}

	@Test("two types referencing each other")
	func mutualReference() throws {
		let a = try MutualScope.A.CRUDTableStructure()
		#expect(try reference(a, "bId") == .foreignKey("B", "id", .cascade, .cascade))
		let b = try MutualScope.B.CRUDTableStructure()
		#expect(try reference(b, "aId") == .foreignKey("A", "id", .cascade, .cascade))
	}

	@Test("a type reached through a foreign key during an explicit-key computation isn't cached with that key")
	func mutualReferenceWithExplicitPrimaryKey() throws {
		let keyed = try MutualPKScope.A.CRUDTableStructure(primaryKey: \.code)
		#expect(keyed.primaryKeyName == "code")
		#expect(try reference(keyed, "bId") == .foreignKey("B", "id", .cascade, .cascade))
		// B was computed while A's explicit key was in progress, and referenced it then.
		// On its own, as with a cold cache, B references A's default key.
		let b = try MutualPKScope.B.CRUDTableStructure()
		#expect(try reference(b, "aCode") == .foreignKey("A", "id", .cascade, .cascade))
		let a = try MutualPKScope.A.CRUDTableStructure()
		#expect(a.primaryKeyName == "id")
	}

	@Test("three types in a foreign key cycle")
	func triangle() throws {
		let b = try TriangleScope.B.CRUDTableStructure()
		#expect(try reference(b, "cId") == .foreignKey("C", "id", .cascade, .cascade))
		let c = try TriangleScope.C.CRUDTableStructure()
		#expect(try reference(c, "aId") == .foreignKey("A", "id", .cascade, .cascade))
		let a = try TriangleScope.A.CRUDTableStructure()
		#expect(try reference(a, "bId") == .foreignKey("B", "id", .cascade, .cascade))
	}

	@Test("a self-referencing sub-table")
	func selfReferencingSubTable() throws {
		let p = try SubTableSelfScope.Parent.CRUDTableStructure()
		let node = try #require(p.subTables.first)
		#expect(node.tableName == "Node")
		#expect(try reference(node, "nextId") == .foreignKey("Node", "id", .cascade, .cascade))
	}

	@Test("a cycle between types with no primary key")
	func cycleWithoutPrimaryKeys() throws {
		let a = try NoKeyScope.A.CRUDTableStructure()
		#expect(a.primaryKeyName == nil)
		#expect(try reference(a, "bName") == nil)
		#expect(try reference(NoKeyScope.B.CRUDTableStructure(), "aName") == nil)
	}

	@Test("a type whose sub-table reaches an explicit key isn't cached with it")
	func subTableThroughForeignKeyWithExplicitPrimaryKey() throws {
		let keyed = try SubTableThroughForeignKeyScope.A.CRUDTableStructure(primaryKey: \.code)
		#expect(try reference(keyed, "bId") == .foreignKey("B", "id", .cascade, .cascade))
		// B (and its sub-table C) were computed while A's explicit key was in progress. On its
		// own, as with a cold cache, C references A's default key.
		let b = try SubTableThroughForeignKeyScope.B.CRUDTableStructure()
		let c = try #require(b.subTables.first)
		#expect(try reference(c, "aCode") == .foreignKey("A", "id", .cascade, .cascade))
	}

	@Test("foreign keys reaching the same types along many paths", .timeLimit(.minutes(1)))
	func layeredForeignKeys() throws {
		let keyed = try LayeredScope.Root.CRUDTableStructure(primaryKey: \.code)
		#expect(try reference(keyed, "x") == .foreignKey("X0", "id", .cascade, .cascade))
		let plain = try LayeredScope.Root.CRUDTableStructure()
		#expect(try reference(plain, "y") == .foreignKey("Y0", "id", .cascade, .cascade))
		#expect(try reference(LayeredScope.X21.CRUDTableStructure(), "y") == .foreignKey("Y22", "id", .cascade, .cascade))
	}

	@Test("concurrent first-time computation of cyclic types")
	func concurrentCycles() async throws {
		let results = try await withThrowingTaskGroup(of: [String].self) { group in
			for i in 0..<64 {
				group.addTask {
					let table: TableStructure
					switch i % 3 {
					case 0: table = try ConcurrentScope.Employee.CRUDTableStructure()
					case 1: table = try ConcurrentScope.A.CRUDTableStructure()
					default: table = try ConcurrentScope.B.CRUDTableStructure()
					}
					return table.columns.flatMap { col in
						col.properties.compactMap {
							guard case .foreignKey(let t, let c, _, _) = $0 else { return nil }
							return "\(table.tableName).\(col.name)->\(t).\(c)"
						}
					}
				}
			}
			var collected = Set<[String]>()
			for try await r in group {
				collected.insert(r)
			}
			return collected
		}
		#expect(results == [["Employee.managerId->Employee.id"], ["A.bId->B.id"], ["B.aId->A.id"]])
	}
}
