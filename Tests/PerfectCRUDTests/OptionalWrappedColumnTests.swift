import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - @ForeignKey / @PrimaryKey wrapping an Optional value
//
// Synthesized Codable decodes a property wrapper with `decode(Wrapper.self, forKey:)`, not
// `decodeIfPresent`, even when the wrapped value is Optional. The column name decoder only
// marked a column optional from `decodeIfPresent`, so `@ForeignKey(...) var parentId: Int?`
// produced a non-optional column (NOT NULL in every connector), typed `Optional<Int>`
// (a JSON column in MySQL). Writing nil threw, and reading went through the JSON fallback.
//
// Every type is unique to one test, so the table structure cache needs no clearing.

private enum OptionalFKStructureScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var ownerId: Int
	}
}

private enum OptionalPKScope {
	struct Model: Codable {
		@PrimaryKey var key: Int?
		let name: String
	}
}

private enum OptionalFKInsertScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		init(id: Int, parentId: Int?) {
			self.id = id
			self.parentId = parentId
		}
	}
}

private enum OptionalFKUpdateScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		init(id: Int, parentId: Int?) {
			self.id = id
			self.parentId = parentId
		}
	}
}

private enum OptionalFKRoundTripScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
	}
}

private enum OptionalFKUnsetScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		init(id: Int) {
			self.id = id
		}
	}
}

private enum OptionalFKWhereScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
	}
}

private enum OptionalStringFKScope {
	struct Country: Codable {
		@PrimaryKey var code: String
	}
	struct City: Codable {
		let id: Int
		@ForeignKey(Country.self, onDelete: setNull, onUpdate: cascade)
		var countryCode: String?
		init(id: Int, countryCode: String?) {
			self.id = id
			self.countryCode = countryCode
		}
	}
}

private enum MixedScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Ref: Codable {
		@PrimaryKey var uuid: UUID
	}
	struct Model: Codable {
		let id: Int
		let flagA: Bool
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var first: Int?
		let flagB: Bool
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var second: Int?
		@ForeignKey(Ref.self, onDelete: setNull, onUpdate: restrict)
		var ref: UUID?
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var owner: Int
		let plain: Int?
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var nested: Int??
		init(id: Int, first: Int?, second: Int?, ref: UUID?, owner: Int, nested: Int??) {
			self.id = id
			flagA = true
			flagB = false
			plain = nil
			self.first = first
			self.second = second
			self.ref = ref
			self.owner = owner
			self.nested = nested
		}
	}
}

// Records the SQL and bindings of every statement, and returns no rows.
private final class RecordingStore: @unchecked Sendable {
	private let lock = NSLock()
	private var _statements: [(sql: String, bindings: Bindings)] = []
	var statements: [(sql: String, bindings: Bindings)] {
		lock.lock(); defer { lock.unlock() }
		return _statements
	}
	func record(_ sql: String, _ bindings: Bindings) {
		lock.lock(); defer { lock.unlock() }
		_statements.append((sql, bindings))
	}
}

