import Testing
import Foundation
@testable import PerfectCRUD

// Key paths that reach *through* a property into a nested Codable type, such
// as `\WithSub.sub?.x`. Column names are resolved by value, and the nested
// type's values restart at the same counter as the table's own, so these
// used to resolve silently to one of the table's columns (`sub?.x` became
// "id"). They must throw instead. Top-level key paths, including Codable
// columns and join arrays, must keep resolving as before.

private struct Inner: Codable {
	var z: Int
}

private struct Sub: Codable {
	var x: Int
	var label: String
	var flag: Bool
	var when: Date?
	var inner: Inner?
}

private struct Child: Codable {
	var id: Int
	var parentId: Int
	var name: String
}

private struct WithSub: Codable {
	var id: Int
	var name: String
	var flag: Bool
	var sub: Sub?
	var req: Sub
	var inner: Inner
	var children: [Child]?
}

private final class Owner: Codable {
	var id: Int
	var pet: Sub?
	init(id: Int, pet: Sub?) {
		self.id = id
		self.pet = pet
	}
}

// `id` is never decoded, so it's random in every instance and in every probe.
private struct Addr: Codable, Identifiable {
	let id = UUID()
	var street: String
	private enum CodingKeys: String, CodingKey {
		case street
	}
}

private struct Person: Codable {
	var id: Int
	var name: String
	var addr: Addr
}

// Codable types with no scalar fields of their own.
private struct Leaf: Codable {
	var x: Int
}

private struct Wrap: Codable {
	var leaf: Leaf?
}

private struct Mid: Codable {
	var w: Wrap
}

private struct HasWrap: Codable {
	var id: Int
	var w: Wrap
	var mid: Mid
}

// Column types whose decoded values don't sit one Mirror level down.
private struct WrappedOnly: Codable {
	@PrimaryKey var x: Int
}

private struct Flattened: Codable {
	var leaf: Leaf
	init(from decoder: Decoder) throws {
		leaf = try Leaf(from: decoder)
	}
	func encode(to encoder: Encoder) throws {
		try leaf.encode(to: encoder)
	}
}

private struct Unboxed: Codable {
	var x: Int
	enum CodingKeys: CodingKey {
		case x
	}
	init(from decoder: Decoder) throws {
		x = try decoder.container(keyedBy: CodingKeys.self).decode(Leaf.self, forKey: .x).x
	}
	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encode(Leaf(x: x), forKey: .x)
	}
}

// Its only first-level scalar is a constant the decoder never sets.
private struct Versioned: Codable {
	var version = 3
	var leaf: Leaf
	private enum CodingKeys: String, CodingKey {
		case leaf
	}
}

private struct Shapes: Codable {
	var id: Int
	var wrapped: WrappedOnly
	var flat: Flattened
	var unboxed: Unboxed
	var versioned: Versioned
}

// Columns that init(from:) derives from their decoded value, so a skewed
// decode can map back to the same value.
private struct Clamped: Codable {
	var level: Int
	var mask: Int
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		level = max(try c.decode(Int.self, forKey: .level), 2)
		mask = try c.decode(Int.self, forKey: .mask) | 1
	}
}

private struct Normalised: Codable {
	var id: Int
	var isActive: Bool
	var deletedAt: Date?
	var level: Int
	var clamped: Clamped
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .id)
		isActive = try c.decode(Bool.self, forKey: .isActive)
		deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
		level = max(try c.decode(Int.self, forKey: .level), 4)
		clamped = try c.decode(Clamped.self, forKey: .clamped)
		if deletedAt != nil {
			isActive = false
		}
	}
}

// Its init(from:) rejects the shifted values of whole-model probes.
private struct Validated: Codable {
	var id: Int
	var rating: Int
	var sub: Sub?
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .id)
		rating = try c.decode(Int.self, forKey: .rating)
		sub = try c.decodeIfPresent(Sub.self, forKey: .sub)
		guard (1...3).contains(rating) else {
			throw CRUDDecoderError("rating out of range")
		}
	}
}

// A nested init(from:) that resolves key paths itself, while the probes for
// the table are being built.
private struct Reentrant: Codable {
	var x: Int
	enum CodingKeys: CodingKey {
		case x
	}
	init(from decoder: Decoder) throws {
		x = try decoder.container(keyedBy: CodingKeys.self).decode(Int.self, forKey: .x)
		_ = try columnName(\HasWrap.w)
	}
	func encode(to encoder: Encoder) throws {}
}

private struct HasReentrant: Codable {
	var id: Int
	var r: Reentrant
}

private final class NestedStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		throw CRUDSQLExeError("not executed in these tests")
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

