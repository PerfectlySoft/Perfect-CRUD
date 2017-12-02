//
//  PerfectSwORMDatabase.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	typealias Configuration = C
	let configuration: Configuration
	func table<T: Codable>(_ form: T.Type) -> Table<T, Database<C>> {
		return .init(database: self)
	}
}
