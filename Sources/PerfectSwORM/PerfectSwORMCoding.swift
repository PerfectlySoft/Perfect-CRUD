//
//  PerfectSwORMCoding.swift
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

struct SwORMDecoderError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
		SwORMLogging.log(.error, m)
	}
}
struct SwORMEncoderError: Error {
	let msg: String
	init(_ m: String) {
		msg = m
		SwORMLogging.log(.error, m)
	}
}

struct ColumnKey : CodingKey {
	public var stringValue: String
	public var intValue: Int?
	public init?(stringValue: String) {
		self.stringValue = stringValue
		self.intValue = nil
	}
	public init?(intValue: Int) {
		self.stringValue = "\(intValue)"
		self.intValue = intValue
	}
	init(index: Int) {
		self.stringValue = "Index \(index)"
		self.intValue = index
	}
}

public class SwORMDecoder<K: CodingKey>: Decoder {
	public typealias Key = K
	public var codingPath: [CodingKey] = []
	public var userInfo: [CodingUserInfoKey:Any] = [:]
	let delegate: SwORMExeDelegate
	init(delegate d: SwORMExeDelegate) {
		delegate = d
	}
	public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
		guard let next: KeyedDecodingContainer<Key> = try delegate.next() else {
			throw SwORMDecoderError("No row.")
		}
		return next
	}
	public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw SwORMDecoderError("Unimplimented")
	}
	public func singleValueContainer() throws -> SingleValueDecodingContainer {
		throw SwORMDecoderError("Unimplimented")
	}
}

// -- reads and records the coding keys for an object
class SwORMColumnNamesReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] = []
	var allKeys: [Key] = []
	var parent: SwORMColumnNameDecoder
	var knownKeys = Set<String>()
	init(_ p: SwORMColumnNameDecoder) {
		parent = p
	}
	func appendKey(_ key: Key) {
		let s = key.stringValue
		if !knownKeys.contains(s) {
			parent.collectedKeys.append(s)
			knownKeys.insert(s)
		}
	}
	func contains(_ key: Key) -> Bool {
		appendKey(key)
		return true
	}
	func decodeNil(forKey key: Key) throws -> Bool {
		appendKey(key)
		return true
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		appendKey(key)
		return true
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		appendKey(key)
		return 0
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		appendKey(key)
		return 0
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		appendKey(key)
		return 0
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		appendKey(key)
		return 0
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		appendKey(key)
		return 0
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		appendKey(key)
		return 0
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		appendKey(key)
		return 0
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		appendKey(key)
		return 0
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		appendKey(key)
		return 0
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		appendKey(key)
		return 0
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		appendKey(key)
		return 0
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		appendKey(key)
		return 0
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		appendKey(key)
		return ""
	}
	func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
		appendKey(key)
		fatalError("Unimplimented")
	}
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		appendKey(key)
		fatalError("Unimplimented")
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		appendKey(key)
		fatalError("Unimplimented")
	}
	func superDecoder() throws -> Decoder {
		fatalError("Unimplimented")
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		fatalError("Unimplimented")
	}
}

class SwORMColumnNameDecoder: Decoder {
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey : Any] = [:]
	var collectedKeys: [String] = []
	
	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
		return KeyedDecodingContainer<Key>(SwORMColumnNamesReader<Key>(self))
	}
	
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		fatalError("Unimplimented")
	}
	
	func singleValueContainer() throws -> SingleValueDecodingContainer {
		fatalError("Unimplimented")
	}
}

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


