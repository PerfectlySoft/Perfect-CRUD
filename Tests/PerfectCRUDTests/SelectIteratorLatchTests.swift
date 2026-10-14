import Testing
import Foundation
@testable import PerfectCRUD

// A SelectIterator that had returned nil, or had thrown, used to call into the connector again on
// the next call. Perfect-MySQL re-runs the statement (restarting at row 1, or throwing when it has
// bindings), and every connector carried on past a row that failed to decode. This stub behaves
// like the first: once its rows run out, the next hasNext() starts again from the first row.

private struct LatchRow: Codable { var id: Int }

private final class RestartingExeDelegate: SQLExeDelegate, @unchecked Sendable {
	let rows: [CRUDExpression]
	var index = -1
	init(rows: [CRUDExpression]) { self.rows = rows }
	func bind(_ bindings: Bindings, skip: Int) throws {}
	func hasNext() throws -> Bool {
		index += 1
		if index >= rows.count {
			index = -1 // re-executes on the next call
			return false
		}
		return true
	}
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? {
		KeyedDecodingContainer(LatchRowContainer<A>(value: rows[index]))
	}
}

private struct LatchRowContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
	let value: CRUDExpression
	var codingPath: [CodingKey] = []
	var allKeys: [K] { [] }
	func contains(_ key: K) -> Bool { true }
	func decodeNil(forKey key: K) throws -> Bool { false }
	func decode(_ type: Int.Type, forKey key: K) throws -> Int {
		guard case .integer(let i) = value else { throw CRUDDecoderError("not an Int") }
		return i
	}
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T { throw CRUDDecoderError("unsupported") }
	func nestedContainer<N: CodingKey>(keyedBy type: N.Type, forKey key: K) throws -> KeyedDecodingContainer<N> { throw CRUDDecoderError("unsupported") }
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer { throw CRUDDecoderError("unsupported") }
	func superDecoder() throws -> Decoder { throw CRUDDecoderError("unsupported") }
	func superDecoder(forKey key: K) throws -> Decoder { throw CRUDDecoderError("unsupported") }
}

private final class LatchConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var rows: [CRUDExpression] = []
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate { RestartingExeDelegate(rows: rows) }
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

@Suite("SelectIterator stays finished", .serialized)
struct SelectIteratorLatchTests {
	private func select(_ rows: [CRUDExpression]) throws -> Select<LatchRow, Table<LatchRow, Database<LatchConfig>>> {
		CRUDClearTableStructureCache()
		let config = try LatchConfig()
		config.rows = rows
		return try Database(configuration: config).table(LatchRow.self).select()
	}

	@Test func nilIsFinal() throws {
		var rows = try select([.integer(1), .integer(2)]).makeThrowingIterator()
		#expect(try rows.nextElement()?.id == 1)
		#expect(try rows.nextElement()?.id == 2)
		#expect(try rows.nextElement() == nil)
		#expect(try rows.nextElement() == nil) // used to be row 1 again
		#expect(rows.next() == nil)

		var iterator = try select([.integer(1)]).makeIterator()
		#expect(iterator.next()?.id == 1)
		#expect(iterator.next() == nil)
		#expect(iterator.next() == nil) // used to be row 1 again
	}

	@Test func anErrorIsFinal() throws {
		var rows = try select([.integer(1), .string("bad"), .integer(3)]).makeThrowingIterator()
		#expect(try rows.nextElement()?.id == 1)
		#expect(throws: CRUDDecoderError.self) { _ = try rows.nextElement() }
		#expect(try rows.nextElement() == nil) // used to be row 3
		#expect(rows.next() == nil)

		var iterator = try select([.integer(1), .string("bad"), .integer(3)]).makeIterator()
		#expect(iterator.next()?.id == 1)
		#expect(iterator.next() == nil)
		#expect(iterator.next() == nil) // used to be row 3
	}
}
