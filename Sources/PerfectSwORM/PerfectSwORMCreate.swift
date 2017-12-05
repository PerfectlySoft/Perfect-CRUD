//
//  PerfectSwORMCreate.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-03.
//

import Foundation

struct TableCreatePolicy: OptionSet {
	let rawValue: Int
	static let shallow = TableCreatePolicy(rawValue: 1)
	static let dropTable = TableCreatePolicy(rawValue: 2)
	
	static let defaultPolicy: TableCreatePolicy = []
}

struct TableStructure {
	struct Column {
		struct Property: OptionSet {
			let rawValue: Int
			static let primaryKey = Property(rawValue: 1)
		}
		let name: String
		let type: Any.Type
		let properties: Property
	}
	let tableName: String
	let primaryKeyName: String
	let columns: [Column]
	let subTables: [TableStructure]
	let indexes: [String]
}

extension Decodable {
	static func swormTableStructure(policy: TableCreatePolicy, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let columnDecoder = SwORMColumnNameDecoder()
		columnDecoder.tableNamePath.append("\(Self.swormTableName)")
		_ = try Self.init(from: columnDecoder)
		return try swormTableStructure(policy: policy, columnDecoder: columnDecoder, primaryKey: primaryKey)
	}
	
	static func swormTableStructure(policy: TableCreatePolicy, columnDecoder: SwORMColumnNameDecoder, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let primaryKeyName: String
		if let pkpk = primaryKey {
			let pathDecoder = SwORMKeyPathsDecoder()
			let pathInstance = try Self.init(from: pathDecoder)
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: pkpk) else {
				throw SwORMSQLGenError("Could not get column name for primary key \(Self.self).")
			}
			primaryKeyName = pkn
		} else {
			primaryKeyName = "id"
		}
		guard columnDecoder.collectedKeys.map({$0.0}).contains(primaryKeyName) else {
			throw SwORMSQLGenError("Primary key was not found in type \(Self.self) \(primaryKeyName).")
		}
		let subTables: [TableStructure]
		if !policy.contains(.shallow) {
			subTables = try columnDecoder.subTables.map {
				try swormTableStructure(policy: policy, columnDecoder: $0.2)
			}
		} else {
			subTables = []
		}
		let tableStruct = TableStructure(
			tableName: columnDecoder.tableNamePath.last!,
			primaryKeyName: primaryKeyName,
			columns: columnDecoder.collectedKeys.map {
				let props: TableStructure.Column.Property
				if $0.0 == primaryKeyName {
					props = .primaryKey
				} else {
					props = []
				}
				return .init(name: $0.0, type: $0.1, properties: props)
			},
			subTables: subTables,
			indexes: [])
		return tableStruct
	}
}

struct Create<OAF: Codable, D: DatabaseProtocol> {
	typealias OverAllForm = OAF
	let fromDatabase: D
	let policy: TableCreatePolicy
	let tableStructure: TableStructure
	init(fromDatabase ft: D, primaryKey: PartialKeyPath<OAF>?, policy p: TableCreatePolicy) throws {
		fromDatabase = ft
		policy = p
		tableStructure = try OverAllForm.swormTableStructure(policy: policy, primaryKey: primaryKey)
		let delegate = fromDatabase.configuration.sqlGenDelegate
		let sql = try delegate.getCreateTableSQL(forTable: tableStructure, policy: policy)
		for stat in sql {
			SwORMLogging.log(.query, stat)
			let exeDelegate = try fromDatabase.configuration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
}

struct Index<OAF: Codable, A: TableProtocol>: FromTableProtocol {
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	init(fromTable ft: FromTableType, keys: [PartialKeyPath<FromTableType.Form>]) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		let tableName = "\(OverAllForm.swormTableName)"
		let pathDecoder = SwORMKeyPathsDecoder()
		let pathInstance = try OverAllForm.init(from: pathDecoder)
		let keyNames: [String] = try keys.map {
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: $0) else {
				throw SwORMSQLGenError("Could not get column name for index \(OverAllForm.self).")
			}
			return pkn
		}
		let sql = try keyNames.flatMap { try delegate.getCreateIndexSQL(forTable: tableName, on: $0) }
		for stat in sql {
			SwORMLogging.log(.query, stat)
			let exeDelegate = try ft.databaseConfiguration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
}

extension DatabaseProtocol {
	@discardableResult
	func create<A: Codable>(_ type: A.Type, primaryKey: PartialKeyPath<A>? = nil, policy: TableCreatePolicy = .defaultPolicy) throws -> Create<A, Self> {
		return try .init(fromDatabase: self, primaryKey: primaryKey, policy: policy)
	}
}

extension Table {
	@discardableResult
	func index(_ keys: PartialKeyPath<Form>...) throws -> Index<OverAllForm, Table<A, C>> {
		return try .init(fromTable: self, keys: keys)
	}
}

