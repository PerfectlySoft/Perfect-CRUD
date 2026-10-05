import Testing
import Foundation
@testable import PerfectCRUD

// Codable and array columns are resolved by type, so when a model had two
// top-level columns of the same type every key path to either one resolved
// to the first (`\Pair.req` became "opt"). That broke WHERE/ORDER on the
// second column, insert/update `setKeys`/`ignoreKeys`, and joins on a second
// `[Child]?` of the same element type.

private struct Point: Codable, Equatable {
	var x: Int
	var y: Int
}

private struct Pair: Codable {
	var id: Int
	var opt: Point?
	var req: Point
	var other: Point?
}

private struct TwoRequired: Codable {
	var id: Int
	var a: Point
	var b: Point
	var c: Point
}

// Bool-only and scalar-free column types, and a class model.
private struct Flags: Codable {
	var on: Bool
}

private struct Box: Codable {
	var p: Point?
}

private struct Shapes: Codable {
	var id: Int
	var f1: Flags
	var f2: Flags
	var b1: Box
	var b2: Box
}

private final class Route: Codable {
	var id: Int
	var from: Point
	var to: Point
	init(id: Int, from: Point, to: Point) {
		self.id = id
		self.from = from
		self.to = to
	}
}

// Nothing to tell these apart by: no decoded fields, and not optional.
private struct Empty: Codable {}

private struct TwoEmpty: Codable {
	var id: Int
	var e1: Empty
	var e2: Empty
}

private struct OneEmpty: Codable {
	var id: Int
	var e: Empty
}

private struct Kid: Codable, Equatable {
	var id: Int
	var parentId: Int
	var name: String
}

private struct Parent: Codable {
	var id: Int
	var name: String
	var kids: [Kid]?
	var pets: [Kid]?
}

private struct KidHolder: Codable {
	var kids: [Kid]?
}

private struct HolderParent: Codable {
	var id: Int
	var kids: [Kid]?
	var pets: [Kid]?
	var holder: KidHolder?
}

private struct TwoPlainArrays: Codable {
	var id: Int
	var a: [Kid]
	var b: [Kid]
}

private struct Names: Codable {
	var id: Int
	var tags: [String]
	var aliases: [String]
}

// Missing arrays become empty, so setting a column to nil tells us nothing.
private struct EmptyDefault: Codable {
	var id: Int
	var kids: [Kid]?
	var pets: [Kid]?
	init(id: Int, kids: [Kid]?, pets: [Kid]?) {
		self.id = id
		self.kids = kids
		self.pets = pets
	}
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .id)
		kids = try c.decodeIfPresent([Kid].self, forKey: .kids) ?? []
		pets = try c.decodeIfPresent([Kid].self, forKey: .pets) ?? []
	}
}

// Rejects a missing `a`, so its nil probe can't be decoded.
private struct RequiresA: Codable {
	var id: Int
	var a: [Kid]?
	var b: [Kid]?
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .id)
		guard let a = try c.decodeIfPresent([Kid].self, forKey: .a) else {
			throw DecodingError.valueNotFound([Kid].self, .init(codingPath: [CodingKeys.a], debugDescription: "a"))
		}
		self.a = a
		b = try c.decodeIfPresent([Kid].self, forKey: .b)
	}
}

// Decodes `pets` into two properties, so the key appears twice.
private struct DoubleDecoded: Codable {
	var id: Int
	var kids: [Kid]?
	var pets: [Kid]?
	var petsAgain: [Kid]?
	private enum CodingKeys: String, CodingKey {
		case id, kids, pets
	}
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .id)
		kids = try c.decodeIfPresent([Kid].self, forKey: .kids)
		pets = try c.decodeIfPresent([Kid].self, forKey: .pets)
		petsAgain = try c.decodeIfPresent([Kid].self, forKey: .pets)
	}
	func encode(to encoder: Encoder) throws {}
}

private enum Status: String, Codable {
	case open, closed
}

// Elements the one-element probe can't build: a raw-value enum gets a
// counter value that isn't one of its cases.
private struct StatusLists: Codable {
	var id: Int
	var a: [Status]
	var b: [Status]
}

private struct OptionalElements: Codable {
	var id: Int
	var a: [Kid?]
	var b: [Kid?]
}

// Not an array, but decoded from an unkeyed container: the probe changes a
// value without changing how many there are.
private struct MaybeOne: Codable {
	var x: Int?
	init(from decoder: Decoder) throws {
		var c = try decoder.unkeyedContainer()
		x = c.isAtEnd ? nil : try c.decode(Int.self)
	}
	func encode(to encoder: Encoder) throws {
		var c = encoder.unkeyedContainer()
		try c.encode(x)
	}
}

