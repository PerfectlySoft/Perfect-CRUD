//
//  PerfectSwORMUpdate.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

protocol UpdateAble: TableProtocol {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
}

extension UpdateAble {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: setKeys, excludeKeys: [])
	}
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: ignoreKeys)
	}
}

struct Update<OAF: Codable, A: TableProtocol>: FromTableProtocol, CommandProtocol {
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType,
		 instance: OAF,
		 includeKeys: [PartialKeyPath<OAF>],
		 excludeKeys: [PartialKeyPath<OAF>]) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		var state = SQLGenState(delegate: delegate)
		state.command = .update
		try ft.setState(state: &state)
		let td = state.tableData[0]
		let kpDecoder = td.keyPathDecoder
		guard let kpInstance = td.modelInstance else {
			throw SwORMSQLGenError("Could not get model instance for key path decoder \(OAF.self)")
		}
		let includeNames: [String] = try includeKeys.map {
			guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
				throw SwORMSQLGenError("Could not get key path name for \(OAF.self) \($0)")
			}
			return n
		}
		let excludeNames: [String] = try excludeKeys.map {
			guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
				throw SwORMSQLGenError("Could not get key path name for \(OAF.self) \($0)")
			}
			return n
		}
		let encoder = SwORMBindingsEncoder(delegate: delegate, ignoreKeys: Set(excludeNames), includeKeys: Set(includeNames))
		try instance.encode(to: encoder)
		state.bindingsEncoder = encoder
		try ft.setSQL(state: &state)
		sqlGenState = state
		for stat in state.statements {
			let exeDelegate = try databaseConfiguration.sqlExeDelegate(forSQL: stat.sql)
			try exeDelegate.bind(stat.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
}
