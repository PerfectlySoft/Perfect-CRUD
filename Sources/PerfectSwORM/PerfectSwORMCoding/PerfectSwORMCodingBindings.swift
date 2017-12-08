//
//  PerfectSwORMCodingBindings.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-25.
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

// -- generates bindings for an object
class SwORMBindingsWriter<K : CodingKey>: KeyedEncodingContainerProtocol {
	typealias Key = K
	let codingPath: [CodingKey] = []
	let parent: SwORMBindingsEncoder
	init(_ p: SwORMBindingsEncoder) {
		parent = p
	}
	func addBinding(_ key: Key, value: Expression) throws {
		try parent.addBinding(key: key, value: value)
	}
	func encodeNil(forKey key: K) throws {
		// !FIX! this is never called
		// Expect this to change in the future
		// When nulls are important we have to use the column named decoder first
		// and pass in the list of optionals to SwORMBindingsEncoder
		SwORMLogging.log(.info, "SwORMBindingsWriter.encodeNil started being called.")
		//try addBinding(key, value: .null)
	}
	func encode(_ value: Bool, forKey key: K) throws {
		try addBinding(key, value: .bool(value))
	}
	func encode(_ value: Int, forKey key: K) throws {
		try addBinding(key, value: .integer(value))
	}
	func encode(_ value: Int8, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: Int16, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: Int32, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: Int64, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: UInt, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: UInt8, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: UInt16, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: UInt32, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: UInt64, forKey key: K) throws {
		try addBinding(key, value: .integer(Int(value)))
	}
	func encode(_ value: Float, forKey key: K) throws {
		try addBinding(key, value: .decimal(Double(value)))
	}
	func encode(_ value: Double, forKey key: K) throws {
		try addBinding(key, value: .decimal(value))
	}
	func encode(_ value: String, forKey key: K) throws {
		try addBinding(key, value: .string(value))
	}
	func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
		guard let special = SpecialType(T.self) else {
			throw SwORMEncoderError("Unsupported encoding type: \(value) for key: \(key.stringValue)")
		}
		switch special {
		case .uint8Array:
			try addBinding(key, value: .blob((value as! [UInt8])))
		case .int8Array:
			try addBinding(key, value: .blob((value as! [Int8]).map { UInt8($0) }))
		case .data:
			try addBinding(key, value: .blob((value as! Data).map { $0 }))
		case .uuid:
			try addBinding(key, value: .uuid(value as! UUID))
		case .date:
			try addBinding(key, value: .date(value as! Date))
		}
	}
	func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
		fatalError("Unimplimented")
	}
	func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
		fatalError("Unimplimented")
	}
	func superEncoder() -> Encoder {
		fatalError("Unimplimented")
	}
	func superEncoder(forKey key: K) -> Encoder {
		fatalError("Unimplimented")
	}
}

class SwORMBindingsEncoder: Encoder {
	let codingPath: [CodingKey] = []
	let userInfo: [CodingUserInfoKey : Any] = [:]
	let delegate: SQLGenDelegate
	private var collectedBinds: [(String, Expression)] = []
	
	init(delegate d: SQLGenDelegate) throws {
		delegate = d
	}
	
	func completedBindings(allKeys: [String],
						   ignoreKeys: Set<String>) throws -> [(column: String, identifier: String)] {
		let exprDict: [String:Expression] = .init(uniqueKeysWithValues: collectedBinds)
		let ret: [(column: String, identifier: String)] = try allKeys.map {
			key in
			let bindId: String
			if let expr = exprDict[key] {
				bindId = try delegate.getBinding(for: expr)
			} else {
				bindId = try delegate.getBinding(for: .null)
			}
			return (key, bindId)
		}
		return ret
	}
	
	func completedBindings(ignoreKeys: Set<String>) throws -> [(column: String, identifier: String)] {
		return try completedBindings(allKeys: collectedBinds.map { $0.0 }, ignoreKeys: ignoreKeys)
	}
	
	func addBinding<Key: CodingKey>(key: Key, value: Expression) throws {
		collectedBinds.append((key.stringValue, value))
	}
	func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
		return KeyedEncodingContainer<Key>(SwORMBindingsWriter<Key>(self))
	}
	func unkeyedContainer() -> UnkeyedEncodingContainer {
		fatalError("Unimplimented")
	}
	func singleValueContainer() -> SingleValueEncodingContainer {
		fatalError("Unimplimented")
	}
}




