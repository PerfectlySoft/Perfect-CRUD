//
//  PerfectSwORMDatabase.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

public struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	public typealias Configuration = C
	public let configuration: Configuration
	public init(configuration c: Configuration) {
		configuration = c
	}
	public func table<T: Codable>(_ form: T.Type) -> Table<T, Database<C>> {
		return .init(database: self)
	}
}

public extension Database {
	func sql(_ sql: String, bindings: Bindings = []) throws {
		let delegate = try configuration.sqlExeDelegate(forSQL: sql)
		try delegate.bind(bindings, skip: 0)
		_ = try delegate.hasNext()
	}
}

public extension Database {
	func transaction<T>(_ body: () throws -> T) throws -> T {
		try sql("BEGIN")
		do {
			let r = try body()
			try sql("COMMIT")
			return r
		} catch {
			try sql("ROLLBACK")
			throw error
		}
	}
}
