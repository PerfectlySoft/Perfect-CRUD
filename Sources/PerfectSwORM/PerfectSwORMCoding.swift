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

class SwORMColumnNamesReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] {
		return []
	}
	var allKeys: [Key] {
		return []
	}
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



