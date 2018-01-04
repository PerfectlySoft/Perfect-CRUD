//
//  PerfectCRUDJoin.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2018-01-03.
//

import Foundation

let joinPivotIdColumnName = "_crud_pivot_id_"

public struct Join<OAF: Codable, A: TableProtocol, B: Codable, O: Equatable>: TableProtocol, FromTableProtocol, Joinable, Selectable, Whereable, Orderable, Limitable {
	public typealias Form = B
	public typealias FromTableType = A
	public typealias ComparisonType = O
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	let on: KeyPath<OverAllForm, ComparisonType>
	let equals: KeyPath<Form, ComparisonType>
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: .init(to: to, on: on, equals: equals, pivot: nil))
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

public struct JoinPivot<OAF: Codable, MasterTable: TableProtocol, MyForm: Codable, With: Codable, PivotCompType: Equatable, PivotCompType2: Equatable>: TableProtocol, FromTableProtocol, Joinable, Selectable, Whereable, Orderable, Limitable {
	public typealias Form = MyForm
	public typealias FromTableType = MasterTable
	public typealias PivotTableType = With
	public typealias ComparisonType = PivotCompType
	public typealias ComparisonType2 = PivotCompType2
	public typealias OverAllForm = OAF
	
	public let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	let on: KeyPath<OverAllForm, ComparisonType>
	let equals: KeyPath<PivotTableType, ComparisonType>
	let and: KeyPath<Form, ComparisonType2>
	let alsoEquals: KeyPath<PivotTableType, ComparisonType2>
	
	public func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: .init(to: to, on: on, equals: equals, pivot: PivotTableType.self))
		try state.addTable(type: PivotTableType.self)
	}
	public func setSQL(var state: inout SQLGenState) throws {
		let (orderings, limit) = state.consumeState()
		try fromTable.setSQL(state: &state)
		
		let tableData = state.tableData
		let delegate = state.delegate
		guard let firstTable = tableData.first,
			let myTableIndex = tableData.index(where: { Form.self == $0.type }),
			let pivotTableIndex = tableData.index(where: { PivotTableType.self == $0.type }) else {
				throw CRUDSQLGenError("No tables specified.")
		}
		let joinTables = Array(tableData[1..<myTableIndex]) + Array(tableData[(myTableIndex+1)...])
		let myTable = tableData[myTableIndex]
		let pivotTable = tableData[pivotTableIndex]
		
		let myNameQ = try delegate.quote(identifier: myTable.type.CRUDTableName)
		let myAliasQ = try delegate.quote(identifier: myTable.alias)
		
		let firstNameQ = try delegate.quote(identifier: firstTable.type.CRUDTableName)
		let firstAliasQ = try delegate.quote(identifier: firstTable.alias)
		
		let lhsStr = try Expression.keyPath(on).sqlSnippet(state: state)
		let rhsStr = try Expression.keyPath(equals).sqlSnippet(state: state)
		
		let pivotNameQ = try delegate.quote(identifier: pivotTable.type.CRUDTableName)
		let pivotAliasQ = try delegate.quote(identifier: pivotTable.alias)
		
		let lhsStr2 = try Expression.keyPath(and).sqlSnippet(state: state)
		let rhsStr2 = try Expression.keyPath(alsoEquals).sqlSnippet(state: state)
		
		let tempColumnNameQ = try delegate.quote(identifier: joinPivotIdColumnName)
		
		switch state.command {
		case .count:
			() // joins do nothing on .count except limit master #
		case .select:
			var sqlStr =
			"""
			SELECT DISTINCT \(myAliasQ).*, \(lhsStr) AS \(tempColumnNameQ)
			FROM \(myNameQ) AS \(myAliasQ)
			JOIN \(pivotNameQ) AS \(pivotAliasQ) ON \(lhsStr2) = \(rhsStr2)
			JOIN \(firstNameQ) AS \(firstAliasQ) ON \(lhsStr) = \(rhsStr)
			
			"""
			if let whereExpr = state.whereExpr {
				let referencedTypes = whereExpr.referencedTypes()
				for type in referencedTypes {
					guard type != firstTable.type,
							type != Form.self,
							type != PivotTableType.self else {
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
