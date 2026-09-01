import Foundation

public enum DynamicValue: Equatable, Sendable {
	case null
	case bool(Bool)
	case int(Int64)
	case uint(UInt64)
	case double(Double)
	case string(String)
	case bytes([UInt8])
	case date(Date)

	var crudExpression: CRUDExpression {
		switch self {
		case .null: .null
		case .bool(let value): .bool(value)
		case .int(let value): .integer64(value)
		case .uint(let value): .uinteger64(value)
		case .double(let value): .decimal(value)
		case .string(let value): .string(value)
		case .bytes(let value): .blob(value)
		case .date(let value): .date(value)
		}
	}
}

public struct DynamicRow: Equatable, Sendable {
	public let values: [String: DynamicValue]

	public init(_ values: [String: DynamicValue]) {
		self.values = Dictionary(uniqueKeysWithValues: values.map {
			($0.key.lowercased(), $0.value)
		})
	}

	public subscript(_ field: String) -> DynamicValue? {
		values[field.lowercased()]
	}
}

public enum DynamicComparison: Equatable, Sendable {
	case equal
	case notEqual
	case greaterThan
	case greaterThanOrEqual
	case lessThan
	case lessThanOrEqual
	case beginsWith
	case endsWith
	case contains
}

public struct DynamicPredicate: Equatable, Sendable {
	public let field: String
	public let comparison: DynamicComparison
	public let value: DynamicValue

	public init(field: String, comparison: DynamicComparison, value: DynamicValue) {
		self.field = field
		self.comparison = comparison
		self.value = value
	}
}

public struct DynamicOrdering: Equatable, Sendable {
	public let field: String
	public let descending: Bool

	public init(field: String, descending: Bool = false) {
		self.field = field
		self.descending = descending
	}
}

public struct DynamicQuery: Equatable, Sendable {
	public let table: String
	public let fields: [String]
	public let predicates: [DynamicPredicate]
	public let orderings: [DynamicOrdering]
	public let limit: Int?
	public let offset: Int?

	public init(
		table: String,
		fields: [String] = [],
		predicates: [DynamicPredicate] = [],
		orderings: [DynamicOrdering] = [],
		limit: Int? = nil,
		offset: Int? = nil
	) {
		self.table = table
		self.fields = fields
		self.predicates = predicates
		self.orderings = orderings
		self.limit = limit
		self.offset = offset
	}
}

public struct DynamicResult: Equatable, Sendable {
	public let rows: [DynamicRow]
	public let affectedRows: Int
	public let statement: String
	/// The connector-reported auto-generated primary key from the most
	/// recently executed INSERT, when the connector and table support one.
	/// `nil` for reads, non-insert mutations, or connectors that can't
	/// report this.
	public let insertedID: Int64?

	public init(rows: [DynamicRow], affectedRows: Int = 0, statement: String, insertedID: Int64? = nil) {
		self.rows = rows
		self.affectedRows = affectedRows
		self.statement = statement
		self.insertedID = insertedID
	}
}

/// A single dynamic INSERT/UPDATE/DELETE, generated the same way
/// `DynamicQuery` generates a SELECT — through the connector-agnostic
/// `SQLGenDelegate`/`SQLExeDelegate` abstraction, so it works across any
/// PerfectCRUD connector without per-connector mutation code.
public struct DynamicMutation: Sendable, Equatable {
	public enum Action: Sendable, Equatable {
		case insert
		case update
		case delete
	}

	public let action: Action
	public let table: String
	public let values: [String: DynamicValue]
	public let predicates: [DynamicPredicate]
	public let limit: Int?

	public init(
		action: Action,
		table: String,
		values: [String: DynamicValue] = [:],
		predicates: [DynamicPredicate] = [],
		limit: Int? = nil
	) {
		self.action = action
		self.table = table
		self.values = values
		self.predicates = predicates
		self.limit = limit
	}
}

/// A single raw SQL statement, executed through the same connector
/// abstraction as everything else in this file. Deliberately does not do
/// any SQL parsing beyond a best-effort multi-statement guard (see
/// `execute(_:)` below) — callers decide policy (capability gating,
/// allowlists) before constructing one of these.
public struct DynamicSQL: Sendable, Equatable {
	public let sql: String
	public let bindings: [DynamicValue]
	public let allowsMultipleStatements: Bool

	public init(sql: String, bindings: [DynamicValue] = [], allowsMultipleStatements: Bool = false) {
		self.sql = sql
		self.bindings = bindings
		self.allowsMultipleStatements = allowsMultipleStatements
	}
}

public protocol DynamicDatabaseProtocol: DatabaseProtocol {
	func select(_ query: DynamicQuery) throws -> DynamicResult
	func mutate(_ mutation: DynamicMutation) throws -> DynamicResult
	func execute(_ sql: DynamicSQL) throws -> DynamicResult
}