private final class RecordingExeDelegate: SQLExeDelegate, @unchecked Sendable {
	let store: RecordingStore
	let sql: String
	init(store: RecordingStore, sql: String) {
		self.store = store
		self.sql = sql
	}
	func bind(_ bindings: Bindings, skip: Int) throws {
		store.record(sql, Array(bindings.dropFirst(skip)))
	}
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

private final class RecordingConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let store = RecordingStore()
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		RecordingExeDelegate(store: store, sql: sql)
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

// A single row whose values are read through `CRUDColumnValueDecoder` for wrapped columns,
// the way the connectors (Perfect-MySQL, -SQLite, -PostgreSQL) do. A missing value is NULL.
private struct RowContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
	let row: [String: CRUDExpression]
	var codingPath: [CodingKey] = []
	var allKeys: [K] { row.keys.compactMap { K(stringValue: $0) } }
	func contains(_ key: K) -> Bool { true }
	func decodeNil(forKey key: K) throws -> Bool {
		switch row[key.stringValue] {
		case nil, .null?: return true
		default: return false
		}
	}
	func decode(_ type: Int.Type, forKey key: K) throws -> Int {
		guard case .integer(let i)? = row[key.stringValue] else {
			throw CRUDDecoderError("RowContainer: expected Int for \(key.stringValue)")
		}
		return i
	}
	func decode(_ type: Bool.Type, forKey key: K) throws -> Bool { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: String.Type, forKey key: K) throws -> String { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Double.Type, forKey key: K) throws -> Double { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Float.Type, forKey key: K) throws -> Float { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { throw CRUDDecoderError("Unsupported") }
	func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { throw CRUDDecoderError("Unsupported") }
	// Like the connectors: wrapped values go through the wrapper's own init(from:), and
	// anything else generic is the JSON fallback, which a NULL or integer column can't satisfy.
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
		if SpecialType(type) == .wrapped {
			return try T(from: CRUDColumnValueDecoder(source: KeyedDecodingContainer(self), key: key))
		}
		throw CRUDDecoderError("RowContainer: unsupported generic type \(T.self) for \(key.stringValue)")
	}
	func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
		throw CRUDDecoderError("Unsupported")
	}
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer { throw CRUDDecoderError("Unsupported") }
	func superDecoder() throws -> Decoder { throw CRUDDecoderError("Unsupported") }
	func superDecoder(forKey key: K) throws -> Decoder { throw CRUDDecoderError("Unsupported") }
}

private struct RowDecoder: Decoder {
	let row: [String: CRUDExpression]
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey: Any] = [:]
	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		KeyedDecodingContainer(RowContainer<Key>(row: row))
	}
	func unkeyedContainer() throws -> UnkeyedDecodingContainer { throw CRUDDecoderError("Unsupported") }
	func singleValueContainer() throws -> SingleValueDecodingContainer { throw CRUDDecoderError("Unsupported") }
}

private func binding(_ statement: (sql: String, bindings: Bindings), column: String) -> CRUDExpression? {
	// The stub gen delegate names every binding "?", so map them by column order in the SQL.
	guard let open = statement.sql.firstIndex(of: "("),
		  let close = statement.sql[open...].firstIndex(of: ")") else {
		return nil
	}
	let columns = statement.sql[statement.sql.index(after: open)..<close]
		.split(separator: ",")
		.map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
	guard let index = columns.firstIndex(of: column), index < statement.bindings.count else {
		return nil
	}
	return statement.bindings[index].1
}

private func isNull(_ expr: CRUDExpression?) -> Bool {
	if case .null? = expr { return true }
	return false
}

@Suite("Optional wrapped columns")
struct OptionalWrappedColumnTests {

	@Test("An optional @ForeignKey is a nullable column of the unwrapped type")
	func optionalForeignKeyColumn() throws {
		let structure = try OptionalFKStructureScope.Child.CRUDTableStructure()
		let parentId = try #require(structure.columns.first { $0.name == "parentId" })
		#expect(parentId.optional)
		#expect(ObjectIdentifier(parentId.type) == ObjectIdentifier(Int.self))
		#expect(parentId.properties.contains { if case .foreignKey(_, "id", .setNull, .restrict) = $0 { true } else { false } })
		// A non-optional @ForeignKey is unchanged.
		let ownerId = try #require(structure.columns.first { $0.name == "ownerId" })
		#expect(!ownerId.optional)
		#expect(ObjectIdentifier(ownerId.type) == ObjectIdentifier(Int.self))
	}

	@Test("An optional @PrimaryKey is a nullable column of the unwrapped type")
	func optionalPrimaryKeyColumn() throws {
		let structure = try OptionalPKScope.Model.CRUDTableStructure()
		let key = try #require(structure.columns.first { $0.name == "key" })
		#expect(structure.primaryKeyName == "key")
		#expect(key.optional)
		#expect(ObjectIdentifier(key.type) == ObjectIdentifier(Int.self))
	}

