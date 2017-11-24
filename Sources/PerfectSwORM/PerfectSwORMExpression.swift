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
	
	case column(name: String)
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
	
	case integer(Int)
	case decimal(Double)
	case string(String)
	case blob([UInt8])
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





