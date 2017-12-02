//
//  PerfectSwORMExpressions.swift
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

public indirect enum SwORMExpression {
	public typealias ExpressionProducer = () -> SwORMExpression
	
	case column(String)
	case and(lhs: SwORMExpression, rhs: SwORMExpression)
	case or(lhs: SwORMExpression, rhs: SwORMExpression)
	case equality(lhs: SwORMExpression, rhs: SwORMExpression)
	case inequality(lhs: SwORMExpression, rhs: SwORMExpression)
	case not(rhs: SwORMExpression)
	case lessThan(lhs: SwORMExpression, rhs: SwORMExpression)
	case lessThanEqual(lhs: SwORMExpression, rhs: SwORMExpression)
	case greaterThan(lhs: SwORMExpression, rhs: SwORMExpression)
	case greaterThanEqual(lhs: SwORMExpression, rhs: SwORMExpression)
	case lazy(ExpressionProducer)
	case keyPath(AnyKeyPath)
	
	case integer(Int)
	case decimal(Double)
	case string(String)
	case blob([UInt8])
	case bool(Bool)
	case null
	
	// todo:
	// .blob with Data
	// .null and special handling in query gen IS NULL / IS NOT NULL
	// .integer of varying width
}

public extension SwORMExpression {
	static func &&(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .and(lhs: lhs, rhs: rhs)
	}
	static func ||(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .or(lhs: lhs, rhs: rhs)
	}
	static func ==(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .equality(lhs: lhs, rhs: rhs)
	}
	static func !=(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .inequality(lhs: lhs, rhs: rhs)
	}
	static func <(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThan(lhs: lhs, rhs: rhs)
	}
	static func <=(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThanEqual(lhs: lhs, rhs: rhs)
	}
	static func >(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThan(lhs: lhs, rhs: rhs)
	}
	static func >=(lhs: SwORMExpression, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThanEqual(lhs: lhs, rhs: rhs)
	}
	static prefix func !(rhs: SwORMExpression) -> SwORMExpression {
		return .not(rhs: rhs)
	}
}

public extension SwORMExpression {
	static func ==(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .equality(lhs: .integer(lhs), rhs: rhs)
	}
	static func ==(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .equality(lhs: lhs, rhs: .integer(rhs))
	}
	static func ==(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .equality(lhs: .decimal(lhs), rhs: rhs)
	}
	static func ==(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .equality(lhs: lhs, rhs: .decimal(rhs))
	}
	static func ==(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .equality(lhs: .string(lhs), rhs: rhs)
	}
	static func ==(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .equality(lhs: lhs, rhs: .string(rhs))
	}
	
	static func !=(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .inequality(lhs: .integer(lhs), rhs: rhs)
	}
	static func !=(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .inequality(lhs: lhs, rhs: .integer(rhs))
	}
	static func !=(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .inequality(lhs: .decimal(lhs), rhs: rhs)
	}
	static func !=(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .inequality(lhs: lhs, rhs: .decimal(rhs))
	}
	static func !=(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .inequality(lhs: .string(lhs), rhs: rhs)
	}
	static func !=(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .inequality(lhs: lhs, rhs: .string(rhs))
	}
	
	static func <(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThan(lhs: .integer(lhs), rhs: rhs)
	}
	static func <(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .lessThan(lhs: lhs, rhs: .integer(rhs))
	}
	static func <(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThan(lhs: .decimal(lhs), rhs: rhs)
	}
	static func <(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .lessThan(lhs: lhs, rhs: .decimal(rhs))
	}
	static func <(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThan(lhs: .string(lhs), rhs: rhs)
	}
	static func <(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .lessThan(lhs: lhs, rhs: .string(rhs))
	}
	
	static func <=(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThanEqual(lhs: .integer(lhs), rhs: rhs)
	}
	static func <=(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .lessThanEqual(lhs: lhs, rhs: .integer(rhs))
	}
	static func <=(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThanEqual(lhs: .decimal(lhs), rhs: rhs)
	}
	static func <=(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .lessThanEqual(lhs: lhs, rhs: .decimal(rhs))
	}
	static func <=(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .lessThanEqual(lhs: .string(lhs), rhs: rhs)
	}
	static func <=(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .lessThanEqual(lhs: lhs, rhs: .string(rhs))
	}
	
