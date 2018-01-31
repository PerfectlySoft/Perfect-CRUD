//
//  PerfectCRUDUpdate.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public protocol Updatable: TableProtocol {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self>
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OverAllForm, Self>
}

public extension Updatable {
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: setKeys, excludeKeys: [])
	}
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: ignoreKeys)
	}
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [])
	}
	// !FIX! Swift 4.0.2 seems to have a problem with type inference for the above funcs
	// would not let \.name type references to be used
	// this is an ugly work around
	@discardableResult
	func update<V1>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3, V4>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3, key4], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3, V4, V5>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3, key4, key5], excludeKeys: [])
	}
	//--
	@discardableResult
	func update<V1>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys])
	}
	@discardableResult
	func update<V1, V2>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2])
	}
	@discardableResult
	func update<V1, V2, V3>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3])
	}
	@discardableResult
	func update<V1, V2, V3, V4>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3, key4])
	}
	@discardableResult
	func update<V1, V2, V3, V4, V5>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Update<OverAllForm, Self> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3, key4, key5])
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
			throw CRUDSQLGenError("Could not get model instance for key path decoder \(OAF.self)")
		}
		let includeNames: [String]
		if includeKeys.isEmpty {
			let columnDecoder = CRUDColumnNameDecoder()
			_ = try OverAllForm.init(from: columnDecoder)
			includeNames = columnDecoder.collectedKeys.map { $0.name }
		} else {
			includeNames = try includeKeys.map {
				guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
					throw CRUDSQLGenError("Could not get key path name for \(OAF.self) \($0)")
				}
				return n
			}
		}
		let excludeNames: [String] = try excludeKeys.map {
			guard let n = try kpDecoder.getKeyPathName(kpInstance, keyPath: $0) else {
				throw CRUDSQLGenError("Could not get key path name for \(OAF.self) \($0)")
			}
			return n
		}
		let encoder = try CRUDBindingsEncoder(delegate: delegate)
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
