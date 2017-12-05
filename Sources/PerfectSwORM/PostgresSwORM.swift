//
//  PostgresSwORM.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-04.
//

import Foundation
import PerfectPostgreSQL

struct PostgresSwORMError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
		SwORMLogging.log(.error, m)
	}
}

extension PGResult {
	public func getFieldBlobUInt8(tupleIndex: Int, fieldIndex: Int) -> [UInt8]? {
		guard let s = getFieldString(tupleIndex: tupleIndex, fieldIndex: fieldIndex) else {
			return nil
		}
		let sc = s.utf8
		guard sc.count % 2 == 0, sc.count >= 2, s[s.startIndex] == "\\", s[s.index(after: s.startIndex)] == "x" else {
			return nil
		}
		var ret = [UInt8]()
		var index = sc.index(sc.startIndex, offsetBy: 2)
		while index != sc.endIndex {
			let c1 = UInt8(sc[index])
			index = sc.index(after: index)
			let c2 = UInt8(sc[index])
			guard let byte = byteFromHexDigits(one: c1, two: c2) else {
				return nil
			}
			ret.append(byte)
			index = sc.index(after: index)
		}
		return ret
	}
	
	private func byteFromHexDigits(one c1v: UInt8, two c2v: UInt8) -> UInt8? {
		let capA: UInt8 = 65
		let capF: UInt8 = 70
		let lowA: UInt8 = 97
		let lowF: UInt8 = 102
		let zero: UInt8 = 48
		let nine: UInt8 = 57
		var newChar = UInt8(0)
		if c1v >= capA && c1v <= capF {
			newChar = c1v - capA + 10
		} else if c1v >= lowA && c1v <= lowF {
			newChar = c1v - lowA + 10
		} else if c1v >= zero && c1v <= nine {
			newChar = c1v - zero
		} else {
			return nil
		}
		newChar *= 16
		if c2v >= capA && c2v <= capF {
			newChar += c2v - capA + 10
		} else if c2v >= lowA && c2v <= lowF {
			newChar += c2v - lowA + 10
		} else if c2v >= zero && c2v <= nine {
			newChar += c2v - zero
		} else {
			return nil
		}
		return newChar
	}
}

class PostgresSwORMRowReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] = []
	var allKeys: [K] = []
	let results: PGResult
	let tupleIndex: Int
	let fieldNames: [String:Int]
	init(results r: PGResult, tupleIndex ti: Int, fieldNames fn: [String:Int]) {
		results = r
		tupleIndex = ti
		fieldNames = fn
	}
	func contains(_ key: K) -> Bool {
		return fieldNames[key.stringValue] != nil
	}
	func ensureIndex(forKey key: K) throws -> Int {
		guard let index = fieldNames[key.stringValue] else {
			throw PostgresSwORMError("No index for column \(key.stringValue)")
		}
		return index
	}
	func decodeNil(forKey key: K) throws -> Bool {
		return results.fieldIsNull(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key))
	}
	
	func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
		return results.getFieldBool(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? false
	}
	
	func decode(_ type: Int.Type, forKey key: K) throws -> Int {
		return results.getFieldInt(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
		return results.getFieldInt8(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
		return results.getFieldInt16(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
		return results.getFieldInt32(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
		return results.getFieldInt64(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
		return UInt(results.getFieldInt(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0)
	}
	
	func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
		return UInt8(results.getFieldInt8(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0)
	}
	
	func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
		return UInt16(results.getFieldInt16(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0)
	}
	
	func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
		return UInt32(results.getFieldInt32(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0)
	}
	
	func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
		return UInt64(results.getFieldInt64(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0)
	}
	
	func decode(_ type: Float.Type, forKey key: K) throws -> Float {
		return results.getFieldFloat(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: Double.Type, forKey key: K) throws -> Double {
		return results.getFieldDouble(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? 0
	}
	
	func decode(_ type: String.Type, forKey key: K) throws -> String {
		return results.getFieldString(tupleIndex: tupleIndex, fieldIndex: try ensureIndex(forKey: key)) ?? ""
	}
	
	func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
		let index = try ensureIndex(forKey: key)
		switch type {
		case is [Int8].Type:
			let ret: [Int8] = results.getFieldBlob(tupleIndex: tupleIndex, fieldIndex: index) ?? []
			return ret as! T
		case is [UInt8].Type:
			let ret: [UInt8] = results.getFieldBlobUInt8(tupleIndex: tupleIndex, fieldIndex: index) ?? []
			return ret as! T
		case is Data.Type:
			let bytes: [UInt8] = results.getFieldBlobUInt8(tupleIndex: tupleIndex, fieldIndex: index) ?? []
			return Data(bytes: bytes) as! T
		default:
			throw SwORMDecoderError("Unsupported type: \(type) for key: \(key.stringValue)")
		}
	}
	
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		fatalError("Not implimented")
	}
	
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
		fatalError("Not implimented")
	}
	
	func superDecoder() throws -> Decoder {
		fatalError("Not implimented")
	}
	
	func superDecoder(forKey key: K) throws -> Decoder {
		fatalError("Not implimented")
	}
}

class PostgresGenDelegate: SQLGenDelegate {
	var parentTableStack: [TableStructure] = []
	var bindings: Bindings = []
	func getBinding(for expr: Expression) throws -> String {
		let id = "$\(bindings.count+1)"
		bindings.append((id, expr))
		return id
	}
	func quote(identifier: String) throws -> String {
		return "\"\(identifier)\""
	}
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] {
		parentTableStack.append(forTable)
		defer {
			parentTableStack.removeLast()
		}
		var sub: [String]
		if !policy.contains(.shallow) {
			sub = try forTable.subTables.flatMap { try getCreateTableSQL(forTable: $0, policy: policy) }
		} else {
			sub = []
		}
		if policy.contains(.dropTable) {
			sub += ["DROP TABLE IF EXISTS \(try quote(identifier: forTable.tableName))"]
		}
		sub += [
			"""
			CREATE TABLE IF NOT EXISTS \(try quote(identifier: forTable.tableName)) (
			\(try forTable.columns.map { try mapColumn($0) }.joined(separator: ",\n\t"))
			)
			"""]
		return sub
	}
	func mapColumn(_ column: TableStructure.Column) throws -> String {
		let name = column.name
		let type = column.type
		let typeName: String
		switch type {
		case is Int.Type:
			typeName = "bigint"
		case is Int8.Type:
			typeName = "smallint"
		case is Int16.Type:
			typeName = "smallint"
		case is Int32.Type:
			typeName = "integer"
		case is Int64.Type:
			typeName = "bigint"
		case is UInt.Type:
			typeName = "bigint"
		case is UInt8.Type:
			typeName = "smallint"
		case is UInt16.Type:
			typeName = "integer"
		case is UInt32.Type:
			typeName = "bigint"
		case is UInt64.Type:
			typeName = "bigint"
		case is Double.Type:
			typeName = "double precision"
		case is Float.Type:
			typeName = "real"
		case is Bool.Type:
			typeName = "boolean"
		case is String.Type:
			typeName = "text"
		case is [UInt8].Type:
			typeName = "bytea"
		case is [Int8].Type:
			typeName = "bytea"
		case is Data.Type:
			typeName = "bytea"
		default:
			throw PostgresSwORMError("Unsupported SQLite column type \(type)")
		}
		let addendum: String
		if column.properties.contains(.primaryKey) {
			addendum = " PRIMARY KEY"
		} else {
			addendum = ""
		}
		return "\(name) \(typeName)\(addendum)"
	}
	func getCreateIndexSQL(forTable name: String, on column: String) throws -> [String] {
		let stat =
		"""
		CREATE INDEX IF NOT EXISTS \(try quote(identifier: "index_\(name)_\(column)"))
		ON \(try quote(identifier: name)) (\(try quote(identifier: column)))
		"""
		return [stat]
	}
}

class PostgresExeDelegate: SQLExeDelegate {
	var nextBindings: Bindings = []
	let connection: PGConnection
	let sql: String
	var results: PGResult?
	var tupleIndex = 0
	var numTuples = 0
	var fieldNames: [String:Int] = [:]
	init(connection c: PGConnection, sql s: String) {
		connection = c
		sql = s
	}
	func bind(_ bindings: Bindings, skip: Int) throws {
		results = nil
		if skip == 0 {
			nextBindings = bindings
		} else {
			nextBindings = nextBindings[0..<skip] + bindings
		}
	}
	
	func hasNext() throws -> Bool {
		if nil == results {
			let r = try connection.exec(statement: sql, params: nextBindings.map { try bindOne(expr: $0.1) })
			results = r
			let status = r.status()
			if status == .commandOK || status == .singleTuple || status == .tuplesOK {
				numTuples = r.numTuples()
				for i in 0..<numTuples {
					guard let fieldName = r.fieldName(index: i) else {
						continue
					}
					fieldNames[fieldName] = i
				}
			}
		}
		return tupleIndex < numTuples
	}
	
	func next<A>() throws -> KeyedDecodingContainer<A>? where A : CodingKey {
		guard let results = self.results else {
			return nil
		}
		let ret = KeyedDecodingContainer(PostgresSwORMRowReader<A>(results: results, tupleIndex: tupleIndex, fieldNames: fieldNames))
		tupleIndex += 1
		return ret
	}
	
	private func bindOne(expr: SwORMExpression) throws -> Any? {
		switch expr {
		case .lazy(let e):
			return try bindOne(expr: e())
		case .integer(let i):
			return i
		case .decimal(let d):
			return d
		case .string(let s):
			return s
		case .blob(let b):
			return b
		case .bool(let b):
			return b
		case .null:
			return nil as String?
		default:
			throw PostgresSwORMError("Asked to bind unsupported expression type: \(expr)")
		}
	}
}

struct PostgresDatabaseConfiguration: DatabaseConfigurationProtocol {
	let connection: PGConnection
	init(_ connectionInfo: String) throws {
		let con = PGConnection()
		guard case .ok = con.connectdb(connectionInfo) else {
			throw PostgresSwORMError("Could not connect. \(con.errorMessage())")
		}
		connection = con
	}
	var sqlGenDelegate: SQLGenDelegate {
		return PostgresGenDelegate()
	}
	func sqlExeDelegate(forSQL: String) throws -> SQLExeDelegate {
		return PostgresExeDelegate(connection: connection, sql: forSQL)
	}
}

