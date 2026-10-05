import Testing
import Foundation
@testable import PerfectCRUD

// MARK: - Where clauses that reference a joined type
//
// A where clause runs in every statement of a select, so each statement LEFT JOINs the joined
// tables the clause references and doesn't already include. For a pivot-joined type that join
// used the pivot join's `on`/`equals` (master = pivot table) as if they were the joined type's
// own, without joining the pivot table, so the SQL named an alias it never defined. A where
// clause on the pivot type itself threw "Join without a clause", since the pivot table has no
// join data. The master statement also used the type's name instead of `CRUDTableName`.

private enum WhereJoinScope {
	struct Parent: Codable {
		let id: Int
		let tags: [Tag]?
		let kids: [Kid]?
	}
	struct Tag: Codable {
		let id: Int
		let name: String
	}
	struct ParentTag: Codable {
		let parentId: Int
		let tagId: Int
	}
	struct Kid: Codable, TableNameProvider {
		static let tableName = "kids"
		let id: Int
		let parentId: Int
	}
	// Two joins of one type, and the pivot type also joined directly.
	struct Family: Codable {
		let id: Int
		let kids: [Kid]?
		let kids2: [Kid]?
		let links: [ParentTag]?
		let tags: [Tag]?
	}
}

// Records each statement's SQL and returns no rows.
private final class SQLRecordingConfig: DatabaseConfigurationProtocol, @unchecked Sendable {
	private let lock = NSLock()
	private var _sqls: [String] = []
	var sqls: [String] { lock.withLock { _sqls } }
	var sqlGenDelegate: SQLGenDelegate { StatefulStubGenDelegate() }
	func sqlExeDelegate(forSQL sql: String) throws -> SQLExeDelegate {
		lock.withLock { _sqls.append(sql) }
		return StatefulStubExeDelegate(store: StatefulRowStore(), sql: "")
	}
	required init(url: String? = nil, name: String? = nil, host: String? = nil,
				  port: Int? = nil, user: String? = nil, pass: String? = nil) throws {}
}

@Suite("Where clauses that reference a joined type")
struct WhereClauseJoinTests {
	fileprivate typealias Parent = WhereJoinScope.Parent
	fileprivate typealias Tag = WhereJoinScope.Tag
	fileprivate typealias ParentTag = WhereJoinScope.ParentTag
	fileprivate typealias Kid = WhereJoinScope.Kid
	fileprivate typealias Family = WhereJoinScope.Family

	private func table() throws -> Table<Parent, Database<StatefulStubConfig>> {
		Database(configuration: try StatefulStubConfig()).table(Parent.self)
	}

	/// The statements' SQL, after checking that each one defines every alias before using it.
	private func statements<S: SelectProtocol>(_ select: S) -> [String] {
		let sqls = select.sqlGenState.statements.map(\.sql)
		for sql in sqls {
			Self.checkAliases(in: sql)
		}
		return sqls
	}

	/// From the first table on, every `"tN".` must follow an `AS "tN"`: an ON clause can only name tables
	/// already in scope, which real databases enforce (SQLite: "ON clause references tables to
	/// its right").
	private static func checkAliases(in sql: String, sourceLocation: SourceLocation = #_sourceLocation) {
		guard let from = sql.range(of: "FROM \"") else {
			Issue.record("No FROM in:\n\(sql)", sourceLocation: sourceLocation)
			return
		}
		let body = String(sql[from.lowerBound...])
		let regex = try! NSRegularExpression(pattern: #"AS "(t\d+)"|"(t\d+)"\."#)
		var defined: Set<String> = []
		for match in regex.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
			if let range = Range(match.range(at: 1), in: body) {
				defined.insert(String(body[range]))
			} else if let range = Range(match.range(at: 2), in: body), !defined.contains(String(body[range])) {
				Issue.record("\(body[range]) is used before it is defined in:\n\(sql)", sourceLocation: sourceLocation)
			}
		}
	}

	// Aliases: t0 Parent, t1 Tag, t2 ParentTag, t3 Kid.
	private let pivotJoin = #"LEFT JOIN "ParentTag" AS "t2" ON "t0"."id" = "t2"."parentId""#
	private let tagJoin = #"LEFT JOIN "Tag" AS "t1" ON "t1"."id" = "t2"."tagId""#

