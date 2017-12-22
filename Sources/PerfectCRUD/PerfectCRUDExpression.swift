//
//  PerfectCRUDExpressions.swift
//  PerfectCRUD
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

public indirect enum CRUDExpression {
	public typealias ExpressionProducer = () -> CRUDExpression
	
	case column(String)
	case and(lhs: CRUDExpression, rhs: CRUDExpression)
	case or(lhs: CRUDExpression, rhs: CRUDExpression)
	case equality(lhs: CRUDExpression, rhs: CRUDExpression)
	case inequality(lhs: CRUDExpression, rhs: CRUDExpression)
	case not(rhs: CRUDExpression)
	case lessThan(lhs: CRUDExpression, rhs: CRUDExpression)
	case lessThanEqual(lhs: CRUDExpression, rhs: CRUDExpression)
	case greaterThan(lhs: CRUDExpression, rhs: CRUDExpression)
	case greaterThanEqual(lhs: CRUDExpression, rhs: CRUDExpression)
	case lazy(ExpressionProducer)
	case keyPath(AnyKeyPath)
	
	case integer(Int)
	case decimal(Double)
	case string(String)
	case blob([UInt8])
	case bool(Bool)
	case uuid(UUID)
	case date(Date)
	case null
	
	// todo:
	// .blob with Data
	// .integer of varying width
}

public extension CRUDExpression {
	static func &&(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .and(lhs: lhs, rhs: rhs)
	}
	static func ||(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .or(lhs: lhs, rhs: rhs)
	}
	static func ==(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .equality(lhs: lhs, rhs: rhs)
	}
	static func !=(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .inequality(lhs: lhs, rhs: rhs)
	}
	static func <(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThan(lhs: lhs, rhs: rhs)
	}
	static func <=(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThanEqual(lhs: lhs, rhs: rhs)
	}
	static func >(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThan(lhs: lhs, rhs: rhs)
	}
	static func >=(lhs: CRUDExpression, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThanEqual(lhs: lhs, rhs: rhs)
	}
	static prefix func !(rhs: CRUDExpression) -> CRUDExpression {
		return .not(rhs: rhs)
	}
}

public extension CRUDExpression {
	static func ==(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .equality(lhs: .integer(lhs), rhs: rhs)
	}
	static func ==(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .equality(lhs: lhs, rhs: .integer(rhs))
	}
	static func ==(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .equality(lhs: .decimal(lhs), rhs: rhs)
	}
	static func ==(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .equality(lhs: lhs, rhs: .decimal(rhs))
	}
	static func ==(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .equality(lhs: .string(lhs), rhs: rhs)
	}
	static func ==(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .equality(lhs: lhs, rhs: .string(rhs))
	}
	
	static func !=(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .inequality(lhs: .integer(lhs), rhs: rhs)
	}
	static func !=(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .inequality(lhs: lhs, rhs: .integer(rhs))
	}
	static func !=(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .inequality(lhs: .decimal(lhs), rhs: rhs)
	}
	static func !=(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .inequality(lhs: lhs, rhs: .decimal(rhs))
	}
	static func !=(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .inequality(lhs: .string(lhs), rhs: rhs)
	}
	static func !=(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .inequality(lhs: lhs, rhs: .string(rhs))
	}
	
	static func <(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThan(lhs: .integer(lhs), rhs: rhs)
	}
	static func <(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .lessThan(lhs: lhs, rhs: .integer(rhs))
	}
	static func <(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThan(lhs: .decimal(lhs), rhs: rhs)
	}
	static func <(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .lessThan(lhs: lhs, rhs: .decimal(rhs))
	}
	static func <(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThan(lhs: .string(lhs), rhs: rhs)
	}
	static func <(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .lessThan(lhs: lhs, rhs: .string(rhs))
	}
	
	static func <=(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThanEqual(lhs: .integer(lhs), rhs: rhs)
	}
	static func <=(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .lessThanEqual(lhs: lhs, rhs: .integer(rhs))
	}
	static func <=(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThanEqual(lhs: .decimal(lhs), rhs: rhs)
	}
	static func <=(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .lessThanEqual(lhs: lhs, rhs: .decimal(rhs))
	}
	static func <=(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThanEqual(lhs: .string(lhs), rhs: rhs)
	}
	static func <=(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .lessThanEqual(lhs: lhs, rhs: .string(rhs))
	}
	