	static func >(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThan(lhs: .integer(lhs), rhs: rhs)
	}
	static func >(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .greaterThan(lhs: lhs, rhs: .integer(rhs))
	}
	static func >(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThan(lhs: .decimal(lhs), rhs: rhs)
	}
	static func >(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .greaterThan(lhs: lhs, rhs: .decimal(rhs))
	}
	static func >(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThan(lhs: .string(lhs), rhs: rhs)
	}
	static func >(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .greaterThan(lhs: lhs, rhs: .string(rhs))
	}
	
	static func >=(lhs: Int, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThanEqual(lhs: .integer(lhs), rhs: rhs)
	}
	static func >=(lhs: SwORMExpression, rhs: Int) -> SwORMExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .integer(rhs))
	}
	static func >=(lhs: Double, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThanEqual(lhs: .decimal(lhs), rhs: rhs)
	}
	static func >=(lhs: SwORMExpression, rhs: Double) -> SwORMExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .decimal(rhs))
	}
	static func >=(lhs: String, rhs: SwORMExpression) -> SwORMExpression {
		return .greaterThanEqual(lhs: .string(lhs), rhs: rhs)
	}
	static func >=(lhs: SwORMExpression, rhs: String) -> SwORMExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .string(rhs))
	}
}

public extension SwORMExpression {
	static func ==<T: Codable>(lhs: PartialKeyPath<T>, rhs: SwORMExpression) -> SwORMExpression {
		return .equality(lhs: .keyPath(lhs), rhs: rhs)
	}
}

extension SwORMExpression {
	func sqlSnippet(state: SQLGenState) throws -> String {
		let delegate = state.delegate
		switch self {
		case .column(let name):
			return try delegate.quote(identifier: name)
		case .and(let lhs, let rhs):
			return try bin(state, "AND", lhs, rhs)
		case .or(let lhs, let rhs):
			return try bin(state, "OR", lhs, rhs)
		case .equality(let lhs, let rhs):
			return try bin(state, "=", lhs, rhs)
		case .inequality(let lhs, let rhs):
			return try bin(state, "!=", lhs, rhs)
		case .not(let rhs):
			let rhsStr = try rhs.sqlSnippet(state: state)
			return "NOT \(rhsStr)"
		case .lessThan(let lhs, let rhs):
			return try bin(state, "<", lhs, rhs)
		case .lessThanEqual(let lhs, let rhs):
			return try bin(state, "<=", lhs, rhs)
		case .greaterThan(let lhs, let rhs):
			return try bin(state, ">", lhs, rhs)
		case .greaterThanEqual(let lhs, let rhs):
			return try bin(state, ">=", lhs, rhs)
		case .keyPath(let k):
			let rootType = type(of: k).rootType
			guard let tableData = state.getTableData(type: rootType),
				let modelInstance = tableData.modelInstance else {
				throw SwORMSQLGenError("Unable to get table for KeyPath root \(rootType).")
			}
			guard let keyName = try tableData.keyPathDecoder.getKeyPathName(modelInstance, keyPath: k) else {
				throw SwORMSQLGenError("Unable to get KeyPath name for table \(rootType).")
			}
			let aliasQ = try delegate.quote(identifier: tableData.alias)
			let nameQ = try delegate.quote(identifier: keyName)
			return "\(aliasQ).\(nameQ)"
		case .null:
			return "NULL"
		case .lazy(let e):
			return try e().sqlSnippet(state: state)
		case .integer(_), .decimal(_), .string(_), .blob(_), .bool(_):
			return try delegate.getBinding(for: self)
		}
	}
	private func bin(_ state: SQLGenState, _ op: String, _ lhs: SwORMExpression, _ rhs: SwORMExpression) throws -> String {
		return "\(try lhs.sqlSnippet(state: state)) \(op) \(try rhs.sqlSnippet(state: state))"
	}
	private func un(_ state: SQLGenState, _ op: String, _ rhs: SwORMExpression) throws -> String {
		return "\(op) \(try rhs.sqlSnippet(state: state))"
	}
	func referencedTypes() -> [Any.Type] {
		switch self {
		case .column(_):
			return []
		case .and(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .or(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .equality(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .inequality(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .not(let rhs):
			return rhs.referencedTypes()
		case .lessThan(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .lessThanEqual(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .greaterThan(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .greaterThanEqual(let lhs, let rhs):
			return lhs.referencedTypes() + rhs.referencedTypes()
		case .keyPath(let k):
			return [type(of: k).rootType]
		case .null:
			return []
		case .lazy(let e):
			return e().referencedTypes()
		case .integer(_), .decimal(_), .string(_), .blob(_), .bool(_):
			return []
		}
	}
}



