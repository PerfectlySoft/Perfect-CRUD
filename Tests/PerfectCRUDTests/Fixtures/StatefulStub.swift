import Foundation
@testable import PerfectCRUD

// MARK: - Shared stateful in-memory connector fixture
//
// The existing `StubExeDelegate` (PerfectCRUDTests.swift) and
// `DynamicStubExeDelegate` (same file) are both intentionally minimal: the
// former always returns `hasNext() == false` (fine for pure SQL-shape
// assertions), the latter fakes rows from a fixed, pre-seeded array (fine
// for the dynamic-row path). Neither can fake a real, mutable, typed row
// store -- which `DatabaseMigrator` genuinely needs (its bookkeeping reads
// back rows it just inserted). This fixture fills that gap.
//
// Deliberately narrow, per ADR-0001's implementation-plan review: it
// supports exactly what a migrator's bookkeeping needs -- CREATE as a
// no-op, INSERT appends a row, SELECT returns every row for a table,
// unfiltered. No WHERE-clause interpreter: parsing/honoring a WHERE clause
// would mean reimplementing a small SQL engine, and nothing here needs it
// (`DatabaseMigrator.migrate()` never filters a SELECT). Table/column names
// are recovered by pattern-matching PerfectCRUD's own known-shape generated
// SQL (`INSERT INTO "table" ("col", ...) VALUES (...)`, `FROM "table"`) --
// fragile in the general case, adequate for a fixture whose only clients
// are this package's own generated SQL.

final class StatefulRowStore: @unchecked Sendable {
	private let lock = NSLock()
	private var tables: [String: [[String: CRUDExpression]]] = [:]

	func insert(table: String, row: [String: CRUDExpression]) {
		lock.lock(); defer { lock.unlock() }
		tables[table, default: []].append(row)
	}
	func rows(table: String) -> [[String: CRUDExpression]] {
		lock.lock(); defer { lock.unlock() }
		return tables[table] ?? []
	}
	func removeAll(table: String) {
		lock.lock(); defer { lock.unlock() }
		tables[table] = []
	}
}

final class StatefulStubGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	func getBinding(for expr: CRUDExpression) throws -> String {
		bindings.append(("?", expr))
		return "?"
	}
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
}

final class StatefulStubExeDelegate: SQLExeDelegate, @unchecked Sendable {
	private let store: StatefulRowStore
	private let sql: String
	private var pendingRows: [[String: CRUDExpression]] = []
	private var rowIndex = 0
	private var fetchedRows = false

	init(store: StatefulRowStore, sql: String) {
		self.store = store
		self.sql = sql
	}

	func bind(_ bindings: Bindings, skip: Int) throws {
		guard sql.hasPrefix("INSERT INTO") else { return }
		guard let table = Self.firstMatch(in: sql, pattern: #"INSERT INTO "([^"]+)""#),
			  let columnList = Self.firstMatch(in: sql, pattern: #"\(([^)]*)\)\s*VALUES"#) else {
			throw CRUDSQLGenError("StatefulStubExeDelegate could not parse INSERT statement: \(sql)")
		}
		let columns = columnList.split(separator: ",").map {
			$0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		}
		let values = Array(bindings.dropFirst(skip)).map { $0.1 }
		guard columns.count == values.count else {
			throw CRUDSQLGenError("StatefulStubExeDelegate column/value count mismatch for \(sql)")
		}
		store.insert(table: table, row: Dictionary(uniqueKeysWithValues: zip(columns, values)))
	}

	func hasNext() throws -> Bool {
		guard sql.hasPrefix("SELECT") else { return false }
		if !fetchedRows {
			fetchedRows = true
			guard let table = Self.firstMatch(in: sql, pattern: #"FROM "([^"]+)""#) else {
				throw CRUDSQLGenError("StatefulStubExeDelegate could not parse SELECT statement: \(sql)")
			}
			pendingRows = store.rows(table: table)
		}
		return rowIndex < pendingRows.count
	}

	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? {
		guard rowIndex < pendingRows.count else { return nil }
		defer { rowIndex += 1 }
		return KeyedDecodingContainer(StatefulKeyedDecodingContainer<A>(row: pendingRows[rowIndex]))
	}

	private static func firstMatch(in string: String, pattern: String) -> String? {
		guard let regex = try? NSRegularExpression(pattern: pattern),
			  let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
			  let range = Range(match.range(at: 1), in: string) else {
			return nil
		}
		return String(string[range])
	}
}

final class StatefulStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let store = StatefulRowStore()
	// A fresh delegate per access, not a persistent singleton -- matching
	// the existing StubConfig/DynamicStubConfig pattern in
	// PerfectCRUDTests.swift. PerfectCRUD fetches `sqlGenDelegate` once per
	// command (Insert/Select/etc.) and accumulates that command's bindings
	// into it; a shared, never-reset instance would leak one statement's
	// bindings into the next one built from the same Database value, which
	// is exactly what happened here before this fix (a second migration's
	// INSERT saw the first migration's leftover bindings too).
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		StatefulStubExeDelegate(store: store, sql: sql)
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

// MARK: - Minimal KeyedDecodingContainer over a CRUDExpression-valued row
//
// Only the value cases PerfectCRUD's own bindings encoder actually produces
// for the types this fixture's clients use (String, Date, Int, Bool,
// Double) are implemented -- everything else throws, which is correct for
// a fixture whose whole point is decoding back exactly what was encoded in.

private struct StatefulKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
	let row: [String: CRUDExpression]
	var codingPath: [CodingKey] = []
	var allKeys: [K] { row.keys.compactMap { K(stringValue: $0) } }

