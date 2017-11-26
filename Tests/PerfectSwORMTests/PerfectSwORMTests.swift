import XCTest
@testable import PerfectSwORM
import PerfectSQLite
import PerfectCSQLite3

struct SQLiteSwORMError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
		SwORMLogging.log(.error, m)
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
	func bind(_ binds: SwORMBindings, skip: Int) throws {
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

struct SQLiteDatabase: SwORMDatabase {
	var genDelegate: SwORMGenDelegate {
		return SQLiteSwORMGenDelegate()
	}
	func exeDelegate(forSQL sql: String) throws -> SwORMExeDelegate {
		let prep = try sqlite.prepare(statement: sql)
		return SQLiteSwORMExeDelegate(sqlite, stat: prep)
	}
	func transaction<Ret>(_ body: (SQLiteDatabase) throws -> Ret) throws -> Ret {
		try sqlite.execute(statement: "BEGIN")
		SwORMLogging.log(.query, "BEGIN")
		do {
			let ret = try body(self)
			try sqlite.execute(statement: "COMMIT")
			SwORMLogging.log(.query, "COMMIT")
			return ret
		} catch {
			try sqlite.execute(statement: "ROLLBACK")
			SwORMLogging.log(.query, "ROLLBACK")
			throw error
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
	override func tearDown() {
		SwORMLogging.flush()
	}
	
	func getTestDB() {
		do {
			let db = try SQLiteDatabase(testDBName)
			try db.sqlite.execute(statement: "DROP TABLE IF EXISTS test")
			try db.sqlite.execute(statement: "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, int, doub, blob)")
			try db.transaction {
				db in
				let table = db.table("test")
				var ts: [TestTable] = []
				for num in 1...5 {
					ts.append(TestTable(id: num, name: "This is name bind \(num)",
										int: num, doub: Double(num),
										blob: [num+1, num+2, num+3, num+4, num+5].map {UInt8($0)}))
				}
				try table.insert(ts)
			}
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testSQLGen1() {
		do {
			let db = try SQLiteDatabase(testDBName)
			let query = try db.table("test").order(by: .column("id")).select(as: TestTable.self)
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
			let query = try db.table("test").where(.column("id") < 4).order(by: .column("id")).select(as: TestTable.self)
			var count = 1
			for row in query {
				XCTAssertEqual(count, row.id)
				XCTAssertLessThan(row.id, 4)
				count += 1
			}
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testQuery2() {
		getTestDB()
		do {
			let db = try SQLiteDatabase(testDBName)
			let query = try db.table("test").select(as: TestTable.self)
			let count1 = query.map { $0 }.count
			try db.table("test").where(.column("id") == 1).delete()
			let count2 = query.map { $0 }.count
			XCTAssertEqual(count2, count1 - 1)
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testQuery3() {
		getTestDB()
		do {
			let table = try SQLiteDatabase(testDBName).table("test")
			let tt = TestTable(id: 10, name: "the name", int: 42, doub: 3.2, blob: [1, 2, 3, 4, 5])
			try table.insert([tt])
			let query = try table.where(.column("id") == 10).select(as: TestTable.self)
			guard let tt2 = query.map({ $0 }).first else {
				return XCTAssert(false, "Row not found.")
			}
			XCTAssertEqual(tt2.id, 10)
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testQuery4() {
		getTestDB()
		do {
			let db = try SQLiteDatabase(testDBName)
			let table = db.table("test")
			try db.transaction { _ in
				let tt = TestTable(id: 10, name: "the name", int: 42, doub: 3.2, blob: [1, 2, 3, 4, 5])
				try table.insert([tt])
			}
			let recordTen = table.where(.column("id") == 10)
			try db.transaction { _ in
				let ttChanged = TestTable(id: 10, name: "the name was changed", int: 42, doub: 3.2, blob: [1, 2, 3, 4, 5])
				try recordTen.update(ttChanged)
			}
			let query = try recordTen.select(as: TestTable.self)
			guard let ttNew = query.map({ $0 }).first else {
				return XCTAssert(false, "Row not found.")
			}
			XCTAssertEqual(ttNew.name, "the name was changed")
		} catch {
			XCTAssert(false, "\(error)")
		}
	}

    static var allTests = [
		("testSQLGen1", testSQLGen1),
		("testQuery1", testQuery1),
		("testQuery2", testQuery2),
    ]
}
