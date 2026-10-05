import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - Decoding a @ForeignKey / @PrimaryKey wrapping an Optional from an absent key
//
// Synthesized Codable decodes a property wrapper with `decode(Wrapper.self, forKey:)`, never
// `decodeIfPresent`, so `{"id":1}` threw `keyNotFound` for `@ForeignKey(...) var parentId: Int?`
// where a plain `let parentId: Int?` decodes nil. API payloads often omit null fields.
//
// Every type is unique to one test, so the table structure cache needs no clearing.

private enum AbsentFKScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
	}
}

private enum AbsentPKScope {
	struct Model: Codable {
		@PrimaryKey var key: Int?
		let name: String
	}
}

private enum AbsentNonOptionalScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var ownerId: Int
		@PrimaryKey var key: String
	}
}

private enum AbsentNestedScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var nested: Int??
	}
}

private enum AbsentEncodeScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		@PrimaryKey var key: UUID?
		let plain: Int?
		init(id: Int, parentId: Int?, key: UUID?) {
			self.id = id
			plain = nil
			self.parentId = parentId
			self.key = key
		}
	}
}

private enum AbsentCRUDDecodersScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		@PrimaryKey var key: Int?
		@ForeignKey(Parent.self, onDelete: cascade, onUpdate: cascade)
		var ownerId: Int
		let plain: Int?
		init(id: Int, parentId: Int?, key: Int?, ownerId: Int) {
			self.id = id
			plain = nil
			self.parentId = parentId
			self.key = key
			self.ownerId = ownerId
		}
	}
}

private enum AbsentRowScope {
	struct Parent: Codable {
		let id: Int
	}
	struct Child: Codable {
		let id: Int
		@ForeignKey(Parent.self, onDelete: setNull, onUpdate: restrict)
		var parentId: Int?
		@PrimaryKey var key: Int?
		let plain: Int?
	}
}

// A single row from a result set that may not include every column, like the connectors'
// row readers: `contains` is false for a column the result set doesn't have, and reading it
// throws. Records which keys were asked about.
private final class SparseRowLog: @unchecked Sendable {
	var contains: [String] = []
	var decodeNil: [String] = []
}

private struct SparseRowContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
	let row: [String: CRUDExpression]
	let log: SparseRowLog
	var codingPath: [CodingKey] = []
	var allKeys: [K] { row.keys.compactMap { K(stringValue: $0) } }
	func contains(_ key: K) -> Bool {
		log.contains.append(key.stringValue)
		return row[key.stringValue] != nil
	}
	func value(_ key: K) throws -> CRUDExpression {
		guard let value = row[key.stringValue] else {
			throw CRUDDecoderError("SparseRowContainer: no column \(key.stringValue)")
		}
		return value
	}
	func decodeNil(forKey key: K) throws -> Bool {
		log.decodeNil.append(key.stringValue)
		if case .null = try value(key) { return true }
		return false
	}
	func decode(_ type: Int.Type, forKey key: K) throws -> Int {
		guard case .integer(let i) = try value(key) else {
			throw CRUDDecoderError("SparseRowContainer: expected Int for \(key.stringValue)")
		}
		return i
	}
	func decode(_ type: String.Type, forKey key: K) throws -> String {
		guard case .string(let s) = try value(key) else {
			throw CRUDDecoderError("SparseRowContainer: expected String for \(key.stringValue)")
		}
		return s
	}
	func decode(_ type: Bool.Type, forKey key: K) throws -> Bool { throw CRUDDecoderError("Unsupported") }
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
	// Like the connectors: wrapped values go through the wrapper's own init(from:).
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
		if SpecialType(type) == .wrapped {
			return try T(from: CRUDColumnValueDecoder(source: KeyedDecodingContainer(self), key: key))
		}
		throw CRUDDecoderError("SparseRowContainer: unsupported generic type \(T.self) for \(key.stringValue)")
	}
	func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
		throw CRUDDecoderError("Unsupported")
	}
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer { throw CRUDDecoderError("Unsupported") }
	func superDecoder() throws -> Decoder { throw CRUDDecoderError("Unsupported") }
	func superDecoder(forKey key: K) throws -> Decoder { throw CRUDDecoderError("Unsupported") }
}

private struct SparseRowDecoder: Decoder {
	let row: [String: CRUDExpression]
	let log = SparseRowLog()
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey: Any] = [:]
	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		KeyedDecodingContainer(SparseRowContainer<Key>(row: row, log: log))
	}
	func unkeyedContainer() throws -> UnkeyedDecodingContainer { throw CRUDDecoderError("Unsupported") }
	func singleValueContainer() throws -> SingleValueDecodingContainer { throw CRUDDecoderError("Unsupported") }
}

