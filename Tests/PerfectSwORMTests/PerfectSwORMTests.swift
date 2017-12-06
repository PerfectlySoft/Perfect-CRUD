import XCTest
@testable import PerfectSwORM

struct TestTable1: Codable, TableNameProvider {
	enum CodingKeys: String, CodingKey {
		case id, name, integer = "int", double = "doub", blob, subTables
	}
	static let tableName = "test_table_1"
	let id: Int
	let name: String?
	let integer: Int?
	let double: Double?
	let blob: [UInt8]?
	let subTables: [TestTable2]?
}

struct TestTable2: Codable {
	let id: UUID
	let date: Date
	let parentId: Int
	let name: String?
	let int: Int?
	let doub: Double?
	let blob: [UInt8]?
}

// NOTE - full tests are in Perfect-SQLite

class PerfectSwORMTests: XCTestCase {
	override func tearDown() {
		SwORMLogging.flush()
		super.tearDown()
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
	
    static var allTests = [
		("testKeyPaths", testKeyPaths),
    ]
}