extension Database: DynamicDatabaseProtocol {
	public func select(_ query: DynamicQuery) throws -> DynamicResult {
		var compiler = DynamicQueryCompiler(
			query: query,
			delegate: configuration.sqlGenDelegate
		)
		let generated = try compiler.compile()
		CRUDLogging.log(.query, generated.sql)
		let executor = try configuration.sqlExeDelegate(forSQL: generated.sql)
		try executor.bind(generated.bindings, skip: 0)
		var rows: [DynamicRow] = []
		while try executor.hasNext() {
			guard let row = try executor.nextDynamicRow() else {
				throw CRUDSQLExeError("Connector returned no dynamic row for an available result.")
			}
			rows.append(row)
		}
		return DynamicResult(rows: rows, statement: generated.sql)
	}

	public func mutate(_ mutation: DynamicMutation) throws -> DynamicResult {
		var compiler = DynamicMutationCompiler(
			mutation: mutation,
			delegate: configuration.sqlGenDelegate
		)
		let generated = try compiler.compile()
		CRUDLogging.log(.query, generated.sql)
		let executor = try configuration.sqlExeDelegate(forSQL: generated.sql)
		try executor.bind(generated.bindings, skip: 0)
		// INSERT/UPDATE/DELETE never yield rows, but hasNext() is what
		// actually triggers execution on this connector abstraction —
		// mirrors select()'s loop, just with zero iterations expected.
		_ = try executor.hasNext()
		return DynamicResult(
			rows: [],
			affectedRows: executor.affectedRowCount(),
			statement: generated.sql,
			insertedID: mutation.action == .insert ? executor.lastInsertedID() : nil
		)
	}

	public func execute(_ sql: DynamicSQL) throws -> DynamicResult {
		if !sql.allowsMultipleStatements {
			// Best-effort multi-statement guard, not a real SQL parser: a
			// semicolon anywhere except a single trailing one is treated as
			// more than one statement. A semicolon inside a string literal
			// would false-positive here — acceptable for a safety net whose
			// job is "don't silently run a batch nobody asked for," not
			// "validate arbitrary SQL."
			let trimmed = sql.sql.trimmingCharacters(in: .whitespacesAndNewlines)
			let withoutTrailingSemicolon = trimmed.hasSuffix(";") ? String(trimmed.dropLast()) : trimmed
			guard !withoutTrailingSemicolon.contains(";") else {
				throw CRUDSQLGenError(
					"Raw SQL execution found what looks like multiple statements; pass allowsMultipleStatements to permit this."
				)
			}
		}
		CRUDLogging.log(.query, sql.sql)
		let executor = try configuration.sqlExeDelegate(forSQL: sql.sql)
		try executor.bind(sql.bindings.map { ("", $0.crudExpression) }, skip: 0)
		var rows: [DynamicRow] = []
		while try executor.hasNext() {
			guard let row = try executor.nextDynamicRow() else { break }
			rows.append(row)
		}
		return DynamicResult(
			rows: rows,
			affectedRows: executor.affectedRowCount(),
			statement: sql.sql,
			insertedID: executor.lastInsertedID()
		)
	}
}

private struct DynamicQueryCompiler {
	let query: DynamicQuery
	var delegate: SQLGenDelegate

	mutating func compile() throws -> (sql: String, bindings: Bindings) {
		guard query.table.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic query requires a table.")
		}
		if let limit = query.limit, limit < 0 {
			throw CRUDSQLGenError("Dynamic query limit must not be negative.")
		}
		if let offset = query.offset, offset < 0 {
			throw CRUDSQLGenError("Dynamic query offset must not be negative.")
		}

		delegate.bindings = []
		let fields = try query.fields.isEmpty
			? "*"
			: query.fields.map { try delegate.quote(identifier: $0) }.joined(separator: ", ")
		var sql = "SELECT \(fields) FROM \(try delegate.quote(identifier: query.table))"

		if query.predicates.isEmpty == false {
			var clauses: [String] = []
			for predicate in query.predicates {
				clauses.append(try compilePredicate(predicate))
			}
			sql += " WHERE " + clauses.joined(separator: " AND ")
		}
		if query.orderings.isEmpty == false {
			let clauses = try query.orderings.map {
				try delegate.quote(identifier: $0.field) + ($0.descending ? " DESC" : "")
			}
			sql += " ORDER BY " + clauses.joined(separator: ", ")
		}
		if let limit = query.limit {
			sql += " LIMIT \(limit)"
		}
		if let offset = query.offset {
			guard query.limit != nil else {
				throw CRUDSQLGenError("Dynamic query offset requires a limit.")
			}
			sql += " OFFSET \(offset)"
		}
		return (sql, delegate.bindings)
	}

	private mutating func compilePredicate(_ predicate: DynamicPredicate) throws -> String {
		try compileDynamicPredicate(predicate, delegate: &delegate)
	}
}

