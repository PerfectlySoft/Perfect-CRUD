//
//  PerfectSwORMSelect.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

struct SelectIterator<A: SelectProtocol>: IteratorProtocol {
	typealias Element = A.OverAllForm
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
	mutating func next() -> Element? {
		guard let delegate = exeDelegate else {
			return nil
		}
		do {
			if try delegate.hasNext() {
				let rowDecoder: SwORMRowDecoder2<ColumnKey> = SwORMRowDecoder2(delegate: delegate)
				return try Element(from: rowDecoder)
			}
		} catch {
			SwORMLogging.log(.error, "Error thrown in SelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
}

struct Select<OAF: Codable, A: TableProtocol>: SelectProtocol {
	typealias Iterator = SelectIterator<Select<OAF, A>>
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let sqlGenState: SQLGenState
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
	func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			SwORMLogging.log(.error, "Error thrown in Select.makeIterator() Caught: \(error)")
		}
		return SelectIterator()
	}
}

struct Where<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, SelectAble {
	typealias Form = OAF
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let expression: Expression
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		state.whereExpr = expression
	}
	func setSQL(var state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
	}
}

// this is not an excellent check for Table<OAF, _>
extension Where where OverAllForm == FromTableType.Form {
	@discardableResult
	func update(_ instance: OAF, setKeys: PartialKeyPath<OAF>...) throws -> Update<OAF, Where<OAF,A>> {
		return try .init(fromTable: self, instance: instance, includeKeys: setKeys, excludeKeys: [])
	}
	@discardableResult
	func update(_ instance: OAF, ignoreKeys: PartialKeyPath<OAF>...) throws -> Update<OAF, Where<OAF,A>> {
		return try .init(fromTable: self, instance: instance, includeKeys: [], excludeKeys: ignoreKeys)
	}
	@discardableResult
	func delete() throws -> Delete<OAF, Where<OAF,A>> {
		return try .init(fromTable: self)
	}
}

struct Ordering<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, JoinAble, SelectAble, WhereAble, OrderAble {
	typealias Form = A.Form
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let keys: [PartialKeyPath<A.Form>]
	let descending: Bool
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	func setSQL(var state: inout SQLGenState) throws {
		state.accumulatedOrderings.append(contentsOf: keys.map { (key: $0, desc: descending) })
		try fromTable.setSQL(state: &state)
	}
}

struct Join<OAF: Codable, A: TableProtocol, B: Codable, O: Equatable>: TableProtocol, JoinProtocol, JoinAble, SelectAble, WhereAble, OrderAble {
	typealias Form = B
	typealias FromTableType = A
	typealias ComparisonType = O
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	let on: KeyPath<OverAllForm, ComparisonType>
	let equals: KeyPath<Form, ComparisonType>
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: .init(to: to, on: on, equals: equals))
	}
	func setSQL(var state: inout SQLGenState) throws {
		let orderings = state.consumeOrderings()
		try fromTable.setSQL(state: &state)
		
		let tableData = state.tableData
		let delegate = state.delegate
		guard let firstTable = tableData.first,
			let myTableIndex = tableData.index(where: { Form.self == $0.type }) else {
				throw SwORMSQLGenError("No tables specified.")
		}
		let joinTables = Array(tableData[1..<myTableIndex]) + Array(tableData[(myTableIndex+1)...])
		let myTable = tableData[myTableIndex]
		let nameQ = try delegate.quote(identifier: "\(Form.self)")
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		let fNameQ = try delegate.quote(identifier: "\(firstTable.type)")
		let fAliasQ = try delegate.quote(identifier: firstTable.alias)
		let lhsStr = try Expression.keyPath(on).sqlSnippet(state: state)
		let rhsStr = try Expression.keyPath(equals).sqlSnippet(state: state)
		switch state.command {
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
					let nameQ = try delegate.quote(identifier: "\(joinTable.type)")
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))"
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
