//
//  Comparison.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2018-02-18.
//

import Foundation

// <
public func < <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UInt>, rhs: UInt) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uinteger(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Int64>, rhs: Int64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer64(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UInt64>, rhs: UInt64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uinteger64(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Int32>, rhs: Int32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer32(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UInt32>, rhs: UInt32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uinteger32(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Int16>, rhs: Int16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer16(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UInt16>, rhs: UInt16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uinteger16(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, Int8>, rhs: Int8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .integer8(rhs)))
}
public func < <A: Codable>(lhs: KeyPath<A, UInt8>, rhs: UInt8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .uinteger8(rhs)))
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
public func < <A: Codable>(lhs: KeyPath<A, Date>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThan(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// >
public func > <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UInt>, rhs: UInt) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uinteger(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Int64>, rhs: Int64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer64(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UInt64>, rhs: UInt64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uinteger64(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Int32>, rhs: Int32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer32(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UInt32>, rhs: UInt32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uinteger32(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Int16>, rhs: Int16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer16(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UInt16>, rhs: UInt16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uinteger16(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, Int8>, rhs: Int8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .integer8(rhs)))
}
public func > <A: Codable>(lhs: KeyPath<A, UInt8>, rhs: UInt8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .uinteger8(rhs)))
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
public func > <A: Codable>(lhs: KeyPath<A, Date>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThan(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// <=
public func <= <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UInt>, rhs: UInt) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uinteger(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Int64>, rhs: Int64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer64(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UInt64>, rhs: UInt64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uinteger64(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Int32>, rhs: Int32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer32(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UInt32>, rhs: UInt32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uinteger32(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Int16>, rhs: Int16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer16(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UInt16>, rhs: UInt16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uinteger16(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, Int8>, rhs: Int8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .integer8(rhs)))
}
public func <= <A: Codable>(lhs: KeyPath<A, UInt8>, rhs: UInt8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .uinteger8(rhs)))
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
public func <= <A: Codable>(lhs: KeyPath<A, Date>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.lessThanEqual(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
// >=
public func >= <A: Codable>(lhs: KeyPath<A, Int>, rhs: Int) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UInt>, rhs: UInt) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uinteger(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Int64>, rhs: Int64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer64(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UInt64>, rhs: UInt64) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uinteger64(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Int32>, rhs: Int32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer32(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UInt32>, rhs: UInt32) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uinteger32(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Int16>, rhs: Int16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer16(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UInt16>, rhs: UInt16) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uinteger16(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, Int8>, rhs: Int8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .integer8(rhs)))
}
public func >= <A: Codable>(lhs: KeyPath<A, UInt8>, rhs: UInt8) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .uinteger8(rhs)))
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
public func >= <A: Codable>(lhs: KeyPath<A, Date>, rhs: Date) -> CRUDBooleanExpression {
	return RealBooleanExpression(.greaterThanEqual(lhs: .keyPath(lhs), rhs: .date(rhs)))
}
