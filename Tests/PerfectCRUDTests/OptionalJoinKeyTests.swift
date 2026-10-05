import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - Joins on an optional key
//
// The main use for an optional foreign key is a parent→children relation where a child may
// have no parent. `join(_:on:equals:)` required the same key type on both sides, so
// `on: \Parent.id` (Int) with `equals: \Child.parentId` (Int?) didn't compile. With an
// optional key on the parent side too, it compiled, but every join row threw
// "Invalid join comparison type Optional<Int>" and SelectIterator swallowed the error,
// so select() returned no rows at all. A child whose key is NULL must simply not match.
//
// Every type is unique to one test, so the table structure cache needs no clearing.

// MARK: Canned-row connector
//
// Serves fixed rows per table, matched on the first `FROM "<table>"` in the statement.
// The join rows are filtered in memory by PerfectCRUD itself, so every row of the joined
// table is returned, as an unfiltered LEFT JOIN would. A nil value is a NULL column.

private final class CannedGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	func getBinding(for expr: CRUDExpression) throws -> String {
		bindings.append(("?", expr))
		return "?"
	}
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
}

private typealias CannedRow = [String: Any?]

private final class CannedExeDelegate: SQLExeDelegate, @unchecked Sendable {
	let rows: [CannedRow]
	var index = -1
	init(rows: [CannedRow]) {
		self.rows = rows
	}
	func bind(_ bindings: Bindings, skip: Int) throws {}
	func hasNext() throws -> Bool {
		index += 1
		return index < rows.count
	}
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? {
		guard rows.indices.contains(index) else { return nil }
		return KeyedDecodingContainer(CannedRowReader<A>(row: rows[index]))
	}
}

private final class CannedConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let tables: [String: [CannedRow]]
	var capturedSQL: [String] = []
	init(tables: [String: [CannedRow]]) {
		self.tables = tables
	}
	var sqlGenDelegate: SQLGenDelegate { CannedGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		capturedSQL.append(sql)
		guard let range = sql.range(of: #"FROM "[^"]+""#, options: .regularExpression) else {
			throw CRUDSQLExeError("CannedConfig: no table in \(sql)")
		}
		let table = String(sql[range].dropFirst(6).dropLast())
		return CannedExeDelegate(rows: tables[table] ?? [])
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {
		tables = [:]
	}
}

private struct CannedRowReader<K: CodingKey>: KeyedDecodingContainerProtocol {
	let row: CannedRow
	var codingPath: [CodingKey] = []
	var allKeys: [K] { row.keys.compactMap { K(stringValue: $0) } }
	func contains(_ key: K) -> Bool { row[key.stringValue] != nil }
	func decodeNil(forKey key: K) throws -> Bool {
		guard let value = row[key.stringValue] else {
			throw CRUDDecoderError("CannedRowReader: no column \(key.stringValue)")
		}
		return value == nil
	}
	private func value<T>(_ key: K) throws -> T {
		guard let value = row[key.stringValue] else {
			throw CRUDDecoderError("CannedRowReader: no column \(key.stringValue)")
		}
		guard let typed = value as? T else {
			throw CRUDDecoderError("CannedRowReader: \(key.stringValue) is \(String(describing: value)), not \(T.self)")
		}
		return typed
	}
	func decode(_ type: Bool.Type, forKey key: K) throws -> Bool { try value(key) }
	func decode(_ type: String.Type, forKey key: K) throws -> String { try value(key) }
	func decode(_ type: Double.Type, forKey key: K) throws -> Double { try value(key) }
	func decode(_ type: Float.Type, forKey key: K) throws -> Float { try value(key) }
	func decode(_ type: Int.Type, forKey key: K) throws -> Int { try value(key) }
	func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { try value(key) }
	func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { try value(key) }
	func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { try value(key) }
	func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { try value(key) }
	func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { try value(key) }
	func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { try value(key) }
	func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { try value(key) }
	func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { try value(key) }
	func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { try value(key) }
	// Date, UUID and wrappers. A wrapper decodes its value through a single-value container.
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
		if let typed = row[key.stringValue] as? T {
			return typed
		}
		return try T(from: CannedValueDecoder(value: row[key.stringValue] ?? nil))
	}
	func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
		throw CRUDDecoderError("CannedRowReader: nested containers unsupported")
	}
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("CannedRowReader: unkeyed containers unsupported")
	}
	func superDecoder() throws -> Decoder { throw CRUDDecoderError("CannedRowReader: superDecoder unsupported") }
	func superDecoder(forKey key: K) throws -> Decoder { throw CRUDDecoderError("CannedRowReader: superDecoder unsupported") }
}

