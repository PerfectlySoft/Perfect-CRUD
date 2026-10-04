import Testing
import Foundation
@testable import PerfectCRUD

// Class-hierarchy models whose subclass writes its own `init(from:)` /
// `encode(to:)` and calls `super` with the same decoder/encoder (the usual
// way to keep every property in one flat table). The subclass and the
// superclass each ask the decoder for their own keyed container, so key-path
// resolution must not restart its numbering per container: when it did,
// a subclass key path such as `\Dog.breed` resolved to a superclass column
// (stale PerfectlySoft/Perfect-CRUD#57). Fixed on `main` by keeping the
// counter on `CRUDKeyPathsDecoder`; these tests pin that down.

private class Animal: Codable {
	var id: Int
	var name: String

	init(id: Int, name: String) {
		self.id = id
		self.name = name
	}
}

private final class Dog: Animal {
	var breed: String
	var weight: Double

	private enum CodingKeys: String, CodingKey {
		case breed, weight
	}

	init(id: Int, name: String, breed: String, weight: Double) {
		self.breed = breed
		self.weight = weight
		super.init(id: id, name: name)
	}

	required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		breed = try container.decode(String.self, forKey: .breed)
		weight = try container.decode(Double.self, forKey: .weight)
		try super.init(from: decoder)
	}

	override func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(breed, forKey: .breed)
		try container.encode(weight, forKey: .weight)
		try super.encode(to: encoder)
	}
}

private final class SubclassStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		throw CRUDSQLExeError("not executed in these tests")
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

@Suite("Subclass models with explicit Codable", .serialized)
struct SubclassModelTests {

	@Test func tableStructureHasSubclassAndSuperclassColumns() throws {
		CRUDClearTableStructureCache()
		let structure = try Dog.CRUDTableStructure()
		#expect(structure.tableName == "Dog")
		#expect(Set(structure.columns.map(\.name)) == ["id", "name", "breed", "weight"])
		#expect(structure.primaryKeyName == "id")
	}

	@Test(arguments: ["id", "name", "breed", "weight"])
	func keyPathsResolveToTheirOwnColumns(column: String) throws {
		let expr: CRUDBooleanExpression = switch column {
		case "id": \Dog.id == 1
		case "name": \Dog.name == "Rex"
		case "breed": \Dog.breed == "Collie"
		default: \Dog.weight > 20.0
		}
		CRUDClearTableStructureCache()
		let db = Database(configuration: try SubclassStubConfig())
		let select = try db.table(Dog.self).where(expr).select()
		let sql = try #require(select.sqlGenState.statements.first?.sql)
		let whereClause = try #require(sql.components(separatedBy: "WHERE").last)
		#expect(whereClause.contains("\"\(column)\""), "WHERE clause was: \(whereClause)")
		for other in ["id", "name", "breed", "weight"] where other != column {
			#expect(!whereClause.contains("\"\(other)\""), "WHERE clause was: \(whereClause)")
		}
	}

	@Test func orderByUsesSubclassKeyPath() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try SubclassStubConfig())
		let select = try db.table(Dog.self).order(by: \Dog.breed).select()
		let sql = try #require(select.sqlGenState.statements.first?.sql)
		#expect(sql.contains("ORDER BY"))
		#expect(sql.hasSuffix("\"breed\"") || sql.contains("\"breed\" "), "SQL was: \(sql)")
	}

	@Test func insertAndSelectRoundTrip() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		let db = Database(configuration: config)
		try db.create(Dog.self)
		let table = db.table(Dog.self)
		try table.insert(Dog(id: 1, name: "Rex", breed: "Collie", weight: 23.5))
		try table.insert(Dog(id: 2, name: "Fido", breed: "Pug", weight: 8.0))

		let stored = config.store.rows(table: "Dog")
		#expect(stored.count == 2)
		#expect(Set(stored.first?.keys.map { $0 } ?? []) == ["id", "name", "breed", "weight"])

		let dogs = try table.select().map { $0 }
		#expect(dogs.map(\.id) == [1, 2])
		#expect(dogs.map(\.name) == ["Rex", "Fido"])
		#expect(dogs.map(\.breed) == ["Collie", "Pug"])
		#expect(dogs.map(\.weight) == [23.5, 8.0])
	}
}
