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
	func bind(_ bindings: SwORMBindings, skip: Int) throws
	func hasNext() throws -> Bool
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>?
}

public extension SwORMExeDelegate {
	func bind(_ bindings: SwORMBindings) throws { return try bind(bindings, skip: 0) }
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

public protocol SwORMTable: SwORMQueryWhereable, SwORMQueryInsertable {
	var database: SwORMDatabase { get }
}

public protocol SwORMDatabase {
	func table(_ name: String) -> SwORMTable
	var genDelegate: SwORMGenDelegate { get }
	func exeDelegate(forSQL: String) throws -> SwORMExeDelegate
	func transaction<Ret>(_ body: (Self) throws -> Ret) throws -> Ret
}

public extension SwORMDatabase {
	func table(_ name: String) -> SwORMTable {
		return SwORMTableImpl(database: self, name: name)
	}
}

public struct SwORMSelect<A: Codable>: SwORMCommand, SwORMItem {
	public let subStructureOrder: [SwORMQuerySubStructure] = [.tables, .wheres, .orderings]
	public typealias Form = A
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		let decoder = SwORMColumnNameDecoder()
		do {
			_ = try Form(from: decoder)
			let keys = decoder.collectedKeys
			if !keys.isEmpty {
				return "SELECT \(try keys.map { try delegate.quote(identifier: $0) }.joined(separator: ", ")) FROM"
			}
		} catch {}
		return "SELECT * FROM"
	}
	let source: SwORMItem?
}

public struct SwORMDelete: SwORMCommand, SwORMItem {
	public let subStructureOrder: [SwORMQuerySubStructure] = [.tables, .wheres, .orderingsError]
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return "DELETE FROM"
	}
	let source: SwORMItem?
}

// UPDATE foo SET x=?, y=?, z=? WHERE blah
public struct SwORMUpdate<A: Encodable>: SwORMCommand, SwORMItem {
	public let subStructureOrder: [SwORMQuerySubStructure] = [.tables, .command, .wheres, .orderingsError]
	public typealias Form = A
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return "UPDATE"
	}
	public func sqlSnippet(delegate: SwORMGenDelegate, callCount: Int) throws -> String {
		guard callCount == 1 else {
			throw SwORMSQLGenError("Update command generator called more than twice.")
		}
		let encoder = SwORMBindingsEncoder(delegate: delegate, ignoreKeys: [])
		try item.encode(to: encoder)
		let d = zip(encoder.columnNames, encoder.bindIdentifiers)
		return "SET \(try d.map { "\(try delegate.quote(identifier: $0.0))=\($0.1)" }.joined(separator: ", "))"
	}
	let source: SwORMItem?
	let item: Form
}

// INSERT INTO foo (x, y, z) VALUES (?,?,?) [multiple]
public struct SwORMInsert<A: Encodable>: SwORMCommand, SwORMItem {
	public let subStructureOrder: [SwORMQuerySubStructure] = [.tables, .command, .orderingsError]
	public typealias Form = A
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return "INSERT INTO"
	}
	public func sqlSnippet(delegate: SwORMGenDelegate, callCount: Int) throws -> String {
		guard callCount == 1 else {
			throw SwORMSQLGenError("Update command generator called more than twice.")
		}
		guard !items.isEmpty else {
			throw SwORMSQLGenError("No items to insert.")
		}
		let encoder = SwORMBindingsEncoder(delegate: delegate, ignoreKeys: [])
		try items.first!.encode(to: encoder)
		let columns = try encoder.columnNames.map { try delegate.quote(identifier: $0) }
		let binds = encoder.bindIdentifiers
		return "(\(columns.joined(separator: ", "))) VALUES (\(binds.joined(separator: ", ")))"
	}
	let source: SwORMItem?
	let items: [Form]
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
		delegate = try db.exeDelegate(forSQL: sql)
		try delegate?.bind(binds)
	}
	public mutating func next() -> Element? {
		guard nothing != true, let d = delegate else {
			return nil
		}
		do {
			if try d.hasNext() {
				let rowDecoder: SwORMRowDecoder<ColumnKey> = SwORMRowDecoder(delegate: d)
				return try Element(from: rowDecoder)
			}
		} catch {
			SwORMLogging.log(.error, "Error thrown in SwORMSelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
}

struct SwORMTableImpl: SwORMTable, SwORMItem {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return try delegate.quote(identifier: name)
	}
	let database: SwORMDatabase
	let name: String
	let source: SwORMItem? = nil
}

struct SwORMWhere: SwORMItem, SwORMQueryWhereable {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		return try sqlSnippet(delegate: delegate, expression: expression)
	}
	func `where`(_ expression: SwORMExpression) -> SwORMQueryWhereable {
		return SwORMWhere(source: self.source, expression: .and(lhs: self.expression, rhs: expression))
	}
	let source: SwORMItem?
	let expression: SwORMExpression
}

