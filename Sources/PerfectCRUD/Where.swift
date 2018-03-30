//
//  PerfectCRUDWhere.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2018-01-03.
//

import Foundation


public struct Where<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, Selectable {
	public typealias Form = OAF
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let expression: Expression
	public func setState(state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		state.whereExpr = expression
	}
	public func setSQL(state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
	}
}

public extension Where where OverAllForm == FromTableType.Form {
	//	@discardableResult
	//	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OAF, Where> {
	//		return try .init(fromTable: self, instance: instance, includeKeys: setKeys, excludeKeys: [])
	//	}
	//	@discardableResult
	//	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>...) throws -> Update<OAF, Where> {
	//		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: ignoreKeys)
	//	}
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [])
	}
	@discardableResult
	func delete() throws -> Delete<OverAllForm, Where> {
		return try .init(fromTable: self)
	}
	
	// !FIX! Swift 4.0.2 seems to have a problem with type inference for the above funcs
	// would not let \.name type references to be used
	// this is an ugly work around
	@discardableResult
	func update<V1>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3, V4>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3, key4], excludeKeys: [])
	}
	@discardableResult
	func update<V1, V2, V3, V4, V5>(_ instance: OverAllForm, setKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys, key2, key3, key4, key5], excludeKeys: [])
	}
	//--
	@discardableResult
	func update<V1>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys])
	}
	@discardableResult
	func update<V1, V2>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2])
	}
	@discardableResult
	func update<V1, V2, V3>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3])
	}
	@discardableResult
	func update<V1, V2, V3, V4>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3, key4])
	}
	@discardableResult
	func update<V1, V2, V3, V4, V5>(_ instance: OverAllForm, ignoreKeys: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Update<OverAllForm, Where> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys, key2, key3, key4, key5])
	}
}
