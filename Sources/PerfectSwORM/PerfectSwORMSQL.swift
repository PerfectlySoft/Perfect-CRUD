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
}

private struct SwORMSQLStructure {
	var tables: [SwORMTable] = []
	var wheres: [SwORMWhere] = []
	var orderings: [SwORMOrdering] = []
	var command: SwORMCommand?
}

public struct SwORMSQLGenerator {
	
	func generate<A: SwORMCommand & SwORMItem>(command: A) throws -> (SwORMDatabase, String, SwORMBindings) {
		let (dbm, items) = command.flatten()
		guard let db = dbm else {
			throw SwORMSQLGenError(msg: "Unable to get database from query.")
		}
		let d = db.genDelegate
		let structure = try orderStructure(items: items)
		let sql = try generate(delegate: d, structure: structure)
		
		print("DBG: \(sql)")
		
		return (db, sql, d.bindings)
	}
	
	private func generate(delegate: SwORMGenDelegate, structure: SwORMSQLStructure) throws -> String {
		guard let command = structure.command else {
			throw SwORMSQLGenError(msg: "No command was found in this query.")
		}
		let commandStr = try generate(delegate: delegate, command: command)
		let fromStr = try generate(delegate: delegate, from: structure.tables)
		var sql = "\(commandStr) \(fromStr)"
		if let whereStr = try generate(delegate: delegate, where: structure.wheres) {
			sql += " \(whereStr)"
		}
		if let orderStr = try generate(delegate: delegate, order: structure.orderings) {
			sql += " \(orderStr)"
		}
		return sql
	}
	
	private func generate(delegate: SwORMGenDelegate, command: SwORMCommand) throws -> String {
		return try command.sqlSnippet(delegate: delegate)
	}
	
	private func generate(delegate: SwORMGenDelegate, from: [SwORMTable]) throws -> String {
		guard !from.isEmpty else {
			throw SwORMSQLGenError(msg: "No tables were specified.")
		}
		return "FROM \(try from.map { try $0.sqlSnippet(delegate: delegate) }.joined(separator: ", "))"
	}
	
	private func generate(delegate: SwORMGenDelegate, where wha: [SwORMWhere]) throws -> String? {
		guard !wha.isEmpty else {
			return nil
		}
		if wha.count == 1 {
			return "WHERE \(try wha[0].sqlSnippet(delegate: delegate))"
		}
		return "WHERE \(try wha.map { "(\(try $0.sqlSnippet(delegate: delegate)))" }.joined(separator: " AND "))"
	}
	
	private func generate(delegate: SwORMGenDelegate, order: [SwORMOrdering]) throws -> String? {
		guard !order.isEmpty else {
			return nil
		}
		return "ORDER BY \(try order.map { try $0.sqlSnippet(delegate: delegate) }.joined(separator: ", "))"
	}

	private func orderStructure(items: [SwORMItem]) throws -> SwORMSQLStructure {
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
				throw SwORMSQLGenError(msg: "Strange element in query: \(item)")
			}
		}
		return structure
	}
	
}
