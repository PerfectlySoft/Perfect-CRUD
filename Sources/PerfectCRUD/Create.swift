//
//  PerfectCRUDCreate.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-03.
//

import Foundation

public struct TableCreatePolicy: OptionSet {
	public let rawValue: Int
	public init(rawValue r: Int) { rawValue = r }
	public static let shallow = TableCreatePolicy(rawValue: 1)
	public static let dropTable = TableCreatePolicy(rawValue: 2)
	public static let reconcileTable = TableCreatePolicy(rawValue: 4)
	
	public static let defaultPolicy: TableCreatePolicy = []
}

public struct TableStructure {
	public struct Column {
		public struct Property: OptionSet {
			public let rawValue: Int
			public init(rawValue r: Int) { rawValue = r }
			public static let primaryKey = Property(rawValue: 1)
		}
		public let name: String
		public let type: Any.Type
		public let optional: Bool
		public let properties: Property
	}
	public let tableName: String
	public let primaryKeyName: String?
	public let columns: [Column]
	public let subTables: [TableStructure]
	public let indexes: [String]
}

extension Decodable {
	static func CRUDTableStructure(policy: TableCreatePolicy, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let columnDecoder = CRUDColumnNameDecoder()
		columnDecoder.tableNamePath.append("\(Self.CRUDTableName)")
		_ = try Self.init(from: columnDecoder)
		return try CRUDTableStructure(policy: policy, columnDecoder: columnDecoder, primaryKey: primaryKey)
	}
	static func CRUDTableStructure(policy: TableCreatePolicy, columnDecoder: CRUDColumnNameDecoder, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let primaryKeyName: String?
		if let pkpk = primaryKey {
			let pathDecoder = CRUDKeyPathsDecoder()
			let pathInstance = try Self.init(from: pathDecoder)
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: pkpk) else {
				throw CRUDSQLGenError("Could not get column name for primary key \(Self.self).")
			}
			primaryKeyName = pkn
		} else if columnDecoder.collectedKeys.map({$0.0}).contains("id") {
			primaryKeyName = "id"
		} else {
			primaryKeyName = nil
		}
		let subTables: [TableStructure]
		if !policy.contains(.shallow) {
			subTables = try columnDecoder.subTables.map {
				try CRUDTableStructure(policy: policy, columnDecoder: $0.2)
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
				return .init(name: $0.name, type: $0.type, optional: $0.optional, properties: props)
			},
			subTables: subTables,
			indexes: [])
		return tableStruct
	}
}

public struct Create<OAF: Codable, D: DatabaseProtocol> {
	typealias OverAllForm = OAF
	let fromDatabase: D
	let policy: TableCreatePolicy
	let tableStructure: TableStructure
	init(fromDatabase ft: D, primaryKey: PartialKeyPath<OAF>?, policy p: TableCreatePolicy) throws {
		fromDatabase = ft
		policy = p
		tableStructure = try OverAllForm.CRUDTableStructure(policy: policy, primaryKey: primaryKey)
		let delegate = fromDatabase.configuration.sqlGenDelegate
		let sql = try delegate.getCreateTableSQL(forTable: tableStructure, policy: policy)
		for stat in sql {
			CRUDLogging.log(.query, stat)
			let exeDelegate = try fromDatabase.configuration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
}

public struct Index<OAF: Codable, A: TableProtocol>: FromTableProtocol, TableProtocol {
	public typealias Form = OAF
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	init(fromTable ft: FromTableType, keys: [PartialKeyPath<FromTableType.Form>], unique: Bool) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		let tableName = "\(OverAllForm.CRUDTableName)"
		let pathDecoder = CRUDKeyPathsDecoder()
		let pathInstance = try OverAllForm.init(from: pathDecoder)
		let keyNames: [String] = try keys.map {
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: $0) else {
				throw CRUDSQLGenError("Could not get column name for index \(OverAllForm.self).")
			}
			return pkn
		}
		let sql = try delegate.getCreateIndexSQL(forTable: tableName, on: keyNames, unique: unique)
		for stat in sql {
			CRUDLogging.log(.query, stat)
			let exeDelegate = try ft.databaseConfiguration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
	public func setState(state: inout SQLGenState) throws {}
	public func setSQL(state: inout SQLGenState) throws {}
}

public extension DatabaseProtocol {
	@discardableResult
	func create<A: Codable>(_ type: A.Type, policy: TableCreatePolicy = .defaultPolicy) throws -> Table<A, Self> {
		let _: Create<A, Self> = try Create(fromDatabase: self, primaryKey: nil, policy: policy)
		return Table(database: self)
	}
	@discardableResult
	func create<A: Codable, V: Equatable>(_ type: A.Type, primaryKey: KeyPath<A, V>? = nil, policy: TableCreatePolicy = .defaultPolicy) throws -> Table<A, Self> {
		let _: Create<A, Self> = try Create(fromDatabase: self, primaryKey: primaryKey, policy: policy)
		return Table(database: self)
	}
}

public extension Table {
	@discardableResult
	func index(unique: Bool = false, _ keys: PartialKeyPath<OverAllForm>...) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: keys, unique: unique)
	}
	// !FIX! Swift 4.0.2 seems to have a problem with type inference for the above func
	// would not let \.name type references to be used
	// this is an ugly work around
	@discardableResult
	func index<V1: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable, V4: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3, key4], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable, V4: Equatable, V5: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3, key4, key5], unique: unique)
	}
}