private struct MaybeOnes: Codable {
	var id: Int
	var a: MaybeOne
	var b: MaybeOne
}

private struct KidMaps: Codable {
	var id: Int
	var a: [String: Kid]
	var b: [String: Kid]
}

private func columnName<T: Codable>(_ keyPath: PartialKeyPath<T>) throws -> String? {
	let decoder = CRUDKeyPathsDecoder()
	let instance = try T(from: decoder)
	return try decoder.getKeyPathName(instance, keyPath: keyPath)
}

private func expectAmbiguous(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
	let error = #expect(throws: CRUDSQLGenError.self, sourceLocation: sourceLocation) {
		try body()
	}
	#expect(error?.description.contains("can't be told apart") == true, sourceLocation: sourceLocation)
}

private let samplePair = Pair(id: 1, opt: Point(x: 1, y: 2), req: Point(x: 3, y: 4), other: nil)

@Suite("Codable columns of the same type", .serialized)
struct SameTypeColumnTests {

	@Test func optionalAndRequiredColumnsResolveByName() throws {
		#expect(try columnName(\Pair.id) == "id")
		#expect(try columnName(\Pair.opt) == "opt")
		#expect(try columnName(\Pair.req) == "req")       // was "opt"
		#expect(try columnName(\Pair.other) == "other")   // was "opt"
	}

	@Test func requiredColumnsResolveByName() throws {
		#expect(try columnName(\TwoRequired.a) == "a")
		#expect(try columnName(\TwoRequired.b) == "b")
		#expect(try columnName(\TwoRequired.c) == "c")
	}

	@Test func boolOnlyAndNestedOnlyColumnsResolveByName() throws {
		#expect(try columnName(\Shapes.f1) == "f1")
		#expect(try columnName(\Shapes.f2) == "f2")
		#expect(try columnName(\Shapes.b1) == "b1")
		#expect(try columnName(\Shapes.b2) == "b2")
	}

	@Test func classModelsResolveByName() throws {
		#expect(try columnName(\Route.from) == "from")
		#expect(try columnName(\Route.to) == "to")
	}

	@Test func arrayColumnsResolveByName() throws {
		#expect(try columnName(\Parent.kids) == "kids")
		#expect(try columnName(\Parent.pets) == "pets")
	}