// Records the SQL of every statement, and returns no rows.
private final class AbsentRecordingConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	private let lock = NSLock()
	private var _statements: [String] = []
	var statements: [String] {
		lock.lock(); defer { lock.unlock() }
		return _statements
	}
	func record(_ sql: String) {
		lock.lock(); defer { lock.unlock() }
		_statements.append(sql.replacingOccurrences(of: "\n", with: " "))
	}
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		AbsentRecordingExeDelegate(config: self, sql: sql)
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

private final class AbsentRecordingExeDelegate: SQLExeDelegate, @unchecked Sendable {
	let config: AbsentRecordingConfig
	let sql: String
	init(config: AbsentRecordingConfig, sql: String) {
		self.config = config
		self.sql = sql
	}
	func bind(_ bindings: Bindings, skip: Int) throws {
		config.record(sql)
	}
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

private func json<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
	try JSONDecoder().decode(type, from: Data(text.utf8))
}

private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
	let data = try JSONEncoder().encode(value)
	return try #require(try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any])
}

@Suite("Decoding optional wrapped columns from an absent key")
struct OptionalWrappedDecodingTests {

	@Test("An optional @ForeignKey decodes nil from an absent key, like a plain optional")
	func absentForeignKey() throws {
		typealias Child = AbsentFKScope.Child
		let absent = try json(Child.self, #"{"id":1}"#)
		#expect(absent.id == 1)
		#expect(absent.parentId == nil)
		// Absent decodes the same as null, down to the projected value.
		let null = try json(Child.self, #"{"id":2,"parentId":null}"#)
		#expect(null.parentId == nil)
		#expect(absent.$parentId.map { $0 == nil } == true)
		#expect(null.$parentId.map { $0 == nil } == true)
		let set = try json(Child.self, #"{"id":3,"parentId":7}"#)
		#expect(set.parentId == 7)
		// A present but mistyped value still throws.
		#expect(throws: DecodingError.self) { try json(Child.self, #"{"id":4,"parentId":"x"}"#) }
	}

	@Test("An optional @PrimaryKey decodes nil from an absent key")
	func absentPrimaryKey() throws {
		typealias Model = AbsentPKScope.Model
		let absent = try json(Model.self, #"{"name":"a"}"#)
		#expect(absent.key == nil)
		#expect(absent.name == "a")
		#expect(try json(Model.self, #"{"key":null,"name":"b"}"#).key == nil)
		#expect(try json(Model.self, #"{"key":5,"name":"c"}"#).key == 5)
	}

	@Test("A non-optional @ForeignKey or @PrimaryKey still requires its key")
	func absentNonOptionalThrows() throws {
		typealias Child = AbsentNonOptionalScope.Child
		#expect(try json(Child.self, #"{"id":1,"ownerId":2,"key":"k"}"#).ownerId == 2)
		for text in [#"{"id":1,"key":"k"}"#, #"{"id":1,"ownerId":2}"#] {
			#expect {
				try json(Child.self, text)
			} throws: { error in
				guard case DecodingError.keyNotFound = error else { return false }
				return true
			}
		}
	}

	@Test("A @ForeignKey wrapping an Int?? decodes nil from an absent key")
	func absentNestedOptional() throws {
		typealias Child = AbsentNestedScope.Child
		let absent = try json(Child.self, #"{"id":1}"#)
		#expect(absent.nested == .none)
		#expect(try json(Child.self, #"{"id":2,"nested":null}"#).nested == .none)
		#expect(try json(Child.self, #"{"id":3,"nested":4}"#).nested == 4)
		let structure = try Child.CRUDTableStructure()
		let column = try #require(structure.columns.first { $0.name == "nested" })
		#expect(column.optional)
		#expect(ObjectIdentifier(column.type) == ObjectIdentifier(Int.self))
	}

	// Encoding is left as it was: a nil optional wrapper writes an explicit null, where a plain
	// optional omits its key. Omitting it would need `encodeIfPresent` overloads on
	// `KeyedEncodingContainer`, and would change the JSON existing API clients receive.
	// Both forms now decode back to nil.
	@Test("A nil optional wrapper encodes an explicit null that round-trips")
	func encodesExplicitNull() throws {
		typealias Child = AbsentEncodeScope.Child
		let none = Child(id: 1, parentId: nil, key: nil)
		let object = try jsonObject(none)
		#expect(object["parentId"] is NSNull)
		#expect(object["key"] is NSNull)
		#expect(object["plain"] == nil, "a plain optional omits its key")
		let decoded = try JSONDecoder().decode(Child.self, from: try JSONEncoder().encode(none))
		#expect(decoded.parentId == nil)
		#expect(decoded.key == nil)
		let uuid = UUID()
		let some = Child(id: 2, parentId: 9, key: uuid)
		#expect(try jsonObject(some)["parentId"] as? Int == 9)
		let roundTripped = try JSONDecoder().decode(Child.self, from: try JSONEncoder().encode(some))
		#expect(roundTripped.parentId == 9)
		#expect(roundTripped.key == uuid)
	}

	@Test("CRUD's own decoders still see the columns: structure, key paths, insert and update")
	func crudDecodersUnchanged() throws {
		typealias Child = AbsentCRUDDecodersScope.Child
		let structure = try Child.CRUDTableStructure()
		#expect(structure.columns.map(\.name) == ["id", "parentId", "key", "ownerId", "plain"])
		#expect(structure.primaryKeyName == "key")
		for (name, optional) in [("id", false), ("parentId", true), ("key", true), ("ownerId", false), ("plain", true)] {
			let c = try #require(structure.columns.first { $0.name == name })
			#expect(c.optional == optional, "\(name)")
			#expect(ObjectIdentifier(c.type) == ObjectIdentifier(Int.self), "\(name): \(c.type)")
		}
		let parentId = try #require(structure.columns.first { $0.name == "parentId" })
		#expect(parentId.properties.contains { if case .foreignKey(_, "id", .setNull, .restrict) = $0 { true } else { false } })
		let key = try #require(structure.columns.first { $0.name == "key" })
		#expect(key.properties.contains { if case .primaryKey = $0 { true } else { false } })

		let pathDecoder = CRUDKeyPathsDecoder()
		let instance = try Child(from: pathDecoder)
		#expect(try pathDecoder.getKeyPathName(instance, keyPath: \Child.parentId) == "parentId")
		#expect(try pathDecoder.getKeyPathName(instance, keyPath: \Child.key) == "key")
		#expect(try pathDecoder.getKeyPathName(instance, keyPath: \Child.ownerId) == "ownerId")
		#expect(try pathDecoder.getKeyPathName(instance, keyPath: \Child.plain) == "plain")

		let config = try AbsentRecordingConfig()
		let table = Database(configuration: config).table(Child.self)
		try table.insert(Child(id: 1, parentId: nil, key: nil, ownerId: 2))
		try table.where(\Child.id == 1).update(Child(id: 1, parentId: 3, key: 4, ownerId: 2), setKeys: \.parentId, \.key)
		let insert = try #require(config.statements.first { $0.hasPrefix("INSERT") })
		#expect(insert.contains("(\"id\", \"parentId\", \"key\", \"ownerId\", \"plain\")"), "SQL was: \(insert)")
		let update = try #require(config.statements.first { $0.hasPrefix("UPDATE") })
		#expect(update.contains("\"parentId\"=?"), "SQL was: \(update)")
		#expect(update.contains("\"key\"=?"), "SQL was: \(update)")
		let select = try #require(try table.where(\Child.parentId == 3 && \Child.key == nil).select().sqlGenState.statements.first)
		#expect(select.sql.contains("\"parentId\" = ?"), "SQL was: \(select.sql)")
		#expect(select.sql.contains("\"key\" IS NULL"), "SQL was: \(select.sql)")
	}

	@Test("A row reader is asked contains and decodeNil, and a missing column reads nil like a plain optional")
	func rowReaderSeesColumn() throws {
		typealias Child = AbsentRowScope.Child
		let full = SparseRowDecoder(row: ["id": .integer(1), "parentId": .integer(2), "key": .integer(3), "plain": .integer(4)])
		let read = try Child(from: full)
		#expect(read.parentId == 2)
		#expect(read.key == 3)
		#expect(read.plain == 4)
		for name in ["parentId", "key", "plain"] {
			#expect(full.log.contains.contains(name), "\(name)")
			#expect(full.log.decodeNil.contains(name), "\(name)")
		}
		let nulls = try Child(from: SparseRowDecoder(row: ["id": .integer(1), "parentId": .null, "key": .null, "plain": .null]))
		#expect(nulls.parentId == nil)
		#expect(nulls.key == nil)
		#expect(nulls.plain == nil)
		let missing = SparseRowDecoder(row: ["id": .integer(1)])
		let sparse = try Child(from: missing)
		#expect(sparse.parentId == nil)
		#expect(sparse.key == nil)
		#expect(sparse.plain == nil)
		#expect(missing.log.decodeNil.isEmpty, "decodeNil isn't asked about a column the row lacks")
	}
}
