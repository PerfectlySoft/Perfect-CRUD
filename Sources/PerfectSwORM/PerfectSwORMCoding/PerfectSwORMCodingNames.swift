//
//  PerfectSwORMCodingNames.swift
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
	func appendKey(_ key: Key, _ type: Any.Type) {
		let s = key.stringValue
		if !knownKeys.contains(s) {
			parent.collectedKeys.append((s, type))
			knownKeys.insert(s)
		}
	}
	func contains(_ key: Key) -> Bool {
//		appendKey(key)
		return true
	}
	func decodeNil(forKey key: Key) throws -> Bool {
//		appendKey(key)
		return false
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		appendKey(key, type)
		return true
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		appendKey(key, type)
		return 0
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		appendKey(key, type)
		return ""
	}
	func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
		appendKey(key, type)
		let sub = SwORMColumnNameDecoder()
		parent.subTables.append((key.stringValue, sub))
		return try T(from: sub)
	}
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		fatalError("Unimplimented")
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		fatalError("Unimplimented")
	}
	func superDecoder() throws -> Decoder {
		fatalError("Unimplimented")
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		fatalError("Unimplimented")
	}
}

class SwORMColumnNameUnkeyedReader: UnkeyedDecodingContainer {
	let codingPath: [CodingKey] = []
	var count: Int? = 0
	var isAtEnd: Bool = true
	var currentIndex: Int = 0
	let parent: SwORMColumnNameDecoder
	init(parent p: SwORMColumnNameDecoder) {
		parent = p
	}
	func decodeNil() throws -> Bool {
		return true
	}
	
	func decode(_ type: Bool.Type) throws -> Bool {
		return false
	}
	
	func decode(_ type: Int.Type) throws -> Int {
		return 0
	}
	
	func decode(_ type: Int8.Type) throws -> Int8 {
		return 0
	}
	
	func decode(_ type: Int16.Type) throws -> Int16 {
		return 0
	}
	
	func decode(_ type: Int32.Type) throws -> Int32 {
		return 0
	}
	
	func decode(_ type: Int64.Type) throws -> Int64 {
		return 0
	}
	
	func decode(_ type: UInt.Type) throws -> UInt {
		return 0
	}
	
	func decode(_ type: UInt8.Type) throws -> UInt8 {
		return 0
	}
	
	func decode(_ type: UInt16.Type) throws -> UInt16 {
		return 0
	}
	
	func decode(_ type: UInt32.Type) throws -> UInt32 {
		return 0
	}
	
	func decode(_ type: UInt64.Type) throws -> UInt64 {
		return 0
	}
	
	func decode(_ type: Float.Type) throws -> Float {
		return 0
	}
	
	func decode(_ type: Double.Type) throws -> Double {
		return 0
	}
	
	func decode(_ type: String.Type) throws -> String {
		return ""
	}
	
	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		let sub = SwORMColumnNameDecoder()
		return try T(from: sub)
	}
	
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		fatalError("Unimplimented")
	}
	
	func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
		fatalError("Unimplimented")
	}
	
	func superDecoder() throws -> Decoder {
		return SwORMColumnNameDecoder()
	}
}

class SwORMColumnNameDecoder: Decoder {
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey : Any] = [:]
	var collectedKeys: [(String, Any.Type)] = []
	var subTables: [(String, SwORMColumnNameDecoder)] = []
	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
		return KeyedDecodingContainer<Key>(SwORMColumnNamesReader<Key>(self))
	}
	
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		return SwORMColumnNameUnkeyedReader(parent: self)
	}
	
	func singleValueContainer() throws -> SingleValueDecodingContainer {
		fatalError("Unimplimented")
	}
}