private func whereSQL(_ expr: CRUDBooleanExpression) throws -> String {
	CRUDClearTableStructureCache()
	let db = Database(configuration: try NestedStubConfig())
	let select = try db.table(WithSub.self).where(expr).select()
	return try #require(select.sqlGenState.statements.first?.sql)
}

private func columnName<T: Codable>(_ keyPath: PartialKeyPath<T>) throws -> String? {
	let decoder = CRUDKeyPathsDecoder()
	let instance = try T(from: decoder)
	return try decoder.getKeyPathName(instance, keyPath: keyPath)
}

private func expectNestedError(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
	let error = #expect(throws: CRUDSQLGenError.self, sourceLocation: sourceLocation) {
		try body()
	}
	#expect(error?.description.contains("top-level property") == true, sourceLocation: sourceLocation)
}

@Suite("Nested and optional-chained key paths", .serialized)
struct NestedKeyPathTests {

	static let nestedWheres = [
		"sub?.x ==", "sub?.x !=", "sub?.x <", "sub?.x >", "sub?.x <=", "sub?.x >=",
		"sub?.label", "sub?.flag", "sub?.when", "sub?.inner?.z", "req.x", "req.label", "req.flag",
	]

	@Test(arguments: nestedWheres)
	func whereThroughNestedPropertyThrows(_ which: String) throws {
		let expr: CRUDBooleanExpression = switch which {
		case "sub?.x ==": \WithSub.sub?.x == 3
		case "sub?.x !=": \WithSub.sub?.x != 3
		case "sub?.x <": \WithSub.sub?.x < 3
		case "sub?.x >": \WithSub.sub?.x > 3
		case "sub?.x <=": \WithSub.sub?.x <= 3
		case "sub?.x >=": \WithSub.sub?.x >= 3
		case "sub?.label": \WithSub.sub?.label == "a"
		case "sub?.flag": \WithSub.sub?.flag == true
		case "sub?.when": \WithSub.sub?.when == nil
		case "sub?.inner?.z": \WithSub.sub?.inner?.z == 1
		case "req.x": \WithSub.req.x == 3
		case "req.label": \WithSub.req.label == "a"
		default: \WithSub.req.flag == false
		}
		expectNestedError { _ = try whereSQL(expr) }
	}

	@Test func topLevelWheresStillResolve() throws {
		let sql = try whereSQL(\WithSub.id == 1 && \WithSub.name == "n" && \WithSub.flag == true)
		let whereClause = try #require(sql.components(separatedBy: "WHERE").last)
		#expect(whereClause.contains("\"id\" = ?"), "SQL was: \(sql)")
		#expect(whereClause.contains("\"name\" = ?"), "SQL was: \(sql)")
		#expect(whereClause.contains("\"flag\" = ?"), "SQL was: \(sql)")
	}

