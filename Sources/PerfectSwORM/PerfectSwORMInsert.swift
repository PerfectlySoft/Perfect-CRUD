//
//  PerfectSwORMInsert.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

struct Insert<OAF: Codable, A: TableProtocol>: FromTableProtocol, CommandProtocol {
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType,
		 instances: [OAF]) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		var state = SQLGenState(delegate: delegate)
		state.command = .insert
		sqlGenState = state
		guard !instances.isEmpty else {
			return
		}
		let encoder = SwORMBindingsEncoder(delegate: delegate)
		try instances[0].encode(to: encoder)
		let columns = try encoder.columnNames.map { try delegate.quote(identifier: $0) }
		let binds = encoder.bindIdentifiers
		let nameQ = try delegate.quote(identifier: "\(OAF.self)")
		let sqlStr = "INSERT INTO \(nameQ) (\(columns.joined(separator: ", "))) VALUES (\(binds.joined(separator: ", ")))"
		SwORMLogging.log(.query, sqlStr)
		let exeDelegate = try databaseConfiguration.sqlExeDelegate(forSQL: sqlStr)
		try exeDelegate.bind(delegate.bindings)
		_ = try exeDelegate.hasNext()
		for instance in instances[1...] {
			let delegate = databaseConfiguration.sqlGenDelegate
			let encoder = SwORMBindingsEncoder(delegate: delegate)
			try instance.encode(to: encoder)
			try exeDelegate.bind(delegate.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
}

extension Table {
	func insert(_ instances: [Form]) throws -> Insert<Form, Table<A,C>> {
		return try .init(fromTable: self, instances: instances)
	}
	func insert(_ instance: Form) throws -> Insert<Form, Table<A,C>> {
		return try insert([instance])
	}
}
