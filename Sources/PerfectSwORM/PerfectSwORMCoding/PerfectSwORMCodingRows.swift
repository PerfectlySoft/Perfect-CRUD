//
//  PerfectSwORMCodingRows.swift
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

public class SwORMRowDecoder<K: CodingKey>: Decoder {
	public typealias Key = K
	public var codingPath: [CodingKey] = []
	public var userInfo: [CodingUserInfoKey:Any] = [:]
	let delegate: SQLExeDelegate
	public init(delegate d: SQLExeDelegate) {
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
