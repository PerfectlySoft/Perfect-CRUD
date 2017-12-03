//
//  PerfectSwORMDelete.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-03.
//

import Foundation

protocol DeleteAble: TableProtocol {
	@discardableResult
	func delete() throws -> Delete<OverAllForm, Self>
}

extension DeleteAble {
	@discardableResult
	func delete() throws -> Delete<OverAllForm, Self> {
		return try .init(fromTable: self)
	}
}

struct Delete<OAF: Codable, A: TableProtocol>: FromTableProtocol, CommandProtocol {
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		var state = SQLGenState(delegate: delegate)
		state.command = .delete
		try ft.setState(state: &state)
		try ft.setSQL(state: &state)
		guard state.accumulatedOrderings.isEmpty else {
			throw SwORMSQLGenError("Orderings were not consumed: \(state.accumulatedOrderings)")
		}
		sqlGenState = state
		for stat in state.statements {
			let exeDelegate = try databaseConfiguration.sqlExeDelegate(forSQL: stat.sql)
			try exeDelegate.bind(stat.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
}
