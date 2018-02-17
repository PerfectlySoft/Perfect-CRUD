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

public protocol CRUDBooleanExpression {
	var crudExpression: CRUDExpression { get }
}

private struct RealBooleanExpression: CRUDBooleanExpression {
	let crudExpression: CRUDExpression
	init(_ e: CRUDExpression) {
		crudExpression = e
	}
}

// ==
public func == <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func == <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// == ?
public func == <A: Codable>(lhs: KeyPath<A, Int?>, rhs: Int?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .integer(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, String?>, rhs: String?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .string(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, Double?>, rhs: Double?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, [UInt8]?>, rhs: [UInt8]?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .blob(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, Bool?>, rhs: Bool?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .bool(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, UUID?>, rhs: UUID?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
public func == <A: Codable>(lhs: KeyPath<A, UUID?>, rhs: Date?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .date(rhs)))
	}
	return RealBooleanExpression(.equality(lhs: .keyPath(lhs), rhs: .null))
}
// !=
public func != <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func != <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// != ?
public func != <A: Codable>(lhs: KeyPath<A, Int?>, rhs: Int?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .integer(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, String?>, rhs: String?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .string(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, Double?>, rhs: Double?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, [UInt8]?>, rhs: [UInt8]?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .blob(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, Bool?>, rhs: Bool?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .bool(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, UUID?>, rhs: UUID?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
public func != <A: Codable>(lhs: KeyPath<A, UUID?>, rhs: Date?) -> CRUDBooleanExpression {
	if let rhs = rhs {
		return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .date(rhs)))
	}
	return RealBooleanExpression(.inequality(lhs: .keyPath(lhs), rhs: .null))
}
// <
public func < <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// >
public func > <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// <=
public func <= <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// >=
public func >= <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, String>, rhs: String) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .string(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Double>, rhs: Double) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .decimal(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, [UInt8]>, rhs: [UInt8]) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .blob(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Bool>, rhs: Bool) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .bool(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UUID>, rhs: UUID) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uuid(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UUID>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// &&
public func && (lhs: CRUDBooleanExpression, rhs: CRUDBooleanExpression) -> CRUDBooleanExpression {
	return RealBooleanExpression(.and(lhs: lhs.crudExpression, rhs: rhs.crudExpression))
}
// ||
public func || (lhs: CRUDBooleanExpression, rhs: CRUDBooleanExpression) -> CRUDBooleanExpression {
	return RealBooleanExpression(.or(lhs: lhs.crudExpression, rhs: rhs.crudExpression))
}
// !
public prefix func ! (rhs: CRUDBooleanExpression) -> CRUDBooleanExpression {
	return RealBooleanExpression(.not(rhs: rhs.crudExpression))
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
			return "NOT (\(rhsStr))"
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