	static func >(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThan(lhs: .integer(lhs), rhs: rhs)
	}
	static func >(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .greaterThan(lhs: lhs, rhs: .integer(rhs))
	}
	static func >(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThan(lhs: .decimal(lhs), rhs: rhs)
	}
	static func >(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .greaterThan(lhs: lhs, rhs: .decimal(rhs))
	}
	static func >(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThan(lhs: .string(lhs), rhs: rhs)
	}
	static func >(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .greaterThan(lhs: lhs, rhs: .string(rhs))
	}
	
	static func >=(lhs: Int, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThanEqual(lhs: .integer(lhs), rhs: rhs)
	}
	static func >=(lhs: CRUDExpression, rhs: Int) -> CRUDExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .integer(rhs))
	}
	static func >=(lhs: Double, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThanEqual(lhs: .decimal(lhs), rhs: rhs)
	}
	static func >=(lhs: CRUDExpression, rhs: Double) -> CRUDExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .decimal(rhs))
	}
	static func >=(lhs: String, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThanEqual(lhs: .string(lhs), rhs: rhs)
	}
	static func >=(lhs: CRUDExpression, rhs: String) -> CRUDExpression {
		return .greaterThanEqual(lhs: lhs, rhs: .string(rhs))
	}
}

public extension CRUDExpression {
	static func == <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .equality(lhs: .keyPath(lhs), rhs: rhs)
	}
	static func != <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .inequality(lhs: .keyPath(lhs), rhs: rhs)
	}
	static func > <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThan(lhs: .keyPath(lhs), rhs: rhs)
	}
	static func >= <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .greaterThanEqual(lhs: .keyPath(lhs), rhs: rhs)
	}
	static func < <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThan(lhs: .keyPath(lhs), rhs: rhs)
	}
	static func <= <T: Codable>(lhs: PartialKeyPath<T>, rhs: CRUDExpression) -> CRUDExpression {
		return .lessThanEqual(lhs: .keyPath(lhs), rhs: rhs)
	}
}

extension CRUDExpression {
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
			if case .null = rhs {
				return "\(try lhs.sqlSnippet(state: state)) IS NULL"
			}
			return try bin(state, "=", lhs, rhs)
		case .inequality(let lhs, let rhs):
			if case .null = rhs {
				return "\(try lhs.sqlSnippet(state: state)) IS NOT NULL"
			}
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
				throw CRUDSQLGenError("Unable to get table for KeyPath root \(rootType).")
			}
			guard let keyName = try tableData.keyPathDecoder.getKeyPathName(modelInstance, keyPath: k) else {
				throw CRUDSQLGenError("Unable to get KeyPath name for table \(rootType).")
			}
			let nameQ = try delegate.quote(identifier: keyName)
			switch state.command {
			case .select, .count:
				let aliasQ = try delegate.quote(identifier: tableData.alias)
				return "\(aliasQ).\(nameQ)"
			case .insert, .update, .delete:
				return nameQ
			case .unknown:
				throw CRUDSQLGenError("Can not process unknown command.")
			}
		case .null:
			return "NULL"
		case .lazy(let e):
			return try e().sqlSnippet(state: state)
		case .integer(_), .decimal(_), .string(_), .blob(_), .bool(_), .uuid(_), .date(_):
			return try delegate.getBinding(for: self)
		}
	}
	private func bin(_ state: SQLGenState, _ op: String, _ lhs: CRUDExpression, _ rhs: CRUDExpression) throws -> String {
		return "\(try lhs.sqlSnippet(state: state)) \(op) \(try rhs.sqlSnippet(state: state))"
	}
	private func un(_ state: SQLGenState, _ op: String, _ rhs: CRUDExpression) throws -> String {
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
		case .integer(_), .decimal(_), .string(_), .blob(_), .bool(_), .uuid(_), .date(_):
			return []
		}
	}
}



