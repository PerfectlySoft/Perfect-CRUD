//
//  SQLiteSwORM.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-28.
//

import Foundation
import PerfectSQLite
import PerfectCSQLite3

struct SQLiteSwORMError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
		SwORMLogging.log(.error, m)
	}
}

// maps column name to position which must be computer once before row reading action
typealias SQLiteSwORMColumnMap = [String:Int]

class SQLiteSwORMRowReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] = []
	var allKeys: [Key] = []
	let database: SQLite
	let statement: SQLiteStmt
	let columns: SQLiteSwORMColumnMap
	// the SQLiteStmt has been successfully step()ed to the next row
	init(_ db: SQLite, stat: SQLiteStmt, columns cols: SQLiteSwORMColumnMap) {
		database = db
		statement = stat
		columns = cols
	}
	func columnPosition(_ key: Key) -> Int {
		return columns[key.stringValue] ?? -1
	}
	func contains(_ key: Key) -> Bool {
		return nil != columns[key.stringValue]
	}
	func decodeNil(forKey key: Key) throws -> Bool {
		return statement.isNull(position: columnPosition(key))
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		return statement.columnInt(position: columnPosition(key)) == 1
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		return statement.columnInt(position: columnPosition(key))
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		return statement.columnInt32(position: columnPosition(key))
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		return statement.columnInt64(position: columnPosition(key))
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		return type.init(statement.columnInt(position: columnPosition(key)))
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		return type.init(statement.columnDouble(position: columnPosition(key)))
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		return statement.columnDouble(position: columnPosition(key))
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		return statement.columnText(position: columnPosition(key))
	}
	func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
		let position = columnPosition(key)
		switch type {
		case is [Int8].Type:
			let ret: [Int8] = statement.columnIntBlob(position: position)
			return ret as! T
		case is [UInt8].Type:
			let ret: [UInt8] = statement.columnIntBlob(position: position)
			return ret as! T
		case is Data.Type:
			let bytes: [UInt8] = statement.columnIntBlob(position: position)
			return Data(bytes: bytes) as! T
		default:
			throw SwORMDecoderError("Unsupported type: \(type) for key: \(key.stringValue)")
		}
	}
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		fatalError("Unimplimented")
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		fatalError("Unimplimented")
	}
	func superDecoder() throws -> Decoder {
		fatalError("Unimplimented")
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		fatalError("Unimplimented")
	}
}

class SQLiteGenDelegate: SQLGenDelegate {
	var parentTableStack: [TableStructure] = []
	var bindings: Bindings = []
	
	func getCreateIndexSQL(forTable name: String, on column: String) throws -> [String] {
		let stat =
		"""
		CREATE INDEX IF NOT EXISTS \(try quote(identifier: "index_\(name)_\(column)"))
		ON \(try quote(identifier: name)) (\(try quote(identifier: column)))
		"""
		return [stat]
	}
	
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] {
		parentTableStack.append(forTable)
		defer {
			parentTableStack.removeLast()
		}
		let sub: [String]
		if !policy.contains(.shallow) {
			sub = try forTable.subTables.flatMap { try getCreateTableSQL(forTable: $0, policy: policy) }
		} else {
			sub = []
		}
		let stat =
		"""
		CREATE TABLE IF NOT EXISTS \(try quote(identifier: forTable.tableName)) (
			\(try forTable.columns.map { try mapColumn($0) }.joined(separator: ",\n\t"))
		)
		"""
		return [stat] + sub
	}
	
	func mapColumn(_ column: TableStructure.Column) throws -> String {
		let name = column.name
		let type = column.type
		let typeName: String
		switch type {
		case is Int.Type:
			typeName = "INT"
		case is Int8.Type:
			typeName = "INT"
		case is Int16.Type:
			typeName = "INT"
		case is Int32.Type:
			typeName = "INT"
		case is Int64.Type:
			typeName = "INT"
		case is UInt.Type:
			typeName = "INT"
		case is UInt8.Type:
			typeName = "INT"
		case is UInt16.Type:
			typeName = "INT"
		case is UInt32.Type:
			typeName = "INT"
		case is UInt64.Type:
			typeName = "INT"
		case is Double.Type:
			typeName = "REAL"
		case is Float.Type:
			typeName = "REAL"
		case is Bool.Type:
			typeName = "INT"
		case is String.Type:
			typeName = "TEXT"
		case is [UInt8].Type:
			typeName = "BLOB"
		case is [Int8].Type:
			typeName = "BLOB"
		case is Data.Type:
			typeName = "BLOB"
		default:
			throw SQLiteSwORMError("Unsupported SQLite column type \(type)")
		}
		let addendum: String
		if column.properties.contains(.primaryKey) {
			addendum = " PRIMARY KEY"
		} else {
			addendum = ""
		}
		return "\(name) \(typeName)\(addendum)"
	}
	
	func getBinding(for expr: Expression) throws -> String {
		bindings.append(("?", expr))
		return "?"
	}
	func quote(identifier: String) throws -> String {
		return "\"\(identifier)\""
	}
}

// maps column name to position which must be computer once before row reading action
typealias SQLiteColumnMap = [String:Int]

class SQLiteExeDelegate: SQLExeDelegate {
	let database: SQLite?
	let statement: SQLiteStmt
	let columnMap: SQLiteColumnMap
	init(_ db: SQLite, stat: SQLiteStmt) {
		database = db
		statement = stat
		var m = SQLiteColumnMap()
		let count = statement.columnCount()
		for i in 0..<count {
			let name = statement.columnName(position: i)
			m[name] = i
		}
		columnMap = m
	}
	func bind(_ binds: Bindings, skip: Int) throws {
		_ = try statement.reset()
		for i in skip..<binds.count {
			let (_, expr) = binds[i]
			try bindOne(statement, position: i+1, expr: expr)
		}
	}
	func hasNext() throws -> Bool {
		let step = statement.step()
		guard step == SQLITE_ROW || step == SQLITE_DONE else {
			throw SQLiteSwORMError(database!.errMsg())
		}
		return step == SQLITE_ROW
	}
	func next<A>() -> KeyedDecodingContainer<A>? where A : CodingKey {
		guard let db = database else {
			return nil
		}
		return KeyedDecodingContainer(SQLiteSwORMRowReader<A>(db, stat: statement, columns: columnMap))
	}
	private func bindOne(_ stat: SQLiteStmt, position: Int, expr: SwORMExpression) throws {
		switch expr {
		case .lazy(let e):
			try bindOne(stat, position: position, expr: e())
		case .integer(let i):
			try stat.bind(position: position, i)
		case .decimal(let d):
			try stat.bind(position: position, d)
		case .string(let s):
			try stat.bind(position: position, s)
		case .blob(let b):
			try stat.bind(position: position, b)
		case .bool(let b):
			try stat.bind(position: position, b ? 1 : 0)
		case .null:
			try stat.bindNull(position: position)
		default:
			throw SQLiteSwORMError("Asked to bind unsupported expression type: \(expr)")
		}
	}
}

struct SQLiteDatabaseConfiguration: DatabaseConfigurationProtocol {
	var sqlGenDelegate: SQLGenDelegate {
		return SQLiteGenDelegate()
	}
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		let prep = try sqlite.prepare(statement: sql)
		return SQLiteExeDelegate(sqlite, stat: prep)
	}
	let name: String
	let sqlite: SQLite
	init(_ n: String) throws {
		name = n
		sqlite = try SQLite(n)
	}
}















