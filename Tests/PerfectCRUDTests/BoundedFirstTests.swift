import Testing
import Foundation
@testable import PerfectCRUD

// first() reads one master row and only that row's joined objects. The master statement gets
// LIMIT 1 (keeping a user OFFSET) and a tie-break ORDER BY on each join key; each joined statement
// joins a derived table that repeats the master statement, with the master's bindings first.
// 1a37035 fixed first() on joins by reading the unlimited query, which fetched every child of
// every parent; 3.0.1 put the LIMIT 1 on the child statement. These tests record the SQL and
// bindings each statement is run with.

final class BFRecordedStatements: @unchecked Sendable {
	private let lock = NSLock()
	private var list: [(sql: String, bindings: [String])] = []
	private var genDelegates = 0
	func append(_ sql: String, _ bindings: Bindings) {
		lock.lock(); defer { lock.unlock() }
		list.append((sql, bindings.map(\.0)))
	}
	func madeGenDelegate() {
		lock.lock(); defer { lock.unlock() }
		genDelegates += 1
	}
	var statements: [(sql: String, bindings: [String])] {
		lock.lock(); defer { lock.unlock() }
		return list
	}
	var genDelegateCount: Int {
		lock.lock(); defer { lock.unlock() }
		return genDelegates
	}
}

final class BFRecordingGenDelegate: SQLGenDelegate, @unchecked Sendable {
	var bindings: Bindings = []
	let dollar: Bool
	init(dollar: Bool) { self.dollar = dollar }
	func getBinding(for expr: CRUDExpression) throws -> String {
		let id = dollar ? "$\(bindings.count + 1)" : "?"
		bindings.append((id, expr))
		return id
	}
	func quote(identifier: String) throws -> String { "\"\(identifier)\"" }
	func getCreateTableSQL(forTable: TableStructure, policy: TableCreatePolicy) throws -> [String] { [] }
	func getCreateIndexSQL(forTable name: String, on columns: [String], unique: Bool) throws -> [String] { [] }
}

struct BFRecordingExeDelegate: SQLExeDelegate {
	let sql: String
	let recorded: BFRecordedStatements
	func bind(_ bindings: Bindings, skip: Int) throws { recorded.append(sql, bindings) }
	func hasNext() throws -> Bool { false }
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>? { nil }
}

final class BFRecordingConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	let recorded = BFRecordedStatements()
	var dollar = false
	var sqlGenDelegate: SQLGenDelegate {
		recorded.madeGenDelegate()
		return BFRecordingGenDelegate(dollar: dollar)
	}
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		BFRecordingExeDelegate(sql: sql, recorded: recorded)
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

private struct BFKid: Codable { var id: Int; var parentId: Int }
private struct BFTag: Codable { var id: Int }
private struct BFParentTag: Codable { var parentId: Int; var tagId: Int }
private struct BFParent: Codable {
	var id: Int
	var name: String
	var kids: [BFKid]?
	var tags: [BFTag]?
}
private struct BFNode: Codable {
	var id: Int
	var parentId: Int?
	var children: [BFNode]?
}