private struct CannedValueDecoder: Decoder, SingleValueDecodingContainer {
	let value: Any?
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey: Any] = [:]
	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		throw CRUDDecoderError("CannedValueDecoder: keyed containers unsupported")
	}
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("CannedValueDecoder: unkeyed containers unsupported")
	}
	func singleValueContainer() throws -> SingleValueDecodingContainer { self }
	func decodeNil() -> Bool { value == nil }
	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		if let typed = value as? T {
			return typed
		}
		if T.self is CRUDOptional.Type {
			return try T(from: self)
		}
		throw CRUDDecoderError("CannedValueDecoder: \(String(describing: value)) is not \(T.self)")
	}
}

private func cannedDB(_ tables: [String: [CannedRow]]) -> (Database<CannedConfig>, CannedConfig) {
	let config = CannedConfig(tables: tables)
	return (Database(configuration: config), config)
}

// MARK: Models

private enum WrappedFKScope {
	struct Parent: Codable {
		let id: Int
		let name: String
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
	}
}

private enum PlainFKScope {
	struct Parent: Codable {
		let id: Int
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		let parentId: Int?
	}
}

private enum OptionalBothScope {
	struct Parent: Codable {
		let id: Int
		let code: Int?
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		let parentCode: Int?
	}
}

private enum OptionalParentScope {
	struct Parent: Codable {
		let id: Int
		let code: String?
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		let parentCode: String
	}
}

// A self-referencing tree: the main reason to have an optional foreign key.
private enum TreeScope {
	struct Node: Codable {
		let id: Int
		@ForeignKey(Node.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		var children: [Node]?
	}
}

private enum UUIDScope {
	struct Parent: Codable {
		let id: UUID
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		let parentId: UUID?
	}
}

private enum PivotScope {
	struct Parent: Codable {
		let id: Int
		let code: Int?
		var tags: [Tag]?
	}
	struct Tag: Codable {
		let id: Int
		let name: String
	}
	struct ParentTag: Codable {
		let parentCode: Int?
		let tagId: Int
	}
}

private enum PlainPivotScope {
	struct Parent: Codable {
		let id: Int
		var tags: [Tag]?
	}
	struct Tag: Codable {
		let id: Int
	}
	struct ParentTag: Codable {
		let parentId: Int
		let tagId: Int
	}
}

private enum UnsupportedKeyScope {
	struct Parent: Codable {
		let id: Int
		let link: URL?
		var children: [Child]?
	}
	struct Child: Codable {
		let id: Int
		let link: URL
	}
}

// MARK: Tests

@Suite("Joins on optional keys")
struct OptionalJoinKeyTests {
	@Test func wrappedOptionalForeignKeyJoinsAndNullMatchesNothing() throws {
		typealias P = WrappedFKScope.Parent
		let (db, config) = cannedDB([
			"Parent": [["id": 1, "name": "one"], ["id": 2, "name": "two"]],
			"Child": [["id": 10, "parentId": 1], ["id": 11, "parentId": nil], ["id": 12, "parentId": 1], ["id": 13, "parentId": 2]],
		])
		let parents = try db.table(P.self)
			.join(\.children, on: \.id, equals: \.parentId)
			.order(by: \.id)
			.select().map { $0 }
		#expect(parents.map(\.id) == [1, 2])
		#expect(parents.map { $0.children?.map(\.id) } == [[10, 12], [13]])
		#expect(config.capturedSQL.contains { $0.contains(#"ON "t0"."id" = "t1"."parentId""#) })
	}

	@Test func plainOptionalForeignKeyJoins() throws {
		let (db, _) = cannedDB([
			"Parent": [["id": 1], ["id": 2]],
			"Child": [["id": 10, "parentId": nil], ["id": 11, "parentId": 2]],
		])
		let parents = try db.table(PlainFKScope.Parent.self)
			.join(\.children, on: \.id, equals: \.parentId)
			.select().map { $0 }
		#expect(parents.map { $0.children?.map(\.id) } == [[], [11]])
	}

	@Test func optionalKeyOnBothSides() throws {
		let (db, _) = cannedDB([
			"Parent": [["id": 1, "code": 7], ["id": 2, "code": nil]],
			"Child": [["id": 10, "parentCode": 7], ["id": 11, "parentCode": nil], ["id": 12, "parentCode": 7]],
		])
		let parents = try db.table(OptionalBothScope.Parent.self)
			.join(\.children, on: \.code, equals: \.parentCode)
			.select().map { $0 }
		// NULL never equals NULL: the parent with no code gets no children, not the orphans.
		#expect(parents.map(\.id) == [1, 2])
		#expect(parents.map { $0.children?.map(\.id) } == [[10, 12], []])
	}

