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


