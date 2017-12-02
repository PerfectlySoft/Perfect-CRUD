import XCTest
@testable import PerfectSwORM
import PerfectSQLite
import PerfectCSQLite3


struct TestTable: Codable {
	enum CodingKeys: String, CodingKey {
		case id, name, integer = "int", double = "doub", blob
	}
	let id: Int
	let name: String?
	let integer: Int?
	let double: Double?
	let blob: [UInt8]?
}

struct TestTable1: Codable {
	enum CodingKeys: String, CodingKey {
		case id, name, integer = "int", double = "doub", blob, subTables
	}
	let id: Int
	let name: String?
	let integer: Int?
	let double: Double?
	let blob: [UInt8]?
	let subTables: [TestTable2]?
}

struct TestTable2: Codable {
	let id: Int
	let parentId: Int
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}

struct TestTable3: Codable {
	let id: Int
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}

let testDBRowCount = 5

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
				for num in 1...testDBRowCount {
					ts.append(TestTable(id: num, name: "This is name bind \(num)",
										integer: num, double: Double(num),
										blob: [num+1, num+2, num+3, num+4, num+5].map {UInt8($0)}))
				}
				try table.insert(ts)
			}
			
			// new tables
			try db.sqlite.execute(statement: "DROP TABLE IF EXISTS \(TestTable1.self)")
			try db.sqlite.execute(statement: "DROP TABLE IF EXISTS \(TestTable2.self)")
			try db.sqlite.execute(statement: "CREATE TABLE \(TestTable1.self) (id INTEGER PRIMARY KEY, name TEXT, int, doub, blob)")
			try db.sqlite.execute(statement: "CREATE TABLE \(TestTable2.self) (id INTEGER PRIMARY KEY, parentId INTEGER, name TEXT, int, doub, blob)")
			try db.sqlite.doWithTransaction {
				try db.sqlite.execute(statement: "INSERT INTO \(TestTable1.self) (id,name,int,doub,blob) VALUES (?,?,?,?,?)", count: testDBRowCount) {
					(stmt: SQLiteStmt, num: Int) throws -> () in
					
					try stmt.bind(position: 1, num)
					try stmt.bind(position: 2, "This is name bind \(num)")
					try stmt.bind(position: 3, num)
					try stmt.bind(position: 4, Double(num))
					let num = Int8(num)
					try stmt.bind(position: 5, [Int8](arrayLiteral: num+1, num+2, num+3, num+4, num+5))
				}
			}
			try db.sqlite.doWithTransaction {
				var idCount = 1
				for relCount in 1...testDBRowCount {
					try db.sqlite.execute(statement: "INSERT INTO \(TestTable2.self) (id,parentId,name,int,doub,blob) VALUES (?,?,?,?,?,?)", count: testDBRowCount) {
						(stmt: SQLiteStmt, num: Int) throws -> () in
						try stmt.bind(position: 1, idCount)
						try stmt.bind(position: 2, relCount)
						if idCount % 2 == 0 {
							try stmt.bind(position: 3, "This is name bind \(num)")
						} else {
							try stmt.bind(position: 3, "Me")
						}
						try stmt.bind(position: 4, num)
						try stmt.bind(position: 5, Double(num))
						let num = Int8(num)
						try stmt.bind(position: 6, [Int8](arrayLiteral: num+1, num+2, num+3, num+4, num+5))
						idCount += 1
					}
				}
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
			let tt = TestTable(id: 10, name: "the name", integer: 42, double: 3.2, blob: [1, 2, 3, 4, 5])
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
				let tt = TestTable(id: 10, name: "the name", integer: 42, double: 3.2, blob: [1, 2, 3, 4, 5])
				try table.insert([tt])
			}
			let recordTen = table.where(.column("id") == 10)
			try db.transaction { _ in
				let ttChanged = TestTable(id: 10, name: "the name was changed", integer: 42, double: 3.2, blob: [1, 2, 3, 4, 5])
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
	
	func testKeyPaths() {
		let fs: [(String, PartialKeyPath<TestTable1>)] = [("id", \TestTable1.id),
														  ("name", \TestTable1.name),
														  ("int", \TestTable1.integer),
														  ("doub", \TestTable1.double),
														  ("blob", \TestTable1.blob)]
		do {
			let decoder = SwORMKeyPathsDecoder()
			let inst = try TestTable1(from: decoder)
			for path in fs {
				let name = try decoder.getKeyPathName(inst, keyPath: path.1)
				XCTAssertEqual(name, path.0)
			}
			print(name)
		} catch {
			
		}
	}
	
	func testSelectAll() {
		getTestDB()
		do {
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			let j2 = try db.table(TestTable1.self)
				.select()
			for row in j2 {
				print("\(row)")
			}
		} catch {
			print("\(error)")
		}
	}
	
	func testSelectJoin() {
		getTestDB()
		do {
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			
			let j2 = try db.table(TestTable1.self)
					.order(by: \TestTable1.name)
				.join(\.subTables, on: \.id, equals: \.parentId)
					.order(by: \TestTable2.id)
				.where(\TestTable2.name == .string("Me"))
				.select()
			
			j2.forEach { row in
				row.subTables?.forEach {
					sub in
					XCTAssert(sub.id % 2 == 1)
				}
			}
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
