//
//  PerfectSwORMSelect.swift
//  PerfectSwORM
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
				let rowDecoder: SwORMRowDecoder<ColumnKey> = SwORMRowDecoder(delegate: delegate)
				return try Element(from: rowDecoder)
			}
		} catch {
			SwORMLogging.log(.error, "Error thrown in SelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
}

public struct Select<OAF: Codable, A: TableProtocol>: SelectProtocol {
	public typealias Iterator = SelectIterator<Select<OAF, A>>
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
			throw SwORMSQLGenError("Orderings were not consumed: \(state.accumulatedOrderings)")
		}
		sqlGenState = state
	}
	public func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			SwORMLogging.log(.error, "Error thrown in Select.makeIterator() Caught: \(error)")
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
	@discardableResult
	func update(_ instance: OverAllForm, setKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OAF, Where<OAF,A>> {
		return try .init(fromTable: self, instance: instance, includeKeys: [setKeys] + rest, excludeKeys: [])
	}
	@discardableResult
	func update(_ instance: OverAllForm, ignoreKeys: PartialKeyPath<OverAllForm>, _ rest: PartialKeyPath<OverAllForm>...) throws -> Update<OAF, Where<OAF,A>> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [ignoreKeys] + rest)
	}
	@discardableResult
	func update(_ instance: OverAllForm) throws -> Update<OAF, Where<OAF,A>> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: [])
	}
	@discardableResult
	func delete() throws -> Delete<OAF, Where<OAF,A>> {
		return try .init(fromTable: self)
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
				throw SwORMSQLGenError("No tables specified.")
		}
		let joinTables = Array(tableData[1..<myTableIndex]) + Array(tableData[(myTableIndex+1)...])
		let myTable = tableData[myTableIndex]
		let nameQ = try delegate.quote(identifier: Form.swormTableName)
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		let fNameQ = try delegate.quote(identifier: firstTable.type.swormTableName)
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
						throw SwORMSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw SwORMSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: joinTable.type.swormTableName)
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
			SwORMLogging.log(.query, sqlStr)
		// ordering
		case .insert, .update, .delete:()
		//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw SwORMSQLGenError("SQL command was not set.")
		}
	}
}