	@Test("Inserting nil and non-nil optional foreign keys binds NULL and the value")
	func insertBindsNull() throws {
		typealias Child = OptionalFKInsertScope.Child
		let config = try RecordingConfig()
		let db = Database(configuration: config)
		let table = db.table(Child.self)
		try table.insert([Child(id: 1, parentId: nil), Child(id: 2, parentId: 7)])
		let inserts = config.store.statements.filter { $0.sql.hasPrefix("INSERT") }
		try #require(inserts.count == 2)
		#expect(isNull(binding(inserts[0], column: "parentId")))
		guard case .integer(7)? = binding(inserts[1], column: "parentId") else {
			Issue.record("Expected parentId = 7, got \(String(describing: binding(inserts[1], column: "parentId")))")
			return
		}
	}

	@Test("Updating an optional foreign key to nil binds NULL")
	func updateBindsNull() throws {
		typealias Child = OptionalFKUpdateScope.Child
		let config = try RecordingConfig()
		let db = Database(configuration: config)
		let table = db.table(Child.self)
		try table.where(\Child.id == 1).update(Child(id: 1, parentId: nil))
		let update = try #require(config.store.statements.first { $0.sql.hasPrefix("UPDATE") })
		let sql = update.sql.replacingOccurrences(of: "\n", with: " ")
		// SET "id"=?, "parentId"=? WHERE "id" = ?
		#expect(sql.contains("\"parentId\"=?"), "SQL was: \(sql)")
		try #require(update.bindings.count == 3, "SQL was: \(sql)")
		#expect(isNull(update.bindings[1].1))
	}

	@Test("A row with a NULL or an integer optional foreign key decodes")
	func rowDecodes() throws {
		typealias Child = OptionalFKRoundTripScope.Child
		let null = try Child(from: RowDecoder(row: ["id": .integer(1), "parentId": .null]))
		#expect(null.id == 1)
		#expect(null.parentId == nil)
		let missing = try Child(from: RowDecoder(row: ["id": .integer(2)]))
		#expect(missing.parentId == nil)
		let set = try Child(from: RowDecoder(row: ["id": .integer(3), "parentId": .integer(1)]))
		#expect(set.parentId == 1)
	}

	@Test("An optional foreign key left unset reads, encodes and inserts as nil")
	func unsetOptionalForeignKey() throws {
		typealias Child = OptionalFKUnsetScope.Child
		let child = Child(id: 1)
		#expect(child.parentId == nil)
		let json = try JSONEncoder().encode(child)
		let decoded = try JSONDecoder().decode(Child.self, from: json)
		#expect(decoded.parentId == nil)
		let config = try RecordingConfig()
		try Database(configuration: config).table(Child.self).insert(child)
		let insert = try #require(config.store.statements.first { $0.sql.hasPrefix("INSERT") })
		#expect(isNull(binding(insert, column: "parentId")))
	}

	@Test("A where clause on an optional foreign key names its column")
	func whereOnOptionalForeignKey() throws {
		typealias Child = OptionalFKWhereScope.Child
		let db = Database(configuration: try RecordingConfig())
		let table = db.table(Child.self)
		let equal = try #require(try table.where(\Child.parentId == 5).select().sqlGenState.statements.first)
		#expect(equal.sql.contains("\"parentId\" = ?"), "SQL was: \(equal.sql)")
		let null = try #require(try table.where(\Child.parentId == nil).select().sqlGenState.statements.first)
		#expect(null.sql.contains("\"parentId\" IS NULL"), "SQL was: \(null.sql)")
	}

