//
//  PerfectCRUDSelect.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public struct SelectIterator<A: SelectProtocol>: IteratorProtocol {
	public typealias Element = A.OverAllForm
	let select: A?
	let exeDelegate: SQLExeDelegate?
	init(select s: A) throws {
		select = s
		exeDelegate = try SQLTopExeDelegate(genState: s.sqlGenState, configurator: s.fromTable.databaseConfiguration)
	}
	init() {
		select = nil
		exeDelegate = nil
	}
	public mutating func next() -> Element? {
		guard let delegate = exeDelegate else {
			return nil
		}
		do {
			if try delegate.hasNext() {
				let rowDecoder: CRUDRowDecoder<ColumnKey> = CRUDRowDecoder(delegate: delegate)
				return try Element(from: rowDecoder)
			}
		} catch {
			CRUDLogging.log(.error, "Error thrown in SelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
}

public struct Select<OAF: Codable, A: TableProtocol>: SelectProtocol {
	public typealias Iterator = SelectIterator<Select>
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	public let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType) throws {
		fromTable = ft
		var state = SQLGenState(delegate: ft.databaseConfiguration.sqlGenDelegate)
		state.command = .select
		try ft.setState(state: &state)
		try ft.setSQL(state: &state)
		guard state.accumulatedOrderings.isEmpty else {
			throw CRUDSQLGenError("Orderings were not consumed: \(state.accumulatedOrderings)")
		}
		sqlGenState = state
	}
	public func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			CRUDLogging.log(.error, "Error thrown in Select.makeIterator() Caught: \(error)")
		}
		return SelectIterator()
	}
}

public struct Where<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, SelectAble {
	public typealias Form = OAF
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let expression: Expression
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		state.whereExpr = expression
	}
	public func setSQL(var state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
	}
}

// this is not an excellent check for Table<OAF, _>
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

public struct Ordering<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, JoinAble, SelectAble, WhereAble, OrderAble, LimitAble {
	public typealias Form = A.Form
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let keys: [PartialKeyPath<A.Form>]
	let descending: Bool
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	public func setSQL(var state: inout SQLGenState) throws {
		state.accumulatedOrderings.append(contentsOf: keys.map { (key: $0, desc: descending) })
		try fromTable.setSQL(state: &state)
	}
}

public struct Limit<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, JoinAble, SelectAble, WhereAble, OrderAble {
	public typealias Form = A.Form
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let max: Int
	let skip: Int
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	public func setSQL(var state: inout SQLGenState) throws {
		state.currentLimit = (max, skip)
		try fromTable.setSQL(state: &state)
	}
}

public struct Join<OAF: Codable, A: TableProtocol, B: Codable, O: Equatable>: TableProtocol, JoinProtocol, JoinAble, SelectAble, WhereAble, OrderAble, LimitAble {
	public typealias Form = B
	public typealias FromTableType = A
	public typealias ComparisonType = O
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	public let on: KeyPath<OverAllForm, ComparisonType>
	public let equals: KeyPath<Form, ComparisonType>
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: .init(to: to, on: on, equals: equals))
	}
	public func setSQL(var state: inout SQLGenState) throws {
		let (orderings, limit) = state.consumeState()
		try fromTable.setSQL(state: &state)
		
		let tableData = state.tableData
		let delegate = state.delegate
		guard let firstTable = tableData.first,
			let myTableIndex = tableData.index(where: { Form.self == $0.type }) else {
				throw CRUDSQLGenError("No tables specified.")
		}
		let joinTables = Array(tableData[1..<myTableIndex]) + Array(tableData[(myTableIndex+1)...])
		let myTable = tableData[myTableIndex]
		let nameQ = try delegate.quote(identifier: Form.CRUDTableName)
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		let fNameQ = try delegate.quote(identifier: firstTable.type.CRUDTableName)
		let fAliasQ = try delegate.quote(identifier: firstTable.alias)
		let lhsStr = try Expression.keyPath(on).sqlSnippet(state: state)
		let rhsStr = try Expression.keyPath(equals).sqlSnippet(state: state)
		switch state.command {
		case .count:
			() // joins do nothing on .count except limit master #
		case .select:
			var sqlStr =
			"""
			SELECT DISTINCT \(aliasQ).*
			FROM \(nameQ) AS \(aliasQ)
			JOIN \(fNameQ) AS \(fAliasQ) ON \(lhsStr) = \(rhsStr)
			
			"""
			if let whereExpr = state.whereExpr {
				let referencedTypes = whereExpr.referencedTypes()
				for type in referencedTypes {
					guard type != firstTable.type && type != Form.self else {
						continue
					}
					guard let joinTable = joinTables.first(where: { type == $0.type }) else {
						throw CRUDSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw CRUDSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: joinTable.type.CRUDTableName)
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))\n"
			}
			if let (max, skip) = limit {
				if max > 0 {
					sqlStr += "LIMIT \(max)\n"
				}
				if skip > 0 {
					sqlStr += "OFFSET \(skip)\n"
				}
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			CRUDLogging.log(.query, sqlStr)
		// ordering
		case .insert, .update, .delete:()
		//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw CRUDSQLGenError("SQL command was not set.")
		}
	}
}
