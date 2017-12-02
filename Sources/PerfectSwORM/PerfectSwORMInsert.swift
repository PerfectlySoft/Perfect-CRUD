//
//  PerfectSwORMInsert.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

extension DatabaseProtocol {
	func insert<A: Codable>(_ instances: [A]) throws {
		guard !instances.isEmpty else {
			return
		}
		let delegate = configuration.sqlGenDelegate
		let encoder = SwORMBindingsEncoder(delegate: delegate)
		try instances[0].encode(to: encoder)
		let nameQ = try delegate.quote(identifier: "\(A.self)")
		let columns = try encoder.columnNames.map { try delegate.quote(identifier: $0) }
		let binds = encoder.bindIdentifiers
		let sqlStr = "INSERT INTO \(nameQ) (\(columns.joined(separator: ", "))) VALUES (\(binds.joined(separator: ", ")))"
		SwORMLogging.log(.query, sqlStr)
		let exeDelegate = try configuration.sqlExeDelegate(forSQL: sqlStr)
		try exeDelegate.bind(delegate.bindings)
		_ = try exeDelegate.hasNext()
		for instance in instances[1...] {
			let delegate = configuration.sqlGenDelegate
			let encoder = SwORMBindingsEncoder(delegate: delegate)
			try instance.encode(to: encoder)
			try exeDelegate.bind(delegate.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
	func insert<A: Codable>(_ instance: A) throws {
		return try insert([instance])
	}
}
