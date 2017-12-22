//
//  PerfectCRUDTable.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public struct Table<A: Codable, C: DatabaseProtocol>: TableProtocol, JoinAble, SelectAble, WhereAble, OrderAble, UpdateAble, DeleteAble, LimitAble {
	public typealias OverAllForm = A
	public typealias Form = A
	public typealias DatabaseType = C
	public var databaseConfiguration: DatabaseConfigurationProtocol { return database.configuration }
	let database: DatabaseType
	public func setState(var state: inout SQLGenState) throws {
		try state.addTable(type: Form.self)
	}
	public func setSQL(var state: inout SQLGenState) throws {
		let (orderings, limit) = state.consumeState()
		let tableData = state.tableData
		let delegate = state.delegate
		guard let myTable = tableData.first else {
			throw CRUDSQLGenError("No tables specified.")
		}
		let nameQ = try delegate.quote(identifier: "\(Form.CRUDTableName)")
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
						throw CRUDSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw CRUDSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: "\(joinTable.type)")
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			if let (max, skip) = limit {
				if max > 0 {
					sqlStr += "LIMIT \(max)\n"
				}
				if skip > 0 {
					sqlStr += "OFFSET \(skip)\n"
				}
			}
			if state.command == .count {
				sqlStr = "SELECT COUNT(*) AS count FROM (\(sqlStr)) AS s1"
			} else if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))\n"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			CRUDLogging.log(.query, sqlStr)
		case .update:
			guard let encoder = state.bindingsEncoder else {
				throw CRUDSQLGenError("No bindings encoder for update.")
			}
			let (allKeys, ignoreKeys) = state.columnFilters
			let bindings = try encoder.completedBindings(allKeys: allKeys, ignoreKeys: Set(ignoreKeys))
			let columnNames = try bindings.map { try delegate.quote(identifier: $0.column) }
			let bindIdentifiers = bindings.map { $0.identifier }
			
			var sqlStr = "UPDATE \(nameQ)\nSET \(zip(columnNames, bindIdentifiers).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))\n"
			if let whereExpr = state.whereExpr {
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			CRUDLogging.log(.query, sqlStr)
		case .delete:
			var sqlStr = "DELETE FROM \(nameQ)\n"
			if let whereExpr = state.whereExpr {
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			CRUDLogging.log(.query, sqlStr)
		case .insert:()
		//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw CRUDSQLGenError("SQL command was not set.")
		}
	}
}