struct SwORMOrdering: SwORMItem, SwORMQueryOrdering {
	public func sqlSnippet(delegate: SwORMGenDelegate) throws -> String {
		let snip = try sqlSnippet(delegate: delegate, expression: expression)
		if descending {
			return snip + " DESC"
		}
		return snip
	}
	var source: SwORMItem?
	let expression: SwORMExpression
	let descending: Bool
}

extension SwORMSelect: Sequence {
	public typealias Iterator = SwORMSelectIterator<Form>
	public func makeIterator() -> SwORMSelectIterator<A> {
		do {
			return try SwORMSelectIterator<A>(query: self)
		} catch {
			SwORMLogging.log(.error, "Error thrown in SwORMSelect.makeIterator() Caught: \(error)")
			return SwORMSelectIterator<A>()
		}
	}
}

extension SwORMQuerySelectable where Self: SwORMItem {
	func select<A: Decodable>(as: A.Type) throws -> SwORMSelect<A> {
		return SwORMSelect<A>(source: self)
	}
	func delete() throws {
		try simpleExe(SwORMDelete(source: self))
	}
	func update<A: Encodable>(_ using: A) throws {
		let update = SwORMUpdate(source: self, item: using)
		let (db, sql, binds1) = try SwORMSQLGenerator().generate(command: update)
		let delegate = try db.exeDelegate(forSQL: sql)
		do {
			let genDel = db.genDelegate
			let encoder = SwORMBindingsEncoder(delegate: genDel)
			try using.encode(to: encoder)
			try delegate.bind(genDel.bindings)
			try delegate.bind(binds1, skip: genDel.bindings.count)
			_ = try delegate.hasNext()
		}
	}
	fileprivate func simpleExe<Cmd: SwORMCommand & SwORMItem>(_ cmd: Cmd) throws {
		let (db, sql, binds) = try SwORMSQLGenerator().generate(command: cmd)
		let delegate = try db.exeDelegate(forSQL: sql)
		try delegate.bind(binds)
		_ = try delegate.hasNext()
	}
}

extension SwORMQueryOrderable where Self: SwORMItem {
	func order(by expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: false)
	}
	func order(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: true)
	}
}

extension SwORMQueryWhereable where Self: SwORMItem {
	func `where`(_ expression: SwORMExpression) -> SwORMQueryWhereable {
		return SwORMWhere(source: self, expression: expression)
	}
}

extension SwORMQueryOrdering where Self: SwORMItem {
	func then(by expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: false)
	}
	func then(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering {
		return SwORMOrdering(source: self, expression: expression, descending: true)
	}
}

extension SwORMTable where Self: SwORMItem {
	func insert<A>(_ using: [A]) throws where A : Encodable {
		let insert = SwORMInsert(source: self, items: using)
		let (db, sql, _) = try SwORMSQLGenerator().generate(command: insert)
		let delegate = try db.exeDelegate(forSQL: sql)
		for item in using {
			let genDel = db.genDelegate
			let encoder = SwORMBindingsEncoder(delegate: genDel)
			try item.encode(to: encoder)
			try delegate.bind(genDel.bindings)
			_ = try delegate.hasNext()
		}
	}
}
