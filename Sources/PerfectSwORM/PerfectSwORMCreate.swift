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
}

extension Decodable {
	static func swormTableStructure(primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let columnDecoder = SwORMColumnNameDecoder()
		_ = try Self.init(from: columnDecoder)
		let pathDecoder = SwORMKeyPathsDecoder()
		let pathInstance = try Self.init(from: pathDecoder)
		let primaryKeyName: String
		if let pkpk = primaryKey {
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
		for (name, type) in columnDecoder.collectedKeys {
			print("\(type)")
			switch type {
			default:
				()
			}
		}
		let tableStruct = TableStructure(
			tableName: "\(Self.self)",
			primaryKeyName: primaryKeyName,
			columns: columnDecoder.collectedKeys.map {
				let props: TableStructure.Column.Property
				if $0.0 == primaryKeyName {
					props = .primaryKey
				} else {
					props = []
				}
				return .init(name: $0.0, type: $0.1, properties: props)
		})
		return tableStruct
	}
}

extension DatabaseProtocol {
	func create<A: Codable>(_ type: A.Type, primaryKey: PartialKeyPath<A>) throws {
		let tableStruct = try A.swormTableStructure(primaryKey: primaryKey)
		
		return
	}
}
