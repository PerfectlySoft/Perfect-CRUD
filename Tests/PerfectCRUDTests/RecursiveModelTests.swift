import Testing
import Foundation
@testable import PerfectCRUD

// Self-referential Codable models, such as `final class Node { var v: Int; var next: Node? }`.
// The key path and column name decoders build a model by handing out a value for every
// property, and both answered "not nil" for every optional. So `next` was decoded, and its
// `next`, and so on until the stack overflowed: any `db.table(Node.self)`, or a table with a
// Node column, crashed the process.
//
// Each test first runs the operation in a child process (an exit test), so on a build without
// the fix the test fails instead of taking the test runner down. Only then does it check the
// results in process.

private final class Node: Codable {
	var v: Int
	var next: Node?
}

private struct Holder: Codable {
	var id: Int
	var name: String
	var head: Node?
	var flag: Bool
}

private final class Tree: Codable {
	var id: Int
	var left: Tree?
	var right: Tree?
}

private final class Person: Codable {
	var id: Int
	var name: String
	var pet: Pet?
}

private final class Pet: Codable {
	var name: String
	var owner: Person?
}

// The cycle goes through a non-optional property: Outer -> Inner? -> Outer.
private final class Outer: Codable {
	var id: Int
	var inner: Inner?
}

private struct Inner: Codable {
	var label: String
	var outer: Outer
}

// A hand-written init(from:) that checks decodeNil(forKey:) itself, so the decoder never
// learns the type of the optional property.
private final class ManualNode: Codable {
	var v: Int
	var next: ManualNode?
	private enum CodingKeys: String, CodingKey {
		case v, next
	}
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		v = try c.decode(Int.self, forKey: .v)
		if try c.decodeNil(forKey: .next) {
			next = nil
		} else {
			next = try c.decode(ManualNode.self, forKey: .next)
		}
	}
}

// Can't be decoded from any finite input: `next` isn't optional.
private final class Endless: Codable {
	var v: Int
	var next: Endless
}

private final class RecursiveStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		throw CRUDSQLExeError("not executed in these tests")
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

private func columnName<T: Codable>(_ keyPath: PartialKeyPath<T>) throws -> String? {
	let decoder = CRUDKeyPathsDecoder()
	let instance = try T(from: decoder)
	return try decoder.getKeyPathName(instance, keyPath: keyPath)
}

private func columns<T: Codable>(_ type: T.Type) throws -> [String: Bool] {
	let structure = try T.CRUDTableStructure()
	return Dictionary(uniqueKeysWithValues: structure.columns.map { ($0.name, $0.optional) })
}

// What the in-process checks below do, run where a stack overflow can't hurt.
private func exerciseKeyPaths() {
	_ = try? columnName(\Node.v)
	_ = try? columnName(\Node.next)
	_ = try? columnName(\Holder.name)
	_ = try? columnName(\Holder.head)
	_ = try? columnName(\Holder.head?.v)
	_ = try? columnName(\Tree.right)
	_ = try? columnName(\Person.pet)
	_ = try? columnName(\Person.pet?.name)
	_ = try? columnName(\Outer.inner)
	_ = try? columnName(\ManualNode.v)
}

private func exerciseTableStructures() {
	_ = try? Node.CRUDTableStructure()
	_ = try? Holder.CRUDTableStructure()
	_ = try? Tree.CRUDTableStructure()
	_ = try? Person.CRUDTableStructure()
	_ = try? Outer.CRUDTableStructure()
	_ = try? ManualNode.CRUDTableStructure()
}

private func exerciseSQL() {
	guard let config = try? RecursiveStubConfig() else {
		return
	}
	let db = Database(configuration: config)
	_ = try? db.table(Node.self).where(\Node.v == 1).select()
	_ = try? db.table(Holder.self).order(by: \.head).where(\Holder.name == "x").select()
}

