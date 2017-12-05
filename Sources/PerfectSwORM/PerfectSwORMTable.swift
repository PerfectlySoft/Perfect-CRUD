//
//  PerfectSwORMTable.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

struct Table<A: Codable, C: DatabaseProtocol>: TableProtocol, JoinAble, SelectAble, WhereAble, OrderAble, UpdateAble, DeleteAble {
	typealias OverAllForm = A
	typealias Form = A
	typealias DatabaseType = C
	var databaseConfiguration: DatabaseConfigurationProtocol { return database.configuration }
	let database: DatabaseType
	func setState(var state: inout SQLGenState) throws {
		try state.addTable(type: Form.self)
	}
	func setSQL(var state: inout SQLGenState) throws {
		let orderings = state.consumeOrderings()
		let tableData = state.tableData
		let delegate = state.delegate
		guard let myTable = tableData.first else {
			throw SwORMSQLGenError("No tables specified.")
		}
		let nameQ = try delegate.quote(identifier: "\(Form.swormTableName)")
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		switch state.command {
		case .select, .count:
			var sqlStr =
			"""
			SELECT DISTINCT \(aliasQ).*
			FROM \(nameQ) AS \(aliasQ)
			
			"""
			if let whereExpr = state.whereExpr {
				let joinTables = tableData[1...].map { $0 }
				let referencedTypes = whereExpr.referencedTypes()
				for type in referencedTypes {
					guard type != Form.self else {
						continue
					}
					guard let joinTable = joinTables.first(where: { type == $0.type }) else {
						throw SwORMSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw SwORMSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: "\(joinTable.type)")
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			if state.command == .count {
				sqlStr = "SELECT COUNT(*) AS count FROM (\(sqlStr)) AS s1"
			} else if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			SwORMLogging.log(.query, sqlStr)
		case .update:
			guard let encoder = state.bindingsEncoder else {
				throw SwORMSQLGenError("No bindings encoder for update.")
			}
			let columns = try encoder.columnNames.map { try delegate.quote(identifier: $0) }
			let binds = encoder.bindIdentifiers
			var sqlStr = "UPDATE \(nameQ)\nSET \(zip(columns, binds).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))\n"
			if let whereExpr = state.whereExpr {
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			SwORMLogging.log(.query, sqlStr)
		case .delete:
			var sqlStr = "DELETE FROM \(nameQ)\n"
			if let whereExpr = state.whereExpr {
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			SwORMLogging.log(.query, sqlStr)
		case .insert:()
		//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw SwORMSQLGenError("SQL command was not set.")
		}
	}
}