	@Test func orderByThroughNestedPropertyThrows() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try NestedStubConfig())
		expectNestedError { _ = try db.table(WithSub.self).order(by: \WithSub.sub?.x).select() }
		expectNestedError { _ = try db.table(WithSub.self).order(by: \WithSub.req.label).select() }
	}

	@Test func topLevelColumnsResolveByName() throws {
		#expect(try columnName(\WithSub.id) == "id")
		#expect(try columnName(\WithSub.name) == "name")
		#expect(try columnName(\WithSub.flag) == "flag")
		#expect(try columnName(\WithSub.sub) == "sub")
		// `sub` and `req` are both `Sub`; matching by type alone gave "sub".
		#expect(try columnName(\WithSub.req) == "req")
		#expect(try columnName(\WithSub.inner) == "inner")
		#expect(try columnName(\WithSub.children) == "children")
	}

	@Test func nestedPathsAreRejectedByResolution() throws {
		// Scalar leaves that collide with a top-level column...
		expectNestedError { _ = try columnName(\WithSub.sub?.x) }      // was "id"
		expectNestedError { _ = try columnName(\WithSub.req.label) }   // was "name"
		expectNestedError { _ = try columnName(\WithSub.sub?.flag) }   // was "flag"
		// ...and Codable leaves whose type is also a top-level column's type.
		expectNestedError { _ = try columnName(\WithSub.sub?.inner) }  // was "inner"
		expectNestedError { _ = try columnName(\WithSub.req.inner) }   // was "inner"
	}

	@Test func classModelsAreChecked() throws {
		#expect(try columnName(\Owner.id) == "id")
		#expect(try columnName(\Owner.pet) == "pet")
		expectNestedError { _ = try columnName(\Owner.pet?.x) }
	}

	@Test func insertIgnoreKeysThroughNestedPropertyThrows() throws {
		CRUDClearTableStructureCache()
		let db = Database(configuration: try StatefulStubConfig())
		let row = WithSub(id: 1, name: "n", flag: false, sub: nil,
						  req: Sub(x: 1, label: "l", flag: true, when: nil, inner: nil),
						  inner: Inner(z: 1), children: nil)
		// Used to drop the "id" column from the INSERT without complaint.
		expectNestedError { _ = try db.table(WithSub.self).insert(row, ignoreKeys: \WithSub.sub?.x) }
	}

	@Test func joinOnArraySubTableStillWorks() throws {
		CRUDClearTableStructureCache()
		let config = try StatefulStubConfig()
		let db = Database(configuration: config)
		let join = try db.table(WithSub.self)
			.join(\.children, on: \.id, equals: \.parentId)
			.where(\WithSub.name == "n")
		let select = try join.select()
		#expect(select.sqlGenState.statements.count == 2)
		let childSQL = try #require(select.sqlGenState.statements.last?.sql)
		#expect(childSQL.contains("\"parentId\""), "SQL was: \(childSQL)")
		// Executing resolves `\.children` and `\.id` against the model instance.
		#expect(try select.map { $0 }.isEmpty)
	}

	@Test func undecodedRandomFieldsDontMakeAColumnLookNested() throws {
		#expect(try columnName(\Person.addr) == "addr")
		#expect(try columnName(\Person.name) == "name")
		expectNestedError { _ = try columnName(\Person.addr.street) }
		// Never decoded, so random: it used to resolve to whatever column had
		// its first byte as a counter, or trap when that byte was over 127.
		for _ in 0..<50 {
			let error = #expect(throws: CRUDSQLGenError.self) { _ = try columnName(\Person.addr.id) }
			#expect(error?.description.contains("init(from:) decodes") == true)
		}
		CRUDClearTableStructureCache()
		let db = Database(configuration: try StatefulStubConfig())
		let p = Person(id: 1, name: "n", addr: Addr(street: "s"))
		// Both used to throw while the check compared the random `id` too.
		_ = try db.table(Person.self).where(\Person.id == 1).update(p, setKeys: \.addr)
		_ = try db.table(Person.self).insert(p, ignoreKeys: \.addr)
	}

	@Test func codableLeavesWithoutScalarFieldsAreChecked() throws {
		#expect(try columnName(\HasWrap.w) == "w")
		#expect(try columnName(\HasWrap.mid) == "mid")
		expectNestedError { _ = try columnName(\HasWrap.mid.w) }       // was "w"
		expectNestedError { _ = try columnName(\HasWrap.mid.w.leaf) }
		expectNestedError { _ = try columnName(\HasWrap.mid.w.leaf?.x) }
	}

	@Test func columnTypesOfEveryShapeResolve() throws {
		#expect(try columnName(\Shapes.wrapped) == "wrapped")
		#expect(try columnName(\Shapes.flat) == "flat")
		#expect(try columnName(\Shapes.unboxed) == "unboxed")
		#expect(try columnName(\Shapes.versioned) == "versioned")
		expectNestedError { _ = try columnName(\Shapes.flat.leaf) }
		expectNestedError { _ = try columnName(\Shapes.versioned.leaf.x) }
		// A constant default the decoder never sets used to resolve to "versioned".
		let error = #expect(throws: CRUDSQLGenError.self) { _ = try columnName(\Shapes.versioned.version) }
		#expect(error?.description.contains("init(from:) decodes") == true)
		CRUDClearTableStructureCache()
		let db = Database(configuration: try NestedStubConfig())
		_ = try db.table(Shapes.self).order(by: \.flat, \.versioned).select()
	}

	@Test func nestedInitFromThatResolvesKeyPathsDoesNotDeadlock() throws {
		#expect(try columnName(\HasReentrant.r) == "r")
		expectNestedError { _ = try columnName(\HasReentrant.r.x) }
	}

	@Test func derivedColumnsResolveAndDerivedNestedValuesThrow() throws {
		#expect(try columnName(\Normalised.isActive) == "isActive")
		#expect(try columnName(\Normalised.level) == "level")
		#expect(try columnName(\Normalised.clamped) == "clamped")
		expectNestedError { _ = try columnName(\Normalised.clamped.level) }
		expectNestedError { _ = try columnName(\Normalised.clamped.mask) }
	}

	@Test func modelsThatValidateTheirFieldsAreStillChecked() throws {
		#expect(try columnName(\Validated.id) == "id")
		#expect(try columnName(\Validated.rating) == "rating")
		expectNestedError { _ = try columnName(\Validated.sub?.x) }  // was "id"
	}
}