	@Test("a where on a pivot-joined type joins the pivot table first, in every statement")
	func whereOnPivotJoinedType() throws {
		let select = try table()
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.where(\Tag.name == "a")
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 3)
		for sql in [sqls[0], sqls[2]] {
			let pivot = try #require(sql.range(of: pivotJoin), "SQL was:\n\(sql)")
			let tag = try #require(sql.range(of: tagJoin), "SQL was:\n\(sql)")
			#expect(pivot.upperBound <= tag.lowerBound, "SQL was:\n\(sql)")
		}
		// The pivot statement already has both tables.
		#expect(!sqls[1].contains("LEFT JOIN \"Tag\""), "SQL was:\n\(sqls[1])")
	}

	@Test("a where on a pivot-joined type, with no other join")
	func whereOnPivotJoinedTypeAlone() throws {
		let select = try table()
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.where(\Tag.name == "a")
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 2)
		#expect(sqls[0].contains(pivotJoin) && sqls[0].contains(tagJoin), "SQL was:\n\(sqls[0])")
	}

	@Test("a where on the pivot type joins only the pivot table")
	func whereOnPivotType() throws {
		let select = try table()
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.where(\ParentTag.tagId == 10)
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 3)
		for sql in [sqls[0], sqls[2]] {
			#expect(sql.contains(pivotJoin), "SQL was:\n\(sql)")
			#expect(!sql.contains("LEFT JOIN \"Tag\""), "SQL was:\n\(sql)")
		}
	}

	@Test("a where on both the pivot-joined type and the pivot type joins the pivot table once")
	func whereOnBoth() throws {
		let select = try table()
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.where(\Tag.name == "a" && \ParentTag.tagId == 10)
			.select()
		for sql in statements(select) {
			#expect(sql.components(separatedBy: "\"ParentTag\" AS").count == 2, "SQL was:\n\(sql)")
		}
	}

	@Test("a where on a plain-joined type uses its table name, in the master and pivot statements")
	func whereOnPlainJoinedType() throws {
		let select = try table()
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.where(\Kid.id == 20)
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 3)
		// Aliases here: t0 Parent, t1 Kid, t2 Tag, t3 ParentTag.
		let kidJoin = #"LEFT JOIN "kids" AS "t1" ON "t0"."id" = "t1"."parentId""#
		#expect(sqls[0].contains(kidJoin), "SQL was:\n\(sqls[0])")
		#expect(sqls[2].contains(kidJoin), "SQL was:\n\(sqls[2])")
	}

	@Test("count() with a where on a pivot-joined type")
	func countWithWhereOnPivotJoinedType() throws {
		let config = try SQLRecordingConfig()
		let query = try Database(configuration: config).table(Parent.self)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.join(\.kids, on: \.id, equals: \.parentId)
			.where(\Tag.name == "a")
		// The recording config returns no rows, so count() throws after running its SQL.
		_ = try? query.count()
		let sql = try #require(config.sqls.first)
		#expect(config.sqls.count == 1)
		Self.checkAliases(in: sql)
		#expect(sql.hasPrefix("SELECT COUNT(*)") && sql.contains(pivotJoin) && sql.contains(tagJoin), "SQL was:\n\(sql)")
	}

	@Test("a where on a type joined twice joins its first table in the second join's statement")
	func whereOnTypeJoinedTwice() throws {
		let select = try Database(configuration: try StatefulStubConfig()).table(Family.self)
			.join(\.kids, on: \.id, equals: \.parentId)
			.join(\.kids2, on: \.id, equals: \.parentId)
			.where(\Kid.id == 20)
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 3)
		// t1 is kids, t2 kids2; the where resolves to t1.
		#expect(sqls[2].contains(#"LEFT JOIN "kids" AS "t1" ON "t0"."id" = "t1"."parentId""#), "SQL was:\n\(sqls[2])")
	}

	@Test("a pivot-joined type is joined through its own pivot table, not another table of that type")
	func pivotTypeAlsoJoinedDirectly() throws {
		let select = try Database(configuration: try StatefulStubConfig()).table(Family.self)
			.join(\.links, on: \.id, equals: \.parentId)
			.join(\.tags, with: ParentTag.self, on: \.id, equals: \.parentId, and: \.id, is: \.tagId)
			.where(\Tag.name == "a")
			.select()
		let sqls = statements(select)
		#expect(sqls.count == 3)
		// t1 is links (ParentTag), t2 Tag, t3 the pivot ParentTag. Main joined Tag on t1, the
		// directly joined ParentTag, and returned the wrong rows.
		let tagJoin = #"LEFT JOIN "Tag" AS "t2" ON "t2"."id" = "t3"."tagId""#
		let pivotJoin = #"LEFT JOIN "ParentTag" AS "t3" ON "t0"."id" = "t3"."parentId""#
		for sql in [sqls[0], sqls[1]] {
			#expect(sql.contains(pivotJoin) && sql.contains(tagJoin), "SQL was:\n\(sql)")
		}
	}
}
