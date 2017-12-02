//
//  PerfectSwORMSQL.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-23.
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

struct SwORMSQLGenError: Error {
	let msg: String
	init(_ msg: String) {
		self.msg = msg
		SwORMLogging.log(.error, msg)
	}
}
struct SwORMSQLExeError: Error {
	let msg: String
	init(_ msg: String) {
		self.msg = msg
		SwORMLogging.log(.error, msg)
	}
}

public protocol SwORMSQLGenerating {
	func sqlSnippet(delegate: SwORMGenDelegate) throws -> String
}

extension SwORMSQLGenerating {
	func sqlSnippet(delegate: SwORMGenDelegate, expression: SwORMExpression) throws -> String {
		switch expression {
		case .column(let name):
			return try delegate.quote(identifier: name)
		case .and(let lhs, let rhs):
			return try bin(delegate, "AND", lhs, rhs)
		case .or(let lhs, let rhs):
			return try bin(delegate, "OR", lhs, rhs)
		case .equality(let lhs, let rhs):
			return try bin(delegate, "=", lhs, rhs)
		case .inequality(let lhs, let rhs):
			return try bin(delegate, "!=", lhs, rhs)
		case .not(let rhs):
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "NOT \(rhsStr)"
		case .lessThan(let lhs, let rhs):
			return try bin(delegate, "<", lhs, rhs)
		case .lessThanEqual(let lhs, let rhs):
			return try bin(delegate, "<=", lhs, rhs)
		case .greaterThan(let lhs, let rhs):
			return try bin(delegate, ">", lhs, rhs)
		case .greaterThanEqual(let lhs, let rhs):
			return try bin(delegate, ">=", lhs, rhs)
		case .keyPath(_):
			return "!FIX!"
		case .null:
			return "NULL"
		case .lazy(let e):
			return try sqlSnippet(delegate: delegate, expression: e())
		case .integer(_), .decimal(_), .string(_), .blob(_), .bool(_):
			return try delegate.getBinding(for: expression)
		}
	}
	private func bin(_ delegate: SwORMGenDelegate, _ op: String, _ lhs: SwORMExpression, _ rhs: SwORMExpression) throws -> String {
		return "\(try sqlSnippet(delegate: delegate, expression: lhs)) \(op) \(try sqlSnippet(delegate: delegate, expression: rhs))"
	}
	private func un(_ delegate: SwORMGenDelegate, _ op: String, _ rhs: SwORMExpression) throws -> String {
		return "\(op) \(try sqlSnippet(delegate: delegate, expression: rhs))"
	}
}

private struct SwORMSQLStructure {
	var command: SwORMCommand?
	var tables: [SwORMTable] = []
	var wheres: [SwORMWhere] = []
	var orderings: [SwORMOrdering] = []
}

public struct SwORMSQLGenerator {
	
	func generate<A: SwORMCommand & SwORMItem>(command: A) throws -> (SwORMDatabase, String, SwORMBindings) {
		let (dbm, items) = command.flatten()
		guard let db = dbm else {
			throw SwORMSQLGenError("Unable to get database from query.")
		}
		let d = db.genDelegate
		let structure = try removeEntropy(items: items)
		let sql = try generate(delegate: d, structure: structure)
		SwORMLogging.log(.query, sql)
		return (db, sql, d.bindings)
	}
	
	private func generate(delegate: SwORMGenDelegate, structure: SwORMSQLStructure) throws -> String {
		guard let command = structure.command else {
			throw SwORMSQLGenError("No command was found in this query.")
		}
		let orderings = command.subStructureOrder
		var commandStr = try generate(delegate: delegate, command: command) ?? ""
		var callCount = 1
		for subItem in orderings {
			switch subItem {
			case .tables:
				if let s = try generate(delegate: delegate, from: structure.tables) {
					commandStr += " " + s
				}
			case .wheres:
				if let s = try generate(delegate: delegate, where: structure.wheres) {
					commandStr += " " + s
				}
			case .orderings:
				if let s = try generate(delegate: delegate, order: structure.orderings) {
					commandStr += " " + s
				}
			case .command:
				if let s = try generate(delegate: delegate, command: command, count: callCount) {
					commandStr += " " + s
				}
				callCount += 1
			case .tablesError:
				guard structure.tables.isEmpty else {
					throw SwORMSQLGenError("This SQL command does not accept a table specifier.")
				}
			case .wheresError:
				guard structure.wheres.isEmpty else {
					throw SwORMSQLGenError("This SQL command does not accept a WHERE clause.")
				}
			case .orderingsError:
				guard structure.orderings.isEmpty else {
					throw SwORMSQLGenError("This SQL command does not accept an ORDER clause.")
				}
			}
		}
		return commandStr
	}
	
	private func generate(delegate: SwORMGenDelegate, command: SwORMCommand) throws -> String? {
		return try command.sqlSnippet(delegate: delegate)
	}
	
	private func generate(delegate: SwORMGenDelegate, command: SwORMCommand, count: Int) throws -> String? {
		return try command.sqlSnippet(delegate: delegate, callCount: count)
	}
	
	private func generate(delegate: SwORMGenDelegate, from: [SwORMTable]) throws -> String? {
		guard !from.isEmpty else {
			throw SwORMSQLGenError("No tables were specified.")
		}
		return "\(try from.map { try $0.sqlSnippet(delegate: delegate) }.joined(separator: ", "))"
	}
	
	private func generate(delegate: SwORMGenDelegate, where wha: [SwORMWhere]) throws -> String? {
		guard !wha.isEmpty else {
			return nil
		}
		return "WHERE \(try wha.map { "(\(try $0.sqlSnippet(delegate: delegate)))" }.joined(separator: " AND "))"
	}
	
	private func generate(delegate: SwORMGenDelegate, order: [SwORMOrdering]) throws -> String? {
		guard !order.isEmpty else {
			return nil
		}
		return "ORDER BY \(try order.map { try $0.sqlSnippet(delegate: delegate) }.joined(separator: ", "))"
	}

	private func removeEntropy(items: [SwORMItem]) throws -> SwORMSQLStructure {
		var structure = SwORMSQLStructure()
		for item in items {
			switch item {
			case let table as SwORMTable:
				structure.tables.append(table)
			case let wha as SwORMWhere:
				structure.wheres.append(wha)
			case let ord as SwORMOrdering:
				structure.orderings.append(ord)
			case let sel as SwORMCommand:
				structure.command = sel
			default:
				throw SwORMSQLGenError("Strange element in query: \(item)")
			}
		}
		return structure
	}
	
}
