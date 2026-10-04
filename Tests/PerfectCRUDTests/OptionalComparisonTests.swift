import Testing
import Foundation
@testable import PerfectCRUD

// `<`, `<=`, `>`, `>=` against key paths to Optional columns. Before these
// overloads existed, `\Reading.od < 3.0` didn't compile at all, so most of
// the value of this file is that it builds; the assertions check that each
// overload renders the right SQL operator and binds the right value case.

private struct Reading: Codable {
	var id: Int
	var os: String?
	var od: Double?
	var ob: Bool?
	var ou: UUID?
	var odate: Date?
	var oi: Int?
	var oui: UInt?
	var oi64: Int64?
	var oui64: UInt64?
	var oi32: Int32?
	var oui32: UInt32?
	var oi16: Int16?
	var oui16: UInt16?
	var oi8: Int8?
	var oui8: UInt8?
	// Non-optional twins: comparisons on these must still compile unambiguously
	// next to the optional overloads. (Both overload sets render the same SQL,
	// so this can't tell which one was picked, and it doesn't need to.)
	var d: Double
	var i: Int
}

private final class ComparisonStubConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		throw CRUDSQLExeError("not executed in these tests")
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

/// The WHERE clause SQL and its bindings, rendered without executing anything.
private func render(_ expr: CRUDBooleanExpression) throws -> (sql: String, bindings: [String]) {
	CRUDClearTableStructureCache()
	let db = Database(configuration: try ComparisonStubConfig())
	let select = try db.table(Reading.self).where(expr).select()
	let statement = try #require(select.sqlGenState.statements.first)
	return (statement.sql, statement.bindings.map { String(describing: $0.1) })
}

private func expectComparison(_ expr: CRUDBooleanExpression, _ column: String, _ op: String, _ binding: String,
							  sourceLocation: SourceLocation = #_sourceLocation) throws {
	let (sql, bindings) = try render(expr)
	#expect(sql.contains("\"\(column)\" \(op) ?"), "SQL was: \(sql)", sourceLocation: sourceLocation)
	#expect(bindings == [binding], sourceLocation: sourceLocation)
}

@Suite("Optional-column comparisons", .serialized)
struct OptionalComparisonTests {

	@Test func doubleAllFourOperators() throws {
		try expectComparison(\Reading.od < 3.0, "od", "<", "decimal(3.0)")
		try expectComparison(\Reading.od <= 3.0, "od", "<=", "decimal(3.0)")
		try expectComparison(\Reading.od > 3.0, "od", ">", "decimal(3.0)")
		try expectComparison(\Reading.od >= 3.0, "od", ">=", "decimal(3.0)")
	}

	@Test func stringBoolUUIDDate() throws {
		let uuid = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
		let date = Date(timeIntervalSince1970: 1_000)
		try expectComparison(\Reading.os < "m", "os", "<", "string(\"m\")")
		try expectComparison(\Reading.ob >= true, "ob", ">=", "bool(true)")
		try expectComparison(\Reading.ou > uuid, "ou", ">", "uuid(\(uuid))")
		try expectComparison(\Reading.odate <= date, "odate", "<=", "date(\(date))")
	}

	@Test func integerFamily() throws {
		try expectComparison(\Reading.oi < 5, "oi", "<", "integer(5)")
		try expectComparison(\Reading.oui > 5, "oui", ">", "uinteger(5)")
		try expectComparison(\Reading.oi64 <= 5, "oi64", "<=", "integer64(5)")
		try expectComparison(\Reading.oui64 >= 5, "oui64", ">=", "uinteger64(5)")
		try expectComparison(\Reading.oi32 < 5, "oi32", "<", "integer32(5)")
		try expectComparison(\Reading.oui32 > 5, "oui32", ">", "uinteger32(5)")
		try expectComparison(\Reading.oi16 <= 5, "oi16", "<=", "integer16(5)")
		try expectComparison(\Reading.oui16 >= 5, "oui16", ">=", "uinteger16(5)")
		try expectComparison(\Reading.oi8 < 5, "oi8", "<", "integer8(5)")
		try expectComparison(\Reading.oui8 > 5, "oui8", ">", "uinteger8(5)")
	}

	@Test func nonOptionalKeyPathsStillCompileUnambiguously() throws {
		try expectComparison(\Reading.d < 3.0, "d", "<", "decimal(3.0)")
		try expectComparison(\Reading.i >= 7, "i", ">=", "integer(7)")
	}

	@Test func nonOptionalVariableOnTheRight() throws {
		let limit: Double = 2.5
		try expectComparison(\Reading.od > limit, "od", ">", "decimal(2.5)")
	}

	@Test func combinesWithLogicalAndEqualityOperators() throws {
		let (sql, bindings) = try render(
			\Reading.od > 1.0 && \Reading.od < 9.0 && \Reading.oi != nil || \Reading.os <= "z")
		#expect(sql.contains("\"od\" > ?"))
		#expect(sql.contains("\"od\" < ?"))
		#expect(sql.contains("\"oi\" IS NOT NULL"))
		#expect(sql.contains("\"os\" <= ?"))
		#expect(bindings == ["decimal(1.0)", "decimal(9.0)", "string(\"z\")"])
	}
}
