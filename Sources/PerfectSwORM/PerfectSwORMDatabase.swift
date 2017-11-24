//
//  PerfectSwORMDatabase.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-22.
//	Copyright (C) 2017 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2017 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import Foundation

public typealias SwORMBindings = [(String, SwORMExpression)]

public protocol SwORMGenDelegate {
	var bindings: SwORMBindings { get }
	func getBinding(for: SwORMExpression) throws -> String
	func quote(identifier: String) throws -> String
}

public protocol SwORMExeDelegate {
	func hasNext() throws -> Bool
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>?
}

protocol SwORMItem {
	var source: SwORMItem? { get }
}

extension SwORMItem {
	func flatten() -> (SwORMDatabase?, [SwORMItem]) {
		var array: [SwORMItem] = []
		map(array: &array)
		let db: SwORMDatabase?
		if let table = array.first as? SwORMTable {
			db = table.database
		} else {
			db = nil
		}
		return (db, array)
	}
	func map(var array: inout [SwORMItem]) {
		if let s = source {
			s.map(array: &array)
		}
		array.append(self)
	}
}

public protocol SwORMDatabase {
	func table(_ name: String) -> SwORMQueryWhereable
	var genDelegate: SwORMGenDelegate { get }
	func exeDelegate(forSQL: String, withBindings: SwORMBindings) throws -> SwORMExeDelegate
}

public extension SwORMDatabase {
	func table(_ name: String) -> SwORMQueryWhereable {
		return SwORMTable(database: self, name: name)
	}
}

public struct SwORMSelect<A: Codable>: SwORMCommand, SwORMItem {
	public typealias Form = A
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		let delegate = delegate
		let decoder = SwORMColumnNameDecoder()
		do {
			_ = try Form(from: decoder)
			let keys = decoder.collectedKeys
			if !keys.isEmpty {
				return "SELECT \(try keys.map { try delegate.quote(identifier: $0) }.joined(separator: ", "))"
			}
		} catch {}
		return "SELECT *"
	}
	let source: SwORMItem?
}

public struct SwORMSelectIterator<A: Codable>: IteratorProtocol {
	public typealias Element = A
	let nothing: Bool
	let delegate: SwORMExeDelegate?
	init() {
		nothing = true
		delegate = nil
	}
	init(query: SwORMSelect<Element>) throws {
		nothing = false
		let (db, sql, binds) = try SwORMSQLGenerator().generate(command: query)
		delegate = try db.exeDelegate(forSQL: sql, withBindings: binds)
	}
	
	public mutating func next() -> Element? {
		guard nothing != true, let d = delegate else {
			return nil
		}
		do {
			if try d.hasNext() {
				let rowDecoder: SwORMDecoder<ColumnKey> = SwORMDecoder(delegate: d)
				return try Element(from: rowDecoder)
			}
		} catch {
			// !FIX! log error to a place
		}
		return nil
	}
}

extension SwORMSelect: Sequence {
	public typealias Iterator = SwORMSelectIterator<Form>
	public func makeIterator() -> SwORMSelectIterator<A> {
		do {
			return try SwORMSelectIterator<A>(query: self)
		} catch {
			// !FIX! log error to a place
			return SwORMSelectIterator<A>()
		}
	}
}

struct SwORMTable: SwORMQueryWhereable, SwORMItem {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return try delegate.quote(identifier: name)
	}
	func select<A: Decodable>(as: A.Type) throws -> SwORMSelect<A> {
		return SwORMSelect<A>(source: self)
	}
	func `where`(_ expression: SwORMExpression) -> SwORMQueryWhereable {
		return SwORMWhere(source: self, expression: expression)
	}
	func order(by expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: false)
	}
	func order(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: true)
	}
	let database: SwORMDatabase
	let name: String
	let source: SwORMItem? = nil
}

struct SwORMWhere: SwORMItem, SwORMQueryWhereable {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		throw SwORMSQLGenError(msg: "Unimplimented")
	}
	func `where`(_ expression: SwORMExpression) -> SwORMQueryWhereable {
		return SwORMWhere(source: self.source, expression: .and(lhs: self.expression, rhs: expression))
	}
	func order(by expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: false)
	}
	func order(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: true)
	}
	func select<A: Decodable>(as: A.Type) throws -> SwORMSelect<A> {
		return SwORMSelect<A>(source: self)
	}
	let source: SwORMItem?
	let expression: SwORMExpression
}

struct SwORMOrdering: SwORMItem, SwORMQueryOrdering {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		throw SwORMSQLGenError(msg: "Unimplimented")
	}
	func then(by expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: false)
	}
	func then(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: true)
	}
	func select<A: Decodable>(as: A.Type) throws -> SwORMSelect<A> {
		return SwORMSelect<A>(source: self)
	}
	var source: SwORMItem?
	let expression: SwORMExpression
	let descending: Bool
}

extension SwORMDatabase {
	func sql<A: Decodable>(_ sql: String, into: A.Type) throws -> [A] {
		return []
	}
	func sql(_ sql: String) throws {
		
	}
}