private struct DynamicMutationCompiler {
	let mutation: DynamicMutation
	var delegate: SQLGenDelegate

	mutating func compile() throws -> (sql: String, bindings: Bindings) {
		guard mutation.table.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic mutation requires a table.")
		}
		if let limit = mutation.limit, limit < 0 {
			throw CRUDSQLGenError("Dynamic mutation limit must not be negative.")
		}
		delegate.bindings = []
		switch mutation.action {
		case .insert: return try compileInsert()
		case .update: return try compileUpdate()
		case .delete: return try compileDelete()
		}
	}

	private mutating func compileInsert() throws -> (sql: String, bindings: Bindings) {
		guard mutation.values.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic insert requires at least one value.")
		}
		let columns = mutation.values.keys.sorted()
		let quotedColumns = try columns.map { try delegate.quote(identifier: $0) }.joined(separator: ", ")
		let placeholders = try columns.map { column in
			try delegate.getBinding(for: mutation.values[column]!.crudExpression)
		}
		let table = try delegate.quote(identifier: mutation.table)
		let sql = "INSERT INTO \(table) (\(quotedColumns)) VALUES (\(placeholders.joined(separator: ", ")))"
		return (sql, delegate.bindings)
	}

	private mutating func compileUpdate() throws -> (sql: String, bindings: Bindings) {
		guard mutation.values.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic update requires at least one value.")
		}
		guard mutation.predicates.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic update requires at least one predicate to target records — refusing to update every row in a table by accident.")
		}
		let columns = mutation.values.keys.sorted()
		var setClauses: [String] = []
		for column in columns {
			let placeholder = try delegate.getBinding(for: mutation.values[column]!.crudExpression)
			setClauses.append("\(try delegate.quote(identifier: column)) = \(placeholder)")
		}
		let table = try delegate.quote(identifier: mutation.table)
		var sql = "UPDATE \(table) SET \(setClauses.joined(separator: ", "))"
		sql += " WHERE " + (try mutation.predicates.map { try compileDynamicPredicate($0, delegate: &delegate) }.joined(separator: " AND "))
		if let limit = mutation.limit {
			sql += " LIMIT \(limit)"
		}
		return (sql, delegate.bindings)
	}

	private mutating func compileDelete() throws -> (sql: String, bindings: Bindings) {
		guard mutation.predicates.isEmpty == false else {
			throw CRUDSQLGenError("Dynamic delete requires at least one predicate to target records — refusing to delete every row in a table by accident.")
		}
		let table = try delegate.quote(identifier: mutation.table)
		var sql = "DELETE FROM \(table)"
		sql += " WHERE " + (try mutation.predicates.map { try compileDynamicPredicate($0, delegate: &delegate) }.joined(separator: " AND "))
		if let limit = mutation.limit {
			sql += " LIMIT \(limit)"
		}
		return (sql, delegate.bindings)
	}
}

/// Shared by `DynamicQueryCompiler` (SELECT WHERE clauses) and
/// `DynamicMutationCompiler` (UPDATE/DELETE WHERE clauses) — identical
/// comparison-to-SQL mapping either way.
private func compileDynamicPredicate(_ predicate: DynamicPredicate, delegate: inout SQLGenDelegate) throws -> String {
	let field = try delegate.quote(identifier: predicate.field)
	switch (predicate.comparison, predicate.value) {
	case (.equal, .null):
		return "\(field) IS NULL"
	case (.notEqual, .null):
		return "\(field) IS NOT NULL"
	default:
		break
	}

	let operation: String
	let value: DynamicValue
	switch predicate.comparison {
	case .equal:
		operation = "="
		value = predicate.value
	case .notEqual:
		operation = "!="
		value = predicate.value
	case .greaterThan:
		operation = ">"
		value = predicate.value
	case .greaterThanOrEqual:
		operation = ">="
		value = predicate.value
	case .lessThan:
		operation = "<"
		value = predicate.value
	case .lessThanOrEqual:
		operation = "<="
		value = predicate.value
	case .beginsWith:
		operation = "LIKE"
		value = .string(predicate.value.stringValue + "%")
	case .endsWith:
			operation = "LIKE"
			value = .string("%" + predicate.value.stringValue)
		case .contains:
			operation = "LIKE"
			value = .string("%" + predicate.value.stringValue + "%")
		}
	let placeholder = try delegate.getBinding(for: value.crudExpression)
	return "\(field) \(operation) \(placeholder)"
}

private extension DynamicValue {
	var stringValue: String {
		switch self {
		case .null: ""
		case .bool(let value): value ? "true" : "false"
		case .int(let value): String(value)
		case .uint(let value): String(value)
		case .double(let value): String(value)
		case .string(let value): value
		case .bytes(let value): String(decoding: value, as: UTF8.self)
		case .date(let value): value.ISO8601Format()
		}
	}
}
