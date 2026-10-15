//
//  PerfectCRUDTable.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public struct Table<A: Codable, C: DatabaseProtocol>: TableProtocol, Joinable, Selectable, Whereable, Orderable, Updatable, Deleteable, Limitable {
	public typealias OverAllForm = A
	public typealias Form = A
	public typealias DatabaseType = C
	public var databaseConfiguration: DatabaseConfigurationProtocol { return database.configuration }
	let database: DatabaseType
	public func setState(state: inout SQLGenState) throws {
		try state.addTable(type: Form.self)
	}
	public func setSQL(state: inout SQLGenState) throws {
		let (consumedOrderings, consumedLimit) = state.consumeState()
		var orderings = consumedOrderings
		var limit = consumedLimit
		if state.command == .select, state.firstRowOnly, state.statements.isEmpty {
			limit = (1, limit?.skip ?? 0)
			// Each joined statement repeats this statement as a derived table, so both must pick the
			// same row: break ties on the join keys (rows with equal keys get the same joined objects).
			for on in state.tableData.compactMap({ $0.joinData?.on }) where !orderings.contains(where: { $0.key == on }) {
				orderings.append((key: on, desc: false))
			}
		}
		let delegate = state.delegate
		let nameQ = try delegate.quote(identifier: "\(Form.CRUDTableName)")
		switch state.command {
		case .select, .count:
			guard let poppedTableData = state.popTableData() else {
				throw CRUDSQLGenError("No tables specified.")
			}
			let myTable = poppedTableData.myTable
			let aliasQ = try delegate.quote(identifier: myTable.alias)
			var sqlStr =
			"""
			SELECT DISTINCT \(aliasQ).*
			FROM \(nameQ) AS \(aliasQ)
			"""
			if let whereExpr = state.whereExpr {
				for join in try state.whereClauseJoins(for: whereExpr, present: [myTable.alias]) {
					sqlStr += "\n\(join)"
				}
				sqlStr += "\nWHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			var limitStr = ""
			if let (max, skip) = limit {
				if max > 0 {
					limitStr += "\nLIMIT \(max)"
				}
				if skip > 0 {
					limitStr += "\nOFFSET \(skip)"
				}
			}
			if state.command == .count {
				sqlStr = "SELECT COUNT(*) AS count FROM (\(sqlStr + limitStr)) AS s1"
			} else if !orderings.isEmpty {
				let m = try orderings.map { try state.orderingSnippet($0, statementTable: myTable) }
				sqlStr += "\nORDER BY \(m.joined(separator: ", "))" + limitStr
			} else {
				sqlStr += limitStr
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

			var sqlStr = "UPDATE \(nameQ)\nSET \(zip(columnNames, bindIdentifiers).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))"
			if let whereExpr = state.whereExpr {
				sqlStr += "\nWHERE \(try whereExpr.sqlSnippet(state: state))"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			CRUDLogging.log(.query, sqlStr)
		case .delete:
			var sqlStr = "DELETE FROM \(nameQ)"
			if let whereExpr = state.whereExpr {
				sqlStr += "\nWHERE \(try whereExpr.sqlSnippet(state: state))"
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

// Only stored property is `database: C` -- Sendable whenever C is (needed to
// cross the actor boundary in AsyncExecution.swift's async query methods).
extension Table: Sendable where C: Sendable {}