	@Test func optionalKeyOnParentSideOnly() throws {
		let (db, _) = cannedDB([
			"Parent": [["id": 1, "code": "x"], ["id": 2, "code": nil]],
			"Child": [["id": 10, "parentCode": "x"], ["id": 11, "parentCode": "y"]],
		])
		let parents = try db.table(OptionalParentScope.Parent.self)
			.join(\.children, on: \.code, equals: \.parentCode)
			.select().map { $0 }
		#expect(parents.map { $0.children?.map(\.id) } == [[10], []])
	}

	@Test func selfReferencingTree() throws {
		typealias N = TreeScope.Node
		let rows: [CannedRow] = [
			["id": 1, "parentId": nil],
			["id": 2, "parentId": 1],
			["id": 3, "parentId": 1],
			["id": 4, "parentId": 2],
		]
		let (db, _) = cannedDB(["Node": rows])
		let nodes = try db.table(N.self)
			.join(\.children, on: \.id, equals: \.parentId)
			.select().map { $0 }
		let byId = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.children?.map(\.id)) })
		#expect(byId == [1: [2, 3], 2: [4], 3: [], 4: []])
	}

	@Test func optionalUUIDKey() throws {
		let a = UUID(), b = UUID()
		let (db, _) = cannedDB([
			"Parent": [["id": a], ["id": b]],
			"Child": [["id": 10, "parentId": b], ["id": 11, "parentId": nil]],
		])
		let parents = try db.table(UUIDScope.Parent.self)
			.join(\.children, on: \.id, equals: \.parentId)
			.select().map { $0 }
		#expect(parents.map { $0.children?.map(\.id) } == [[], [10]])
	}

	@Test func pivotJoinOnOptionalKey() throws {
		typealias P = PivotScope.Parent
		// The pivot query selects the parent's key as `_crud_pivot_id_`; NULL for a tag that
		// no parent with a code links to.
		let (db, _) = cannedDB([
			"Parent": [["id": 1, "code": 5], ["id": 2, "code": nil]],
			"Tag": [
				["id": 100, "name": "a", joinPivotIdColumnName: 5],
				["id": 101, "name": "b", joinPivotIdColumnName: nil],
			],
		])
		let parents = try db.table(P.self)
			.join(\.tags, with: PivotScope.ParentTag.self,
				  on: \.code, equals: \.parentCode,
				  and: \.id, is: \.tagId)
			.select().map { $0 }
		#expect(parents.map { $0.tags?.map(\.id) } == [[100], []])
	}

	// The pivot query LEFT JOINs from the joined table, so a tag no parent links to comes back
	// with a NULL pivot id. SQLite and PostgreSQL decoded that as 0 and attached the tag to a
	// parent whose id is 0; Perfect-MySQL threw. It must match nothing.
	@Test func pivotJoinWithUnlinkedRowMatchesNothing() throws {
		let (db, _) = cannedDB([
			"Parent": [["id": 0], ["id": 1]],
			"Tag": [
				["id": 100, joinPivotIdColumnName: 1],
				["id": 101, joinPivotIdColumnName: nil],
			],
		])
		let parents = try db.table(PlainPivotScope.Parent.self)
			.join(\.tags, with: PlainPivotScope.ParentTag.self,
				  on: \.id, equals: \.parentId,
				  and: \.id, is: \.tagId)
			.select().map { $0 }
		#expect(parents.map { $0.tags?.map(\.id) } == [[], [100]])
	}

	// count() builds the same state, so it throws too.
	@Test func unsupportedKeyTypeThrowsFromCount() throws {
		let (db, _) = cannedDB([:])
		#expect(throws: CRUDSQLGenError.self) {
			_ = try db.table(UnsupportedKeyScope.Parent.self)
				.join(\.children, on: \.link, equals: \.link)
				.count()
		}
	}

	// An unsupported key type used to surface only as an empty result. It must throw from select().
	@Test func unsupportedKeyTypeThrowsFromSelect() throws {
		let (db, _) = cannedDB([
			"Parent": [["id": 1, "link": URL(string: "http://a/")!]],
			"Child": [["id": 10, "link": URL(string: "http://a/")!]],
		])
		#expect(throws: CRUDSQLGenError.self) {
			_ = try db.table(UnsupportedKeyScope.Parent.self)
				.join(\.children, on: \.link, equals: \.link)
				.select()
		}
	}
}
