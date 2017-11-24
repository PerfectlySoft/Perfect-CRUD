import XCTest
@testable import PerfectSwORM
import PerfectSQLite
import SQLite3

struct SQLiteSwORMError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
	}
}

class SQLiteSwORMGenDelegate: SwORMGenDelegate {
	var bindings: SwORMBindings = []
	func getBinding(for expr: SwORMExpression) throws -> String {
		bindings.append(("?", expr))
		return "?"
	}
	func quote(identifier: String) throws -> String {
		return "\"\(identifier)\""
	}
}

// maps column name to position which must be computer once before row reading action
typealias SQLiteSwORMColumnMap = [String:Int]

class SQLiteSwORMExeDelegate: SwORMExeDelegate {
	let database: SQLite?
	let statement: SQLiteStmt
	let columnMap: SQLiteSwORMColumnMap
	init(_ db: SQLite, stat: SQLiteStmt) {
		database = db
		statement = stat
		var m = SQLiteSwORMColumnMap()
		let count = statement.columnCount()
		for i in 0..<count {
			let name = statement.columnName(position: i)
			m[name] = i
		}
		columnMap = m
	}
	func hasNext() throws -> Bool {
		let step = statement.step()
		guard step == SQLITE_ROW || step == SQLITE_DONE else {
			throw SQLiteError.Error(code: Int(step), msg: "!FIX! to provide a real msg.")
		}
		return step == SQLITE_ROW
	}
	func next<A>() -> KeyedDecodingContainer<A>? where A : CodingKey {
		guard let db = database else {
			return nil
		}
		return KeyedDecodingContainer(SQLiteSwORMRowReader<A>(db, stat: statement, columns: columnMap))
	}
}

class SQLiteSwORMRowReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] {
		return []
	}
	var allKeys: [Key] {
		return []
	}
	
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
		switch type {
		case is [Int8].Type:
			let ret: [Int8] = statement.columnIntBlob(position: columnPosition(key))
			return ret as! T
		case is [UInt8].Type:
			let ret: [UInt8] = statement.columnIntBlob(position: columnPosition(key))
			return ret as! T
		case is Data.Type:
			let ret: [UInt8] = statement.columnIntBlob(position: columnPosition(key))
			return Data(bytes: ret) as! T
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

struct SQLiteDatabase: SwORMDatabase {
	var genDelegate: SwORMGenDelegate {
		return SQLiteSwORMGenDelegate()
	}
	func exeDelegate(forSQL sql: String, withBindings binds: SwORMBindings) throws -> SwORMExeDelegate {
		let prep = try sqlite.prepare(statement: sql)
		for i in 0..<binds.count {
			let (_, expr) = binds[i]
			try bindOne(prep, position: i, expr: expr)
		}
		return SQLiteSwORMExeDelegate(sqlite, stat: prep)
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
		default:
			()
		}
	}
	
	let name: String
	let sqlite: SQLite
	init(_ n: String) throws {
		name = n
		sqlite = try SQLite(n)
	}
}

struct TestTable: Codable {
	let id: Int
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}

class PerfectSwORMTests: XCTestCase {
	let testDBName = "/tmp/sworm_test.db"
	override func setUp() {
		unlink(testDBName)
	}
	
	func getTestDB() {
		do {
			let db = try SQLiteDatabase(testDBName)
			try db.sqlite.execute(statement: "DROP TABLE IF EXISTS test")
			try db.sqlite.execute(statement: "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, int, doub, blob)")
			try db.sqlite.doWithTransaction {
				try db.sqlite.execute(statement: "INSERT INTO test (id,name,int,doub,blob) VALUES (?,?,?,?,?)", count: 5) {
					(stmt: SQLiteStmt, num: Int) throws -> () in
					
					try stmt.bind(position: 1, num)
					try stmt.bind(position: 2, "This is name bind \(num)")
					try stmt.bind(position: 3, num)
					try stmt.bind(position: 4, Double(num))
					let num = Int8(num)
					try stmt.bind(position: 5, [Int8](arrayLiteral: num+1, num+2, num+3, num+4, num+5))
				}
			}
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
    func testSQLGen1() {
		do {
			let db = try SQLiteDatabase(testDBName)
			let query = try db.table("test").order(by: .column(name: "id")).select(as: TestTable.self)
			let (_, sql, _) = try SwORMSQLGenerator().generate(command: query)
			XCTAssertEqual(sql, "SELECT \"id\", \"name\", \"int\", \"doub\", \"blob\" FROM \"test\" ORDER BY \"id\"")
		} catch {
			XCTAssert(false, "\(error)")
		}
    }
	
	func testQuery1() {
		getTestDB()
		do {
			let db = try SQLiteDatabase(testDBName)
			let query = try db.table("test").order(by: .column(name: "id")).select(as: TestTable.self)
			var count = 1
			for row in query {
				XCTAssertEqual(count, row.id)
				count += 1
			}
		} catch {
			XCTAssert(false, "\(error)")
		}
	}

    static var allTests = [
        ("testSQLGen1", testSQLGen1),
    ]
}
