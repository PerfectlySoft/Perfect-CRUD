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
		return try parent.countBool(key)
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		return Int(parent.countKey(key))
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		return parent.countKey(key)
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		return Int16(parent.countKey(key))
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		return Int32(parent.countKey(key))
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		return Int64(parent.countKey(key))
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		return UInt(parent.countKey(key))
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		return UInt8(parent.countKey(key))
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		return UInt16(parent.countKey(key))
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		return UInt32(parent.countKey(key))
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		return UInt64(parent.countKey(key))
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		return Float(parent.countKey(key))
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		return Double(parent.countKey(key))
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		return "\(parent.countKey(key))"
	}
	func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
		if type is WrappedCodableProvider.Type {
			parent.wrappedKey = key
			let decoded = try T(from: parent)
			defer {
				parent.wrappedKey = nil
			}
			return decoded
		}
		let counter = parent.countKey(key)
		if let special = SpecialType(type) {
			switch special {
			case .uint8Array:
				return [UInt8(counter)] as! T
			case .int8Array:
				return [Int8(counter)] as! T
			case .data:
				return Data([UInt8(counter)]) as! T
			case .uuid:
				return UUID(uuid: uuid_t(UInt8(counter),0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) as! T
			case .date:
				return Date(timeIntervalSinceReferenceDate: TimeInterval(counter)) as! T
			case .url:
				return URL(string: "http://localhost:\(counter)/")! as! T
			case .codable:
				let decoder = parent.childDecoder(for: key)
				let decoded = try T(from: decoder)
				parent.subTypeMap.append((key.stringValue, type, decoder))
				return decoded
			case .wrapped:
				throw CRUDDecoderError("Unhandled decode type \(type)")
			}
		} else {
			let decoder = parent.childDecoder(for: key)
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
	let wrappedKey: CodingKey
	
	init(_ p: CRUDKeyPathsDecoder, key: CodingKey) {
		wrappedKey = key
		parent = p
	}
	
	func decodeNil() -> Bool {
		return false
	}
	
	func decode(_ type: Bool.Type) throws -> Bool {
		return try parent.countBool(wrappedKey)
	}
	
	func decode(_ type: Int.Type) throws -> Int {
		return Int(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Int8.Type) throws -> Int8 {
		return Int8(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Int16.Type) throws -> Int16 {
		return Int16(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Int32.Type) throws -> Int32 {
		return Int32(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Int64.Type) throws -> Int64 {
		return Int64(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: UInt.Type) throws -> UInt {
		return UInt(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: UInt8.Type) throws -> UInt8 {
		return UInt8(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: UInt16.Type) throws -> UInt16 {
		return UInt16(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: UInt32.Type) throws -> UInt32 {
		return UInt32(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: UInt64.Type) throws -> UInt64 {
		return UInt64(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Float.Type) throws -> Float {
		return Float(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: Double.Type) throws -> Double {
		return Double(parent.countKey(wrappedKey))
	}
	
	func decode(_ type: String.Type) throws -> String {
		return "\(parent.countKey(wrappedKey))"
	}
	
	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		// this is being called in some cases for primitive types like Int
		// 	instead of the proper funtion above
		switch type {
		case let t as Bool.Type: return try decode(t) as! T
		case let t as Int.Type: return try decode(t) as! T
		case let t as Int8.Type: return try decode(t) as! T
		case let t as Int16.Type: return try decode(t) as! T
		case let t as Int32.Type: return try decode(t) as! T
		case let t as Int64.Type: return try decode(t) as! T
		case let t as UInt.Type: return try decode(t) as! T
		case let t as UInt8.Type: return try decode(t) as! T
		case let t as UInt16.Type: return try decode(t) as! T
		case let t as UInt32.Type: return try decode(t) as! T
		case let t as UInt64.Type: return try decode(t) as! T
		case let t as Float.Type: return try decode(t) as! T
		case let t as Double.Type: return try decode(t) as! T
		case let t as String.Type: return try decode(t) as! T
		default: ()
		}
		currentIndex += 1
		let counter = parent.countKey(wrappedKey)
		if let special = SpecialType(type) {
			switch special {
			case .uint8Array:
				return [UInt8(counter)] as! T
			case .int8Array:
				return [Int8(counter)] as! T
			case .data:
				return Data([UInt8(counter)]) as! T
			case .uuid:
				return UUID(uuid: uuid_t(UInt8(counter),0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) as! T
			case .date:
				return Date(timeIntervalSinceReferenceDate: TimeInterval(counter)) as! T
			case .url:
				return URL(string: "http://localhost:\(counter)/")! as! T
			case .codable:
				let decoder = parent.childDecoder(for: wrappedKey)
				let decoded = try T(from: decoder)
				parent.subTypeMap.append((wrappedKey.stringValue, type, decoder))
				return decoded
			case .wrapped:
				throw CRUDDecoderError("Unhandled decode type \(type)")
			}
		} else {
			let decoder = parent.childDecoder(for: wrappedKey)
			let decoded = try T(from: decoder)
			parent.subTypeMap.append((wrappedKey.stringValue, type, decoder))
			return decoded
		}
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

class MyUnkeyedDecodingContainer: UnkeyedDecodingContainer {
	var codingPath: [CodingKey] = []
	var count: Int? = 0
	var isAtEnd: Bool = true
	var currentIndex: Int = 0
	
	func decodeNil() throws -> Bool {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Bool.Type) throws -> Bool {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: String.Type) throws -> String {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Double.Type) throws -> Double {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Float.Type) throws -> Float {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Int.Type) throws -> Int {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Int8.Type) throws -> Int8 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Int16.Type) throws -> Int16 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Int32.Type) throws -> Int32 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: Int64.Type) throws -> Int64 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: UInt.Type) throws -> UInt {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: UInt8.Type) throws -> UInt8 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: UInt16.Type) throws -> UInt16 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: UInt32.Type) throws -> UInt32 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode(_ type: UInt64.Type) throws -> UInt64 {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
	
	func superDecoder() throws -> Decoder {
		throw CRUDDecoderError("MyUnkeyedDecodingContainer zero count")
	}
}

public class CRUDKeyPathsDecoder: Decoder {
	public var codingPath: [CodingKey] = []
	public var userInfo: [CodingUserInfoKey : Any] = [:]
	var counter: Int8 = 1
	var boolCounter: Int8 = 0
	var typeMap: [Int8:String] = [:]
	var subTypeMap: [(String, Decodable.Type, CRUDKeyPathsDecoder)] = []
	let depth: Int
	var wrappedKey: CodingKey?
	// Only set on the throwaway decoders that build the probe instances in
	// `probe(_:_:)`. A skewed decoder hands out a different value for every key
	// than an ordinary decoder would, so comparing a key path's leaf with the
	// probe's tells us which decoder produced it.
	enum Skew: Hashable {
		case none
		// Every decoder at this depth or deeper, shifting values down...
		case fromDepth(Int)
		// ...or up.
		case upFromDepth(Int)
		// Every decoder below the given top-level property.
		case subtree(String)
	}
	let skew: Skew
	
	init(depth d: Int = 0) {
		depth = d
		skew = .none
	}
	
	private init(depth d: Int, skew s: Skew) {
		depth = d
		skew = s
	}
	
	private var isSkewed: Bool {
		switch skew {
		case .none, .subtree: return false
		case .fromDepth(let d), .upFromDepth(let d): return depth >= d
		}
	}
	
	func childDecoder(for key: CodingKey) -> CRUDKeyPathsDecoder {
		if depth == 0, case .subtree(let name) = skew {
			return CRUDKeyPathsDecoder(depth: 1, skew: name == key.stringValue ? .fromDepth(1) : .none)
		}
		return CRUDKeyPathsDecoder(depth: 1 + depth, skew: skew)
	}
	
	func countKey(_ key: CodingKey) -> Int8 {
		counter += 1
		typeMap[counter] = key.stringValue
		// counter starts at 2, so a skewed value is always >= 1 and stays
		// valid for the UInt8/UUID/Data/URL encodings in the readers above.
		guard isSkewed else {
			return counter
		}
		if case .upFromDepth = skew, counter < Int8.max {
			return counter + 1
		}
		return counter - 1
	}
	
	func countBool(_ key: CodingKey) throws -> Bool {
		guard boolCounter < 2 else {
			throw CRUDDecoderError("Perfect-CRUD table types can have up to two Bool properties. Try using small ints (Int8) with bool 'var' accessors.")
		}
		typeMap[boolCounter] = key.stringValue
		boolCounter += 1
		return isSkewed ? boolCounter != 2 : boolCounter == 2
	}
	
	public func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		return KeyedDecodingContainer<Key>(CRUDKeyPathsReader<Key>(self))
	}
	public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		return MyUnkeyedDecodingContainer()
	}
	public func singleValueContainer() throws -> SingleValueDecodingContainer {
		guard let wrappedKey = self.wrappedKey else {
			throw CRUDDecoderError("No wrappedKey waiting for unkeyedContainer")
		}
		return CRUDKeyPathsUnkeyedReader(self, key: wrappedKey)
	}
	public func getKeyPathName(_ instance: Any, keyPath: AnyKeyPath) throws -> String? {
		guard let v = instance[keyPath: keyPath] else {
			return nil
		}
		guard subTypeMap.contains(where: { $0.2.producedValues }),
			let modelType = type(of: instance) as? Decodable.Type else {
			// No nested decoder produced anything, so every leaf is top-level.
			return try getKeyPathName(fromValue: v)
		}
		let key = ResolutionKey(type: ObjectIdentifier(modelType), keyPath: keyPath)
		let resolution: Resolution
		if let cached = Self.cachedResolution(key) {
			resolution = cached
		} else {
			resolution = resolve(modelType, keyPath: keyPath, value: v)
			Self.cacheResolution(key, resolution)
		}
		switch resolution {
		case .byValue:
			return try getKeyPathName(fromValue: v)
		case .column(let name):
			return name
		case .nested:
			throw CRUDSQLGenError("Key path \(keyPath) does not refer to a top-level property of \(type(of: instance)). Key paths through a nested Codable property or an optional chain (e.g. \\T.sub?.x) can't be mapped to a column.")
		case .undecoded:
			throw CRUDSQLGenError("Key path \(keyPath) does not refer to a column of \(type(of: instance)): it isn't a property that init(from:) decodes.")
		}
	}
	
	// Names are found by value, and every nested Codable property is decoded
	// by a child decoder whose counter starts over. So `\T.sub?.x` yields the
	// same value as T's first column and would silently resolve to it. Only
	// top-level properties are columns, so reject anything decoded deeper.
	//
	// The leaf is compared with the same key path on probe instances of the
	// model in which some decoders hand out different values:
	// - A scalar leaf is top-level only if it's unchanged when every nested
	//   decoder is skewed.
	// - A Codable leaf is matched by type, and may match several columns. It
	//   is column N only if skewing everything decoded under N changes some
	//   value inside the leaf. If skewing every nested decoder changes it but
	//   no candidate column does, it came from deeper in the model.
	// A scalar leaf that differs between two plain decodes (an undecoded
	// `let id = UUID()`) or that no skew changes (an undecoded constant)
	// isn't a column at all. Inside a Codable leaf such values are ignored.
	// When nothing can be told (no decoded
	// value under the leaf, or a probe can't be decoded because a nested
	// init(from:) rejects the skewed values) the name is found by value, as
	// before. The result depends only on the model type and key path, so it's
	// cached; this assumes init(from:) decodes the same shape every time.
	enum Resolution {
		case byValue, column(String), nested, undecoded
	}
	
	private func resolve(_ modelType: Decodable.Type, keyPath: AnyKeyPath, value v: Any) -> Resolution {
		guard let control = Self.probe(modelType, .none)?[keyPath: keyPath] else {
			return .byValue
		}
		if let code = Self.scalarIdentity(v) {
			func probed(_ skew: Skew) -> AnyHashable?? {
				return Self.probe(modelType, skew).map { Self.scalarIdentity($0[keyPath: keyPath] as Any) }
			}
			// A value no decoder produced differs between plain decodes (a
			// random default), or survives skewing every decoder both ways (a
			// constant). Bools only have two values, so a derived Bool (say,
			// false whenever `deletedAt` is set) can't be told from a constant;
			// they're left to the by-value lookup.
			if Self.scalarIdentity(control) != code {
				return .undecoded
			}
			// If the model rejects whole-model skews (it validates a decoded
			// field), skip this and still run the nested check below.
			if !(Self.unwrapped(v) is Bool),
				let down = probed(.fromDepth(0)), let up = probed(.upFromDepth(0)),
				down == code && up == code {
				return .undecoded
			}
			// Top-level values aren't touched by skewing nested decoders. Two
			// directions keep a nested value that a clamp or mask maps back to
			// the same thing from slipping through.
			let nestedDown = probed(.fromDepth(1))
			let nestedUp = probed(.upFromDepth(1))
			if let d = nestedDown, d != code {
				return .nested
			}
			if let u = nestedUp, u != code {
				return .nested
			}
			return .byValue
		}
		let leafType = type(of: Self.unwrapped(v))
		let candidates = subTypeMap.filter { $0.1 == leafType }.map { $0.0 }
		let mine = Self.deepCodes(v)
		let theirs = Self.deepCodes(control)
		guard mine.count == theirs.count else {
			return .byValue
		}
		let stable = mine.indices.filter { mine[$0] != nil && mine[$0] == theirs[$0] }
		func changes(_ skew: Skew) -> Bool? {
			guard let p = Self.probe(modelType, skew)?[keyPath: keyPath] else {
				return nil
			}
			let probed = Self.deepCodes(p)
			guard probed.count == mine.count else {
				return nil
			}
			return stable.contains { probed[$0] != mine[$0] }
		}
		guard changes(.fromDepth(1)) == true else {
			return .byValue
		}
		// Decoded below the top level; no column of this type means nested.
		var undecided = false
		for name in candidates {
			switch changes(.subtree(name)) {
			case true?: return .column(name)
			case nil: undecided = true
			case false?: continue
			}
		}
		return undecided ? .byValue : .nested
	}
	
	private var producedValues: Bool {
		return counter > 1 || boolCounter > 0 || subTypeMap.contains { $0.2.producedValues }
	}
	
	// Probes and resolutions depend only on the model type, so they're shared.
	// Both are built outside the lock: building a probe runs the model's
	// init(from:), which may itself resolve key paths. A race just builds the
	// same thing twice.
	private final class ProbeBox: @unchecked Sendable {
		let value: Any?
		init(_ v: Any?) { value = v }
	}
	private struct ProbeKey: Hashable {
		let type: ObjectIdentifier
		let skew: Skew
	}
	private struct ResolutionKey: Hashable, @unchecked Sendable {
		let type: ObjectIdentifier
		let keyPath: AnyKeyPath
	}
	private static let cacheLock = NSLock()
	nonisolated(unsafe) private static var probes: [ProbeKey: ProbeBox] = [:]
	nonisolated(unsafe) private static var resolutions: [ResolutionKey: Resolution] = [:]
	
	private static func probe(_ type: Decodable.Type, _ skew: Skew) -> Any? {
		let key = ProbeKey(type: ObjectIdentifier(type), skew: skew)
		cacheLock.lock()
		let cached = probes[key]
		cacheLock.unlock()
		if let cached {
			return cached.value
		}
		let made = try? type.init(from: CRUDKeyPathsDecoder(depth: 0, skew: skew))
		cacheLock.lock()
		probes[key] = ProbeBox(made)
		cacheLock.unlock()
		return made
	}
	
	private static func cachedResolution(_ key: ResolutionKey) -> Resolution? {
		cacheLock.lock()
		defer { cacheLock.unlock() }
		return resolutions[key]
	}
	
	private static func cacheResolution(_ key: ResolutionKey, _ resolution: Resolution) {
		cacheLock.lock()
		defer { cacheLock.unlock() }
		resolutions[key] = resolution
	}
	
	// The counter a scalar leaf was built from (see the readers above), or nil
	// if the value isn't one of the scalar kinds those readers produce.
	private static func scalarCode(_ v: Any) -> Int? {
		switch v {
		case let b as Bool:
			return b ? 1 : 0
		case let s as String:
			return Int(s)
		case let i as any BinaryInteger:
			return Int(truncatingIfNeeded: i)
		case let f as Float:
			return Int(exactly: f.rounded())
		case let d as Double:
			return Int(exactly: d.rounded())
		case let a as [UInt8]:
			return a.first.map(Int.init)
		case let a as [Int8]:
			return a.first.map(Int.init)
		case let d as Data:
			return d.first.map(Int.init)
		case let u as UUID:
			return Int(u.uuid.0)
		case let d as Date:
			return Int(exactly: d.timeIntervalSinceReferenceDate.rounded())
		case let u as URL:
			return u.port
		default:
			return nil
		}
	}
	
	// A scalar value itself, for comparing a leaf with its probes. Comparing
	// whole values rather than codes keeps an undecoded random value (a
	// UUID, say) from matching by chance.
	private static func scalarIdentity(_ v: Any) -> AnyHashable? {
		guard scalarCode(v) != nil else {
			return nil
		}
		return v as? AnyHashable
	}
	
	// The scalar values stored under `v`, depth first. Only positions matter:
	// all callers compare values of the same type.
	private static func deepCodes(_ v: Any) -> [AnyHashable?] {
		var codes: [AnyHashable?] = []
		func walk(_ value: Any, _ level: Int) {
			for field in fields(of: value) {
				let code = scalarIdentity(field)
				codes.append(code)
				if code == nil, level < 16 {
					walk(field, level + 1)
				}
			}
		}
		walk(v, 0)
		return codes
	}
	
	private static func unwrapped(_ v: Any) -> Any {
		var value = v
		var mirror = Mirror(reflecting: value)
		while mirror.displayStyle == .optional, let wrapped = mirror.children.first {
			value = wrapped.value
			mirror = Mirror(reflecting: value)
		}
		return value
	}
	
	private static func fields(of v: Any) -> [Any] {
		let value = unwrapped(v)
		var values: [Any] = []
		var current: Mirror? = Mirror(reflecting: value)
		while let m = current {
			values += m.children.map { $0.value }
			current = m.superclassMirror
		}
		return values
	}
	
	// Values that no reader produced (an undecoded `let id = UUID()`, say)
	// can be out of Int8's range; they name nothing rather than trapping.
	private func name<N: BinaryInteger>(forCode n: N) -> String? {
		return Int8(exactly: n).flatMap { typeMap[$0] }
	}
	
	private func name<F: BinaryFloatingPoint>(forCode f: F) -> String? {
		return f.isFinite ? Int8(exactly: f.rounded(.towardZero)).flatMap { typeMap[$0] } : nil
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
			return name(forCode: i)
		case let i as Int8:
			return name(forCode: i)
		case let i as Int16:
			return name(forCode: i)
		case let i as Int32:
			return name(forCode: i)
		case let i as Int64:
			return name(forCode: i)
		case let i as UInt:
			return name(forCode: i)
		case let i as UInt8:
			return name(forCode: i)
		case let i as UInt16:
			return name(forCode: i)
		case let i as UInt32:
			return name(forCode: i)
		case let i as UInt64:
			return name(forCode: i)
		case let i as Float:
			return name(forCode: i)
		case let i as Double:
			return name(forCode: i)
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
					return (v as! [UInt8]).first.flatMap(name(forCode:))
				case .int8Array:
					return (v as! [Int8]).first.flatMap(name(forCode:))
				case .data:
					return (v as! Data).first.flatMap(name(forCode:))
				case .uuid:
					return name(forCode: (v as! UUID).uuid.0)
				case .date:
					return name(forCode: (v as! Date).timeIntervalSinceReferenceDate)
				case .url:
					return (v as! URL).port.flatMap(name(forCode:))
				case .codable, .wrapped:
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
