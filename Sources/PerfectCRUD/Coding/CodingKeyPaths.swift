//
//  PerfectCRUDCodingKeyPaths.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-11-27.
//

import Foundation

class CRUDKeyPathsReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	let codingPath: [CodingKey] = []
	let allKeys: [Key] = []
	let parent: CRUDKeyPathsDecoder
	var counter: Int8 = 1
	var boolCounter: Int8 = 0
	init(_ p: CRUDKeyPathsDecoder) {
		parent = p
	}
	func contains(_ key: Key) -> Bool {
		return true
	}
	func decodeNil(forKey key: Key) throws -> Bool {
		return false
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		guard boolCounter < 2 else {
			throw CRUDDecoderError("This is lame, but your type has too many Bool properties.")
		}
		parent.typeMap[boolCounter] = key.stringValue
		boolCounter += 1
		return boolCounter == 2
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Int(counter)
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return counter
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Int16(counter)
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Int32(counter)
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Int64(counter)
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return UInt(counter)
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return UInt8(counter)
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return UInt16(counter)
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return UInt32(counter)
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return UInt64(counter)
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Float(counter)
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return Double(counter)
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		return "\(counter)"
	}
	func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
		counter += 1
		parent.typeMap[counter] = key.stringValue
		if let special = SpecialType(type) {
			switch special {
			case .uint8Array:
				return [UInt8(counter)] as! T
			case .int8Array:
				return [Int8(counter)] as! T
			case .data:
				return Data(bytes: [UInt8(counter)]) as! T
			case .uuid:
				return UUID(uuid: uuid_t(UInt8(counter),0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) as! T
			case .date:
				return Date(timeIntervalSinceReferenceDate: TimeInterval(counter)) as! T
			case .url:
				return URL(string: "http://localhost:\(counter)/")! as! T
			case .codable:
				let decoder = CRUDKeyPathsDecoder(depth: 1 + parent.depth)
				let decoded = try T(from: decoder)
				parent.subTypeMap.append((key.stringValue, type, decoder))
				return decoded
			}
		} else {
			let decoder = CRUDKeyPathsDecoder(depth: 1 + parent.depth)
			let decoded = try T(from: decoder)
			parent.subTypeMap.append((key.stringValue, type, decoder))
			return decoded
		}
	}
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		throw CRUDDecoderError("Unimplimented nestedContainer")
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("Unimplimented nestedUnkeyedContainer")
	}
	func superDecoder() throws -> Decoder {
		return parent
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		throw CRUDDecoderError("Unimplimented superDecoder")
	}
}

class CRUDKeyPathsUnkeyedReader: UnkeyedDecodingContainer, SingleValueDecodingContainer {
	let codingPath: [CodingKey] = []
	var count: Int? = 1
	var isAtEnd: Bool { return !(currentIndex < count ?? 0) }
	var currentIndex: Int = 0
	let parent: CRUDKeyPathsDecoder
	init(_ p: CRUDKeyPathsDecoder) {
		parent = p
	}
	func decodeNil() -> Bool {
		return false
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
		currentIndex += 1
		return try T(from: parent)
	}
	
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		throw CRUDDecoderError("Unimplimented nestedContainer")
	}
	
	func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("Unimplimented nestedUnkeyedContainer")
	}
	
	func superDecoder() throws -> Decoder {
		currentIndex += 1
		return parent
	}
}

class CRUDKeyPathsDecoder: Decoder {
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey : Any] = [:]
	var typeMap: [Int8:String] = [:]
	var subTypeMap: [(String, Decodable.Type, CRUDKeyPathsDecoder)] = []
	let depth: Int
	init(depth d: Int = 0) {
		depth = d
	}
	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		return KeyedDecodingContainer<Key>(CRUDKeyPathsReader<Key>(self))
	}
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		let r = CRUDKeyPathsUnkeyedReader(self)
		if depth > 0 {
			r.count = 0
		}
		return r
	}
	func singleValueContainer() throws -> SingleValueDecodingContainer {
		return CRUDKeyPathsUnkeyedReader(self)
	}
	func getKeyPathName(_ instance: Any, keyPath: AnyKeyPath) throws -> String? {
		guard let v = instance[keyPath: keyPath] else {
			return nil
		}
		return try getKeyPathName(fromValue: v)
	}
	private func getKeyPathName(fromValue v: Any) throws -> String? {
		switch v {
		case let b as Bool:
			return typeMap[b ? 1 : 0]
		case let s as String:
			guard let v = Int8(s) else {
				return nil
			}
			return typeMap[v]
		case let i as Int:
			return typeMap[Int8(i)]
		case let i as Int8:
			return typeMap[Int8(i)]
		case let i as Int16:
			return typeMap[Int8(i)]
		case let i as Int32:
			return typeMap[Int8(i)]
		case let i as Int64:
			return typeMap[Int8(i)]
		case let i as UInt:
			return typeMap[Int8(i)]
		case let i as UInt8:
			return typeMap[Int8(i)]
		case let i as UInt16:
			return typeMap[Int8(i)]
		case let i as UInt32:
			return typeMap[Int8(i)]
		case let i as UInt64:
			return typeMap[Int8(i)]
		case let i as Float:
			return typeMap[Int8(i)]
		case let i as Double:
			return typeMap[Int8(i)]
		case let o as Any?:
			guard let unType = o else {
				return nil
			}
			if let found = subTypeMap.first(where: { $0.1 == type(of: unType) }) {
				return found.0
			}
			if let special = SpecialType(type(of: unType)) {
				switch special {
				case .uint8Array:
					return typeMap[Int8((v as! [UInt8])[0])]
				case .int8Array:
					return typeMap[Int8((v as! [Int8])[0])]
				case .data:
					return typeMap[Int8((v as! Data).first!)]
				case .uuid:
					return typeMap[Int8((v as! UUID).uuid.0)]
				case .date:
					return typeMap[Int8((v as! Date).timeIntervalSinceReferenceDate)]
				case .url:
					return typeMap[Int8((v as! URL).port!)]
				case .codable:
					throw CRUDDecoderError("Unsupported operation on codable column.")
				}
			}
			return nil
		default:
			guard let found = subTypeMap.first(where: { $0.1 == type(of: v) }) else {
				return nil
			}
			return found.0
		}
	}
}