	func contains(_ key: K) -> Bool { row[key.stringValue] != nil }
	func decodeNil(forKey key: K) throws -> Bool { row[key.stringValue] == nil }

	private func value(forKey key: K) throws -> CRUDExpression {
		guard let v = row[key.stringValue] else {
			throw CRUDDecoderError("StatefulKeyedDecodingContainer: no value for \(key.stringValue)")
		}
		return v
	}

	func decode(_ type: String.Type, forKey key: K) throws -> String {
		guard case .string(let s) = try value(forKey: key) else {
			throw CRUDDecoderError("StatefulKeyedDecodingContainer: expected String for \(key.stringValue)")
		}
		return s
	}
	func decode(_ type: Int.Type, forKey key: K) throws -> Int {
		guard case .integer(let i) = try value(forKey: key) else {
			throw CRUDDecoderError("StatefulKeyedDecodingContainer: expected Int for \(key.stringValue)")
		}
		return i
	}
	func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
		guard case .bool(let b) = try value(forKey: key) else {
			throw CRUDDecoderError("StatefulKeyedDecodingContainer: expected Bool for \(key.stringValue)")
		}
		return b
	}
	func decode(_ type: Double.Type, forKey key: K) throws -> Double {
		guard case .decimal(let d) = try value(forKey: key) else {
			throw CRUDDecoderError("StatefulKeyedDecodingContainer: expected Double for \(key.stringValue)")
		}
		return d
	}

	// Not needed by this fixture's clients -- explicit, informative failure
	// rather than a crash if something unexpected is ever decoded.
	func decode(_ type: Float.Type, forKey key: K) throws -> Float { throw CRUDDecoderError("Unsupported: Float") }
	func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { throw CRUDDecoderError("Unsupported: Int8") }
	func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { throw CRUDDecoderError("Unsupported: Int16") }
	func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { throw CRUDDecoderError("Unsupported: Int32") }
	func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { throw CRUDDecoderError("Unsupported: Int64") }
	func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { throw CRUDDecoderError("Unsupported: UInt") }
	func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { throw CRUDDecoderError("Unsupported: UInt8") }
	func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { throw CRUDDecoderError("Unsupported: UInt16") }
	func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { throw CRUDDecoderError("Unsupported: UInt32") }
	func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { throw CRUDDecoderError("Unsupported: UInt64") }
	// `KeyedDecodingContainerProtocol` has no dedicated `Date` (or `URL`,
	// `Data`, ...) requirement -- those types decode via their own
	// `init(from:)`, which for `Date` means `T.self == Date.self` arrives
	// here, not at a same-named `decode(_:Date.Type,forKey:)` overload (an
	// earlier version of this fixture had exactly that dead-code overload:
	// nothing ever calls it, since callers go through
	// `KeyedDecodingContainer<K>`'s own forwarding, which only knows the
	// protocol's actual requirements). Special-cased here instead of
	// building out a full nested-single-value-decoder path, since Date is
	// the only non-primitive type this fixture's clients need.
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
		if type == Date.self {
			guard case .date(let d) = try value(forKey: key) else {
				throw CRUDDecoderError("StatefulKeyedDecodingContainer: expected Date for \(key.stringValue)")
			}
			return d as! T
		}
		throw CRUDDecoderError("StatefulKeyedDecodingContainer: unsupported generic Decodable type \(T.self) for \(key.stringValue)")
	}
	func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
		throw CRUDDecoderError("StatefulKeyedDecodingContainer: nested containers unsupported")
	}
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("StatefulKeyedDecodingContainer: unkeyed containers unsupported")
	}
	func superDecoder() throws -> Decoder {
		throw CRUDDecoderError("StatefulKeyedDecodingContainer: superDecoder unsupported")
	}
	func superDecoder(forKey key: K) throws -> Decoder {
		throw CRUDDecoderError("StatefulKeyedDecodingContainer: superDecoder unsupported")
	}
}
