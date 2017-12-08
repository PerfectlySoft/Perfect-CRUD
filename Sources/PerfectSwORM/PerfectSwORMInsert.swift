//
//  PerfectSwORMInsert.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public struct InsertPolicy: OptionSet {
	public let rawValue: Int
	public init(rawValue r: Int) { rawValue = r }
	
	public static let defaultPolicy: InsertPolicy = []
}

public struct Insert<OAF: Codable, A: TableProtocol>: FromTableProtocol, CommandProtocol {
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	public let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType,
		 instances: [OAF],
		 policy: InsertPolicy) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		var state = SQLGenState(delegate: delegate)
		state.command = .insert
		sqlGenState = state
		guard !instances.isEmpty else {
			return
		}
		
		let columnDecoder = SwORMColumnNameDecoder()
		_ = try type(of: instances[0]).init(from: columnDecoder)
		// all the column names that will be included in the insert
		let allKeys = columnDecoder.collectedKeys.map { $0.name }
		
		let encoder = try SwORMBindingsEncoder(delegate: delegate)
		try instances[0].encode(to: encoder)
		
		let bindings = try encoder.completedBindings(allKeys: allKeys, ignoreKeys: Set())
		let columns = try bindings.map { try delegate.quote(identifier: $0.column) }
		let identifiers = bindings.map { $0.identifier }
		
		let nameQ = try delegate.quote(identifier: "\(OAF.swormTableName)")
		let sqlStr = "INSERT INTO \(nameQ) (\(columns.joined(separator: ", "))) VALUES (\(identifiers.joined(separator: ", ")))"
		SwORMLogging.log(.query, sqlStr)
		
		let exeDelegate = try databaseConfiguration.sqlExeDelegate(forSQL: sqlStr)
		try exeDelegate.bind(delegate.bindings)
		_ = try exeDelegate.hasNext()
		
		for instance in instances[1...] {
			let delegate = databaseConfiguration.sqlGenDelegate
			let encoder = try SwORMBindingsEncoder(delegate: delegate)
			try instance.encode(to: encoder)
			_ = try encoder.completedBindings(allKeys: allKeys, ignoreKeys: Set())
			try exeDelegate.bind(delegate.bindings)
			_ = try exeDelegate.hasNext()
		}
	}
}

public extension Table {
	@discardableResult
	func insert(_ instances: [Form], policy: InsertPolicy = .defaultPolicy) throws -> Insert<Form, Table<A,C>> {
		return try .init(fromTable: self, instances: instances, policy: policy)
	}
	@discardableResult
	func insert(_ instance: Form, policy: InsertPolicy = .defaultPolicy) throws -> Insert<Form, Table<A,C>> {
		return try insert([instance], policy: policy)
	}
}
