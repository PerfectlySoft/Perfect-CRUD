//
//  PerfectSwORMUpdate.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public protocol UpdateAble: TableProtocol {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OverAllForm, Self>
}

public extension UpdateAble {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys] + rest, excludeKeys: [])
	}
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys] + rest)
	}
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [])
	}
}

public struct Update<OAF: Codable, A: TableProtocol>: FromTableProtocol, CommandProtocol {
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	public let sqlGenState: SQLGenState
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
		let includeNames: [String]
		if includeKeys.isEmpty {
			let columnDecoder = SwORMColumnNameDecoder()
			_ = try OverAllForm.init(from: columnDecoder)
			includeNames = columnDecoder.collectedKeys.map { $0.name }
		} else {
			includeNames = try includeKeys.map {
				guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
					throw SwORMSQLGenError("Could not get key path name for \(OAF.self) \($0)")
				}
				return n
			}
		}
		let excludeNames: [String] = try excludeKeys.map {
			guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
				throw SwORMSQLGenError("Could not get key path name for \(OAF.self) \($0)")
			}
			return n
		}
		let encoder = try SwORMBindingsEncoder(delegate: delegate)
		try instance.encode(to: encoder)
		state.bindingsEncoder = encoder
		state.columnFilters = (include: includeNames, exclude: excludeNames)
		try ft.setSQL(state: &state)
		sqlGenState = state
		if let stat = state.statements.first { // multi statements?!
			let exeDelegate = try databaseConfiguration.sqlExeDelegate(forSQL: stat.sql)
			try exeDelegate.bind(stat.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
}