	@Test("An optional String @ForeignKey to a String @PrimaryKey")
	func optionalStringForeignKey() throws {
		typealias City = OptionalStringFKScope.City
		let structure = try City.CRUDTableStructure()
		let column = try #require(structure.columns.first { $0.name == "countryCode" })
		#expect(column.optional)
		#expect(ObjectIdentifier(column.type) == ObjectIdentifier(String.self))
		#expect(column.properties.contains { if case .foreignKey(_, "code", .setNull, .cascade) = $0 { true } else { false } })
		let config = try RecordingConfig()
		let table = Database(configuration: config).table(City.self)
		try table.insert([City(id: 1, countryCode: nil), City(id: 2, countryCode: "CA")])
		let inserts = config.store.statements.filter { $0.sql.hasPrefix("INSERT") }
		try #require(inserts.count == 2)
		#expect(isNull(binding(inserts[0], column: "countryCode")))
		guard case .string("CA")? = binding(inserts[1], column: "countryCode") else {
			Issue.record("Expected countryCode = CA, got \(String(describing: binding(inserts[1], column: "countryCode")))")
			return
		}
		let select = try #require(try table.where(\City.countryCode == "CA").select().sqlGenState.statements.first)
		#expect(select.sql.contains("\"countryCode\" = ?"), "SQL was: \(select.sql)")
	}

	@Test("Several optional foreign keys next to Bools, a UUID?, a plain optional and an Int??")
	func mixedColumns() throws {
		typealias Model = MixedScope.Model
		let structure = try Model.CRUDTableStructure()
		func column(_ name: String) throws -> TableStructure.Column {
			try #require(structure.columns.first { $0.name == name })
		}
		for (name, type, optional) in [("first", Int.self as Any.Type, true), ("second", Int.self, true),
									   ("ref", UUID.self, true), ("owner", Int.self, false),
									   ("plain", Int.self, true), ("nested", Int.self, true)] {
			let c = try column(name)
			#expect(c.optional == optional, "\(name)")
			#expect(ObjectIdentifier(c.type) == ObjectIdentifier(type), "\(name): \(c.type)")
		}
		let db = Database(configuration: try RecordingConfig())
		let table = db.table(Model.self)
		for (expr, fragment) in [(\Model.first == 1, "\"first\" = ?"), (\Model.second == 1, "\"second\" = ?"),
								 (\Model.second != nil, "\"second\" IS NOT NULL"), (\Model.first == nil, "\"first\" IS NULL"),
								 (\Model.ref == UUID(), "\"ref\" = ?"), (\Model.owner == 1, "\"owner\" = ?")] {
			let sql = try #require(try table.where(expr).select().sqlGenState.statements.first).sql
			#expect(sql.contains(fragment), "SQL was: \(sql)")
		}
		let config = try RecordingConfig()
		let uuid = UUID()
		try Database(configuration: config).table(Model.self).insert([
			Model(id: 1, first: nil, second: 4, ref: nil, owner: 1, nested: .some(nil)),
			Model(id: 2, first: 3, second: nil, ref: uuid, owner: 1, nested: 6)])
		let inserts = config.store.statements.filter { $0.sql.hasPrefix("INSERT") }
		try #require(inserts.count == 2)
		#expect(isNull(binding(inserts[0], column: "first")))
		#expect(isNull(binding(inserts[0], column: "ref")))
		#expect(isNull(binding(inserts[0], column: "nested")))
		#expect(isNull(binding(inserts[1], column: "second")))
		#expect(binding(inserts[0], column: "second").map { String(describing: $0) } == String(describing: CRUDExpression.integer(4)))
		#expect(binding(inserts[1], column: "first").map { String(describing: $0) } == String(describing: CRUDExpression.integer(3)))
		#expect(binding(inserts[1], column: "ref").map { String(describing: $0) } == String(describing: CRUDExpression.uuid(uuid)))
		#expect(binding(inserts[1], column: "nested").map { String(describing: $0) } == String(describing: CRUDExpression.integer(6)))
	}
}
