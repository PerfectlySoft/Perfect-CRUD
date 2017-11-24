//
//  PerfectSwORMQuery.swift
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

public protocol SwORMSQLGenerating {
	func sqlSnippet(delegate: SwORMGenDelegate) throws -> String
}

extension SwORMSQLGenerating {
	func sqlSnippet(delegate: SwORMGenDelegate, expression: SwORMExpression) throws -> String {
		switch expression {
		case .column(let name):
			return try delegate.quote(identifier: name)
		case .and(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) AND \(rhsStr)"
		case .or(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) OR \(rhsStr)"
		case .equality(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) = \(rhsStr)"
		case .inequality(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) != \(rhsStr)"
		case .not(let rhs):
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "NOT \(rhsStr)"
		case .lessThan(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) < \(rhsStr)"
		case .lessThanEqual(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) <= \(rhsStr)"
		case .greaterThan(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) > \(rhsStr)"
		case .greaterThanEqual(let lhs, let rhs):
			let lhsStr = try sqlSnippet(delegate: delegate, expression: lhs)
			let rhsStr = try sqlSnippet(delegate: delegate, expression: rhs)
			return "\(lhsStr) >= \(rhsStr)"
		case .lazy(let e):
			return try sqlSnippet(delegate: delegate, expression: e())
		case .integer(_), .decimal(_), .string(_), .blob(_):
			return try delegate.getBinding(for: expression)
		}
	}
}

public protocol SwORMCommand: SwORMSQLGenerating {
	
}

public protocol SwORMQuerySelectable: SwORMSQLGenerating {
	func select<A: Decodable>(as: A.Type) throws -> SwORMSelect<A>
//	func delete() throws
//	func update<A: Encodable>(_ using: A) throws
//	func insert<A: Encodable>(_ using: [A]) throws
}

public protocol SwORMQueryOrdering: SwORMQuerySelectable {
	func then(by expression: SwORMExpression) throws -> SwORMQueryOrdering
	func then(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering
}

public protocol SwORMQueryOrderable: SwORMSQLGenerating {
	func order(by expression: SwORMExpression) throws -> SwORMQueryOrdering
	func order(byDescending expression: SwORMExpression) throws -> SwORMQueryOrdering
}

public protocol SwORMQueryWhereable: SwORMQueryOrderable, SwORMQuerySelectable {
	func `where`(_ expression: SwORMExpression) -> SwORMQueryWhereable
}


