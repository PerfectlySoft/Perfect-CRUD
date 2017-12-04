import XCTest
@testable import PerfectSwORM
import PerfectSQLite
import PerfectCSQLite3

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
			let db = try SQLite(testDBName)
			try db.execute(statement: "DROP TABLE IF EXISTS \(TestTable1.self)")
			try db.execute(statement: "DROP TABLE IF EXISTS \(TestTable2.self)")
			try db.execute(statement: "CREATE TABLE \(TestTable1.self) (id INTEGER PRIMARY KEY, name TEXT, int, doub, blob)")
			try db.execute(statement: "CREATE TABLE \(TestTable2.self) (id INTEGER PRIMARY KEY, parentId INTEGER, name TEXT, int, doub, blob)")
			try db.doWithTransaction {
				try db.execute(statement: "INSERT INTO \(TestTable1.self) (id,name,int,doub,blob) VALUES (?,?,?,?,?)", count: testDBRowCount) {
					(stmt: SQLiteStmt, num: Int) throws -> () in
					
					try stmt.bind(position: 1, num)
					try stmt.bind(position: 2, "This is name bind \(num)")
					try stmt.bind(position: 3, num)
					try stmt.bind(position: 4, Double(num))
					let num = Int8(num)
					try stmt.bind(position: 5, [Int8](arrayLiteral: num+1, num+2, num+3, num+4, num+5))
				}
			}
			try db.doWithTransaction {
				var idCount = 1
				for relCount in 1...testDBRowCount {
					try db.execute(statement: "INSERT INTO \(TestTable2.self) (id,parentId,name,int,doub,blob) VALUES (?,?,?,?,?,?)", count: testDBRowCount) {
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
				.select().map { $0 }
			XCTAssert(j2.count != 0)
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
	
	func testInsert() {
		getTestDB()
		do {
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			let newOne = TestTable1(id: 2000, name: "New One", integer: 40, double: nil, blob: nil, subTables: nil)
			try db.table(TestTable1.self).insert(newOne)
			let j2 = try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.select().map { $0 }
			XCTAssert(j2.count == 1)
			XCTAssert(j2[0].id == 2000)
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testUpdate() {
		getTestDB()
		do {
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			let newOne = TestTable1(id: 2000, name: "New One", integer: 40, double: nil, blob: nil, subTables: nil)
			try db.table(TestTable1.self).insert(newOne)
			let newOne2 = TestTable1(id: 2000, name: "New One Updated", integer: 40, double: nil, blob: nil, subTables: nil)
			
			try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.update(newOne2, setKeys: \TestTable1.name)
			
			let j2 = try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.select().map { $0 }
			XCTAssert(j2.count == 1)
			XCTAssert(j2[0].id == 2000)
			XCTAssert(j2[0].name == "New One Updated")
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testDelete() {
		getTestDB()
		do {
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			let newOne = TestTable1(id: 2000, name: "New One", integer: 40, double: nil, blob: nil, subTables: nil)
			try db.table(TestTable1.self).insert(newOne)
			let j1 = try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.select().map { $0 }
			XCTAssert(j1.count == 1)
			try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.delete()
			let j2 = try db.table(TestTable1.self)
				.where(\TestTable1.id == .integer(newOne.id))
				.select().map { $0 }
			XCTAssert(j2.count == 0)
		} catch {
			XCTAssert(false, "\(error)")
		}
	}
	
	func testCreate() {
		do {
			do {
				let db = try SQLite(testDBName)
				try db.execute(statement: "DROP TABLE IF EXISTS \(TestTable1.self)")
				try db.execute(statement: "DROP TABLE IF EXISTS \(TestTable2.self)")
			}
			
			let db = Database(configuration: try SQLiteDatabaseConfiguration(testDBName))
			try db.create(TestTable1.self)
			
			do {
				let t2 = db.table(TestTable2.self)
				try t2.index(\TestTable2.parentId)
			}
			
			let t1 = db.table(TestTable1.self)
			let newOne = TestTable1(id: 2000, name: "New One", integer: 40, double: nil, blob: nil, subTables: nil)
			try t1.insert(newOne)
			let j2 = try t1
				.where(\TestTable1.id == .integer(newOne.id))
				.select().map { $0 }
			XCTAssert(j2.count == 1)
			XCTAssert(j2[0].id == 2000)
		} catch {
			XCTAssert(false, "\(error)")
		}
	}

    static var allTests = [
		("testKeyPaths", testKeyPaths),
		("testSelectAll", testSelectAll),
		("testSelectJoin", testSelectJoin),
		("testInsert", testInsert),
		("testUpdate", testUpdate),
		("testDelete", testDelete),
    ]
}




