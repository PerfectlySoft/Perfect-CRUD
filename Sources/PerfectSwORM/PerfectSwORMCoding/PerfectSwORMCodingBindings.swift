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
	func addBinding(_ key: Key, value: SwORMExpression) throws {
		try parent.addBinding(key: key, value: value)
	}
	func encodeNil(forKey key: K) throws {
		try addBinding(key, value: .null)
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
	let ignoreKeys: Set<String>
	let includeKeys: Set<String>
	var bindIdentifiers: [String] = []
	var columnNames: [String] = []
	init(delegate d: SQLGenDelegate, ignoreKeys ignore: Set<String> = Set(), includeKeys include: Set<String> = Set()) {
		delegate = d
		ignoreKeys = ignore
		includeKeys = include
	}
	func addBinding<Key: CodingKey>(key: Key, value: SwORMExpression) throws {
		guard includeKeys.isEmpty || includeKeys.contains(key.stringValue) else {
			return
		}
		guard ignoreKeys.isEmpty || !ignoreKeys.contains(key.stringValue) else {
			return
		}
		bindIdentifiers.append(try delegate.getBinding(for: value))
		columnNames.append(key.stringValue)
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
