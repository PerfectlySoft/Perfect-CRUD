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
		switch value {
		case let a as [Int8]:
			try addBinding(key, value: .blob(a.map { UInt8($0) }))
		case let a as [UInt8]:
			try addBinding(key, value: .blob(a))
		case let a as Data:
			try addBinding(key, value: .blob(a.map { $0 }))
		default:
			throw SwORMEncoderError("Unsupported encoding type: \(value) for key: \(key.stringValue)")
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
	let delegate: SwORMGenDelegate
	let ignoreKeys: [String]
	var bindIdentifiers: [String] = []
	var columnNames: [String] = []
	init(delegate d: SwORMGenDelegate, ignoreKeys i: [String] = []) {
		delegate = d
		ignoreKeys = i
	}
	func addBinding<Key: CodingKey>(key: Key, value: SwORMExpression) throws {
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