	@Test func nestedArrayOfASharedTypeIsNested() throws {
		#expect(try columnName(\HolderParent.kids) == "kids")
		#expect(try columnName(\HolderParent.pets) == "pets")
		let error = #expect(throws: CRUDSQLGenError.self) {
			_ = try columnName(\HolderParent.holder?.kids)
		}
		#expect(error?.description.contains("top-level property") == true)
	}

	@Test func nonOptionalAndScalarArraysResolveByName() throws {
		#expect(try columnName(\TwoPlainArrays.a) == "a")
		#expect(try columnName(\TwoPlainArrays.b) == "b")
		#expect(try columnName(\Names.tags) == "tags")
		#expect(try columnName(\Names.aliases) == "aliases")
	}

	@Test func arraysDefaultedFromNilResolveByName() throws {
		#expect(try columnName(\EmptyDefault.kids) == "kids")
		#expect(try columnName(\EmptyDefault.pets) == "pets")
	}

	@Test func aProbeThatFailsToDecodeIsSkipped() throws {
		#expect(try columnName(\RequiresA.a) == "a")
		#expect(try columnName(\RequiresA.b) == "b")
	}

	@Test func aKeyDecodedTwiceIsOneCandidate() throws {
		#expect(try columnName(\DoubleDecoded.kids) == "kids")
		#expect(try columnName(\DoubleDecoded.pets) == "pets")
	}

	@Test func optionalElementsAndUnkeyedNonArraysResolveByName() throws {
		#expect(try columnName(\OptionalElements.a) == "a")
		#expect(try columnName(\OptionalElements.b) == "b")
		#expect(try columnName(\MaybeOnes.a) == "a")
		#expect(try columnName(\MaybeOnes.b) == "b")
	}

	@Test func indistinguishableColumnsThrow() throws {
		// Probes that can't be built say nothing, so this isn't "nested".
		expectAmbiguous { _ = try columnName(\StatusLists.a) }
		expectAmbiguous { _ = try columnName(\StatusLists.b) }
		// Keyed containers aren't filled.
		expectAmbiguous { _ = try columnName(\KidMaps.a) }
		expectAmbiguous { _ = try columnName(\KidMaps.b) }
		expectAmbiguous { _ = try columnName(\TwoEmpty.e1) }
		expectAmbiguous { _ = try columnName(\TwoEmpty.e2) }
		// A single column of such a type is still resolved by type.
		#expect(try columnName(\OneEmpty.e) == "e")
	}

	@Test func nestedPathsThroughTheSecondColumnStillThrow() throws {
		for keyPath: PartialKeyPath<Pair> in [\Pair.req.x, \Pair.req.y, \Pair.other?.x] {
			let error = #expect(throws: CRUDSQLGenError.self) {
				_ = try columnName(keyPath)
			}
			#expect(error?.description.contains("top-level property") == true)
		}
	}

	@Test func orderBySecondColumn() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try StatefulStubConfig())
		let select = try db.table(Pair.self).order(by: \Pair.req).select()
		let sql = try #require(select.sqlGenState.statements.first?.sql)
		#expect(sql.hasSuffix("ORDER BY \"t0\".\"req\""), "SQL was: \(sql)")
	}

	@Test func whereOnSecondColumn() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try StatefulStubConfig())
		// No public operator compares a Codable column, but key path
		// expressions resolve the same way the operators' do.
		let expr = RealBooleanExpression(.equality(lhs: .keyPath(\Pair.other), rhs: .null))
		let select = try db.table(Pair.self).where(expr).select()
		let sql = try #require(select.sqlGenState.statements.first?.sql)
		#expect(sql.contains("\"t0\".\"other\" IS NULL"), "SQL was: \(sql)")
	}

	@Test func insertIgnoreAndSetKeysOnSecondColumn() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		let db = Database(configuration: config)
		_ = try db.table(Pair.self).insert(samplePair, ignoreKeys: \Pair.req)
		_ = try db.table(Pair.self).insert(samplePair, setKeys: \Pair.id, \Pair.req)
		let rows = config.store.rows(table: "Pair")
		#expect(rows.count == 2)
		#expect(Set(rows.first?.keys ?? [:].keys) == ["id", "opt", "other"])   // was ["id", "other", "req"]
		#expect(Set(rows.last?.keys ?? [:].keys) == ["id", "req"])    // was ["id", "opt"]
	}

	@Test func updateSetAndIgnoreKeysOnSecondColumn() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try StatefulStubConfig())
		let set = try db.table(Pair.self).where(\Pair.id == 1).update(samplePair, setKeys: \Pair.req)
		let setSQL = try #require(set.sqlGenState.statements.first?.sql)
		#expect(setSQL.contains("SET \"req\"=?"), "SQL was: \(setSQL)")
		#expect(!setSQL.contains("\"opt\""), "SQL was: \(setSQL)")
		let ignore = try db.table(Pair.self).where(\Pair.id == 1).update(samplePair, ignoreKeys: \Pair.req)
		let ignoreSQL = try #require(ignore.sqlGenState.statements.first?.sql)
		#expect(ignoreSQL.contains("\"opt\"=?"), "SQL was: \(ignoreSQL)")
		#expect(!ignoreSQL.contains("\"req\""), "SQL was: \(ignoreSQL)")
	}

	@Test func joinOnSecondArrayFillsThatArray() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		let db = Database(configuration: config)
		try db.table(Parent.self).insert(Parent(id: 1, name: "p", kids: nil, pets: nil))
		try db.table(Kid.self).insert(Kid(id: 7, parentId: 1, name: "rex"))
		let parents = try db.table(Parent.self)
			.join(\.pets, on: \.id, equals: \.parentId)
			.select().map { $0 }
		let parent = try #require(parents.first)
		#expect(parent.pets == [Kid(id: 7, parentId: 1, name: "rex")])
		#expect(parent.kids == nil)   // was the joined rows, with pets nil
	}

	@Test func joinOnAnArrayDefaultedFromNil() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		let db = Database(configuration: config)
		try db.table(EmptyDefault.self).insert(EmptyDefault(id: 1, kids: nil, pets: nil))
		try db.table(Kid.self).insert(Kid(id: 7, parentId: 1, name: "rex"))
		let rows = try db.table(EmptyDefault.self)
			.join(\.pets, on: \.id, equals: \.parentId)
			.select().map { $0 }
		let row = try #require(rows.first)
		#expect(row.pets == [Kid(id: 7, parentId: 1, name: "rex")])
		#expect(row.kids == [])
	}
}
