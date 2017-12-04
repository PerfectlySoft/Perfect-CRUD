//
//  PerfectSwORMCreate.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-03.
//

import Foundation

struct TableCreatePolicy: OptionSet {
	let rawValue: Int
	static let recursive = TableCreatePolicy(rawValue: 1)
	static let dropFirst = TableCreatePolicy(rawValue: 2)
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
}

extension Decodable {
	static func swormTableStructure(primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let columnDecoder = SwORMColumnNameDecoder()
		columnDecoder.tableNamePath.append("\(Self.self)")
		_ = try Self.init(from: columnDecoder)
		return try swormTableStructure(columnDecoder: columnDecoder, primaryKey: primaryKey)
	}
	
	static func swormTableStructure(columnDecoder: SwORMColumnNameDecoder, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
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
		let subTables = try columnDecoder.subTables.map {
			try swormTableStructure(columnDecoder: $0.2)
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
			subTables: subTables)
		return tableStruct
	}
}

extension DatabaseProtocol {
	func create<A: Codable>(_ type: A.Type, primaryKey: PartialKeyPath<A>) throws {
		let tableStruct = try A.swormTableStructure(primaryKey: primaryKey)
		let delegate = configuration.sqlGenDelegate
		let sql = try delegate.getCreateSQL(forTable: tableStruct)
		for stat in sql {
			let exeDelegate = try configuration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
}
