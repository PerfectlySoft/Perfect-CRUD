//
//  PerfectSwORMInsert.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

extension Table {
	func insert(_ instances: [Form]) throws {
		guard !instances.isEmpty else {
			return
		}
		let delegate = databaseConfiguration.sqlGenDelegate
		let encoder = SwORMBindingsEncoder(delegate: delegate)
		try instances[0].encode(to: encoder)
		let columns = try encoder.columnNames.map { try delegate.quote(identifier: $0) }
		let binds = encoder.bindIdentifiers
		let nameQ = try delegate.quote(identifier: "\(Form.self)")
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
	func insert(_ instance: Form) throws {
		return try insert([instance])
	}
}