private func exerciseEndless() {
	_ = try? Endless(from: CRUDKeyPathsDecoder())
	_ = try? Endless.CRUDTableStructure()
	if let config = try? RecursiveStubConfig() {
		_ = try? Database(configuration: config).table(Endless.self).select()
	}
}

@Suite("Self-referential models", .serialized)
struct RecursiveModelTests {
	init() {
		CRUDClearTableStructureCache()
	}

	@Test func decodingTerminates() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseKeyPaths()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		let node = try Node(from: CRUDKeyPathsDecoder())
		// A model's own `next` is still decoded once, so it stays a column.
		#expect(node.next != nil)
		#expect(node.next?.next == nil)
	}

	@Test func keyPathsResolve() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseKeyPaths()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		#expect(try columnName(\Node.v) == "v")
		#expect(try columnName(\Node.next) == "next")
		#expect(try columnName(\Holder.id) == "id")
		#expect(try columnName(\Holder.name) == "name")
		#expect(try columnName(\Holder.head) == "head")
		#expect(try columnName(\Holder.flag) == "flag")
		#expect(try columnName(\Tree.id) == "id")
		#expect(try columnName(\Tree.left) == "left")
		#expect(try columnName(\Tree.right) == "right")
		#expect(try columnName(\Person.name) == "name")
		#expect(try columnName(\Person.pet) == "pet")
		#expect(try columnName(\Outer.id) == "id")
		#expect(try columnName(\Outer.inner) == "inner")
		#expect(try columnName(\ManualNode.v) == "v")
		#expect(try columnName(\ManualNode.next) == "next")
	}

	@Test func keyPathsIntoTheRecursionAreStillNested() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseKeyPaths()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		for check in [{ _ = try columnName(\Holder.head?.v) },
					  { _ = try columnName(\Node.next?.v) },
					  { _ = try columnName(\Person.pet?.name) }] {
			let error = #expect(throws: CRUDSQLGenError.self) { try check() }
			#expect(error?.description.contains("top-level property") == true)
		}
	}

	@Test func tableStructuresHaveTheTopLevelColumns() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseTableStructures()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		#expect(try columns(Node.self) == ["v": false, "next": true])
		#expect(try columns(Holder.self) == ["id": false, "name": false, "head": true, "flag": false])
		#expect(try columns(Tree.self) == ["id": false, "left": true, "right": true])
		#expect(try columns(Person.self) == ["id": false, "name": false, "pet": true])
		#expect(try columns(Outer.self) == ["id": false, "inner": true])
		#expect(try columns(ManualNode.self) == ["v": false, "next": true])
	}

	@Test func tablesGenerateSQL() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseSQL()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		let db = Database(configuration: try RecursiveStubConfig())
		let nodeSQL = try #require(try db.table(Node.self).where(\Node.v == 1).select().sqlGenState.statements.first?.sql)
		#expect(nodeSQL.contains("WHERE \"t0\".\"v\" = "))
		let holderSQL = try #require(try db.table(Holder.self).order(by: \.head).where(\Holder.name == "x")
			.select().sqlGenState.statements.first?.sql)
		#expect(holderSQL.contains("WHERE \"t0\".\"name\" = "))
		#expect(holderSQL.contains("ORDER BY \"t0\".\"head\""))
	}

	@Test func nonOptionalSelfReferenceThrows() async throws {
		let result = await #expect(processExitsWith: .success) {
			exerciseEndless()
		}
		guard case .exitCode(EXIT_SUCCESS)? = result?.exitStatus else {
			return
		}

		let keyPathError = #expect(throws: CRUDDecoderError.self) { _ = try Endless(from: CRUDKeyPathsDecoder()) }
		#expect(keyPathError?.msg.contains("must be optional") == true)
		let columnError = #expect(throws: CRUDDecoderError.self) { _ = try Endless.CRUDTableStructure() }
		#expect(columnError?.msg.contains("must be optional") == true)
		let db = Database(configuration: try RecursiveStubConfig())
		#expect(throws: CRUDDecoderError.self) { _ = try db.table(Endless.self).select() }
	}
}