/// Every placeholder in each statement has a binding, in order: `?` count, or `$1…$n`.
private func expectPlaceholdersMatch(_ statements: [(sql: String, bindings: [String])], dollar: Bool,
									 sourceLocation: SourceLocation = #_sourceLocation) {
	for statement in statements {
		if dollar {
			// NSRegularExpression, not Swift Regex: the test target builds at the package's iOS 15 minimum.
			let regex = try! NSRegularExpression(pattern: #"\$\d+"#)
			let range = NSRange(statement.sql.startIndex..., in: statement.sql)
			let ids = regex.matches(in: statement.sql, range: range).compactMap { Range($0.range, in: statement.sql).map { String(statement.sql[$0]) } }
			#expect(Set(ids) == Set((0..<statement.bindings.count).map { "$\($0 + 1)" }), "\(statement.sql)", sourceLocation: sourceLocation)
			#expect(statement.bindings == (0..<statement.bindings.count).map { "$\($0 + 1)" }, sourceLocation: sourceLocation)
		} else {
			#expect(statement.sql.filter { $0 == "?" }.count == statement.bindings.count, "\(statement.sql)", sourceLocation: sourceLocation)
		}
	}
}

@Suite("first() reads one master row and only its joined objects", .serialized)
struct BoundedFirstTests {
	private func db(dollar: Bool = false) throws -> (Database<BFRecordingConfig>, BFRecordedStatements) {
		CRUDClearTableStructureCache()
		let config = try BFRecordingConfig()
		config.dollar = dollar
		return (Database(configuration: config), config.recorded)
	}

	@Test func plainTableFirstIsOneLimitedStatement() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).first()
		#expect(recorded.statements.count == 1)
		#expect(recorded.statements[0].sql.hasSuffix("LIMIT 1"))
		#expect(!recorded.statements[0].sql.contains("ORDER BY"))
		// 1a37035 built (and logged) a second, unlimited SELECT it never ran.
		#expect(recorded.genDelegateCount == 1)
	}

	@Test func whereFirstIsLimited() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).where(\BFParent.name == "a").first()
		#expect(recorded.statements.count == 1)
		#expect(recorded.statements[0].sql.contains("LIMIT 1"))
		#expect(recorded.genDelegateCount == 1)
	}

	@Test func joinFirstBoundsTheChildStatement() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).join(\.kids, on: \.id, equals: \.parentId).first()
		let statements = recorded.statements
		try #require(statements.count == 2)
		let master = statements[0].sql
		#expect(master.contains("ORDER BY \"t0\".\"id\"\nLIMIT 1"))
		let child = statements[1].sql
		#expect(child.contains("JOIN (\(master)) AS \"t0\" ON \"t0\".\"id\" = \"t1\".\"parentId\""))
		// Its only LIMIT is the derived master's.
		#expect(!child.replacingOccurrences(of: master, with: "").contains("LIMIT"))
		#expect(!child.contains("LEFT JOIN \"BFParent\""))
		#expect(recorded.genDelegateCount == 1)
	}

	@Test(arguments: [false, true])
	func whereBindingsReachEveryStatement(dollar: Bool) throws {
		let (db, recorded) = try db(dollar: dollar)
		_ = try db.table(BFParent.self).join(\.kids, on: \.id, equals: \.parentId)
			.where(\BFParent.name == "a" && \BFKid.id > 2).first()
		let statements = recorded.statements
		try #require(statements.count == 2)
		#expect(statements[0].bindings.count == 2)
		// The derived master's two bindings, then the child's own two.
		#expect(statements[1].bindings.count == 4)
		#expect(statements[1].sql.contains("JOIN (\(statements[0].sql))"))
		expectPlaceholdersMatch(statements, dollar: dollar)
	}

	@Test(arguments: [false, true])
	func pivotJoinFirstIsBounded(dollar: Bool) throws {
		let (db, recorded) = try db(dollar: dollar)
		_ = try db.table(BFParent.self)
			.join(\.tags, with: BFParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.where(\BFParent.name == "a").first()
		let statements = recorded.statements
		try #require(statements.count == 2)
		#expect(statements[0].sql.contains("ORDER BY \"t0\".\"id\"\nLIMIT 1"))
		#expect(statements[1].sql.contains("JOIN (\(statements[0].sql)) AS \"t0\""))
		expectPlaceholdersMatch(statements, dollar: dollar)
	}

	@Test func doubleJoinBoundsBothChildren() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self)
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.tags, with: BFParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.first()
		let statements = recorded.statements
		try #require(statements.count == 3)
		let master = statements[0].sql
		#expect(master.hasSuffix("LIMIT 1"))
		#expect(statements[1].sql.contains("JOIN (\(master)) AS \"t0\""))
		#expect(statements[2].sql.contains("JOIN (\(master)) AS \"t0\""))
	}

	@Test func selfJoinFirstIsBounded() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFNode.self).join(\.children, on: \.id, equals: \.parentId).first()
		let statements = recorded.statements
		try #require(statements.count == 2)
		#expect(statements[0].sql.contains("FROM \"BFNode\" AS \"t0\""))
		#expect(statements[0].sql.contains("LIMIT 1"))
		#expect(statements[1].sql.contains("FROM \"BFNode\" AS \"t1\"\nJOIN (\(statements[0].sql)) AS \"t0\""))
	}

	@Test func limitBeforeJoinKeepsItsOffset() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).limit(5, skip: 2).join(\.kids, on: \.id, equals: \.parentId).first()
		let master = recorded.statements[0].sql
		#expect(master.contains("LIMIT 1\nOFFSET 2"))
		#expect(!master.contains("LIMIT 5"))
	}

	@Test func userOrderingComesBeforeTheTieBreak() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).order(by: \.name)
			.join(\.kids, on: \.id, equals: \.parentId).order(descending: \.id).first()
		let statements = recorded.statements
		try #require(statements.count == 2)
		#expect(statements[0].sql.contains("ORDER BY \"t0\".\"name\", \"t0\".\"id\"\nLIMIT 1"))
		#expect(statements[1].sql.contains("ORDER BY \"t1\".\"id\" DESC"))
		// Already ordered by the join key: no duplicate tie-break.
		_ = try db.table(BFParent.self).order(descending: \.id).join(\.kids, on: \.id, equals: \.parentId).first()
		#expect(recorded.statements[2].sql.contains("ORDER BY \"t0\".\"id\" DESC\nLIMIT 1"))
	}

	@Test func selectIsUnchanged() throws {
		let (db, recorded) = try db()
		_ = try db.table(BFParent.self).join(\.kids, on: \.id, equals: \.parentId).select().all()
		let statements = recorded.statements
		#expect(!statements[0].sql.contains("LIMIT"))
		#expect(!statements[0].sql.contains("ORDER BY"))
		#expect(statements[1].sql.contains("LEFT JOIN \"BFParent\" AS \"t0\""))
	}
}
