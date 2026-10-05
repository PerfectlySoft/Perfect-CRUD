//
//  PerfectCRUDCreate.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-03.
//

import Foundation

public struct TableCreatePolicy: OptionSet, Sendable {
	public let rawValue: Int
	public init(rawValue r: Int) { rawValue = r }
	public static let shallow = TableCreatePolicy(rawValue: 1)
	public static let dropTable = TableCreatePolicy(rawValue: 2)
	public static let reconcileTable = TableCreatePolicy(rawValue: 4)
	
	public static let defaultPolicy: TableCreatePolicy = []
}

public class TableStructure {
	public class Column {
		public enum Property: Equatable {
			case primaryKey
			case foreignKey(String, String, ForeignKeyAction, ForeignKeyAction) // table, column, onDelete, onUpdate
		}
		public let name: String
		public let type: Any.Type
		public let optional: Bool
		public let properties: [Property]
		init(name: String,
			type: Any.Type,
			optional: Bool,
			properties: [Property]) {
			self.name = name
			self.type = type
			self.optional = optional
			self.properties = properties
		}
	}
	public let tableName: String
	public var primaryKeyName: String? { columns.first(where: { $0.properties.contains(.primaryKey) })?.name }
	public let columns: [Column]
	public var subTables: [TableStructure]
	public let indexes: [String]
	init(tableName: String,
		columns: [Column],
		subTables: [TableStructure],
		indexes: [String]) {
		self.tableName = tableName
		self.columns = columns
		self.subTables = subTables
		self.indexes = indexes
	}
}

public protocol WrappedCodableProvider: Codable {
	static func provideWrappedValueType() -> Codable.Type
	func provideWrappedValue() -> Codable
}

protocol PrimaryKeyWrapper: WrappedCodableProvider {}

// Lets type-erased code see through an Optional: a wrapper's `Value`, or a value boxed as
// `Codable`. Synthesized Codable decodes and encodes a property wrapper with
// `decode(_:forKey:)` / `encode(_:forKey:)` even when it wraps an Optional, so a wrapped
// Optional never reaches the `decodeIfPresent` / `encodeIfPresent` paths that plain
// optional properties take.
protocol CRUDOptional {
	static var crudWrappedType: Any.Type { get }
	static var crudNone: Self { get }
	var crudIsNil: Bool { get }
}

extension Optional: CRUDOptional {
	static var crudWrappedType: Any.Type { Wrapped.self }
	static var crudNone: Self { nil }
	// Nil at any level: `.some(nil)` of an `Int??` is a NULL column too.
	var crudIsNil: Bool {
		switch self {
		case .none: return true
		case .some(let wrapped): return (wrapped as? CRUDOptional)?.crudIsNil ?? false
		}
	}
}

@propertyWrapper
public struct PrimaryKey<Value: Codable>: PrimaryKeyWrapper, Codable {
	public static func provideWrappedValueType() -> Codable.Type { Value.self }
	public var wrappedValue: Value
	public var projectedValue: Value { wrappedValue }
	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
	public init(from decoder: Decoder) throws {
		wrappedValue = try decoder.singleValueContainer().decode(Value.self)
	}
	public func encode(to encoder: Encoder) throws {
		var c = encoder.singleValueContainer()
		try c.encode(wrappedValue)
	}
	public func provideWrappedValue() -> Codable {
		return wrappedValue
	}
}

public enum ForeignKeyAction: Sendable {
	case ignore, restrict, setNull, setDefault, cascade
}

public protocol ForeignKeyActionProvider {
	static var action: ForeignKeyAction { get }
}

public struct ForeignKeyActionIgnore: ForeignKeyActionProvider, Sendable {
	static public let action = ForeignKeyAction.ignore
}

public struct ForeignKeyActionRestrict: ForeignKeyActionProvider, Sendable {
	static public let action = ForeignKeyAction.restrict
}

public struct ForeignKeyActionSetNull: ForeignKeyActionProvider, Sendable {
	static public let action = ForeignKeyAction.setNull
}

public struct ForeignKeyActionSetDefault: ForeignKeyActionProvider, Sendable {
	static public let action = ForeignKeyAction.setDefault
}

public struct ForeignKeyActionCascade: ForeignKeyActionProvider, Sendable {
	static public let action = ForeignKeyAction.cascade
}

public let ignore = ForeignKeyActionIgnore()
public let restrict = ForeignKeyActionRestrict()
public let setNull = ForeignKeyActionSetNull()
public let setDefault = ForeignKeyActionSetDefault()
public let cascade = ForeignKeyActionCascade()

protocol ForeignKeyWrapper: WrappedCodableProvider {
	static func foreignKeyTarget() throws -> ForeignKeyTarget
	static func foreignKeyDeleteAction() -> ForeignKeyAction
	static func foreignKeyUpdateAction() -> ForeignKeyAction
}

@propertyWrapper
public struct ForeignKey<Table: Codable, DeleteAction: ForeignKeyActionProvider, UpdateAction: ForeignKeyActionProvider, Value: Codable>: ForeignKeyWrapper, Codable {
	public static func provideWrappedValueType() -> Codable.Type { Value.self }
	static func foreignKeyDeleteAction() -> ForeignKeyAction { DeleteAction.action }
	static func foreignKeyUpdateAction() -> ForeignKeyAction { UpdateAction.action }
	static func foreignKeyTarget() throws -> ForeignKeyTarget {
		return try Table.CRUDForeignKeyTarget()
	}
	
	public var wrappedValue: Value {
		get {
			guard let value = projectedValue ?? Self.unsetValue else {
				fatalError("ForeignKey<\(Table.self), \(Value.self)> read before a value was assigned.")
			}
			return value
		}
		set { projectedValue = newValue }
	}
	public var projectedValue: Value? = nil
	// What an optional `Value` reads as before anything is assigned: nil. A non-optional
	// `Value` has none.
	private static var unsetValue: Value? {
		(Value.self as? CRUDOptional.Type).map { $0.crudNone as! Value }
	}
	
	public init(_ parent: Table.Type, onDelete: DeleteAction, onUpdate: UpdateAction, wrappedValue: Value) {
		self.projectedValue = wrappedValue
	}
	public init(_ parent: Table.Type, onDelete: DeleteAction, onUpdate: UpdateAction) {
		
	}
	public init(from decoder: Decoder) throws {
		projectedValue = try decoder.singleValueContainer().decode(Value.self)
	}
	public func encode(to encoder: Encoder) throws {
		guard let value = projectedValue ?? Self.unsetValue else {
			throw EncodingError.invalidValue(Value.self, .init(codingPath: encoder.codingPath,
				debugDescription: "ForeignKey<\(Table.self), \(Value.self)> encoded before a value was assigned."))
		}
		var c = encoder.singleValueContainer()
		try c.encode(value)
	}
	public func provideWrappedValue() -> Codable {
		return wrappedValue
	}
	// A decoded value: `.some(nil)` for an optional `Value` decoded from a null or absent key,
	// as `init(from:)` gives for a null.
	init(decodedValue: Value) {
		self.projectedValue = decodedValue
	}
}

// Synthesized Codable decodes a property wrapper with `decode(_:forKey:)`, never
// `decodeIfPresent`, so an absent key threw `keyNotFound` for a wrapped Optional where a plain
// optional property decodes nil. These overloads are picked at the synthesized call site in
// the model's module for a wrapper around an Optional, and treat an absent key like a null.
// `decodeIfPresent` asks the container's `contains` and `decodeNil` and then calls its
// `decode`, so CRUD's own decoders and the connectors' row readers still see the column, as
// they do for a plain optional property. Encoding is unchanged: a nil value is written as an
// explicit null, which decodes back to nil.
extension KeyedDecodingContainer {
	public func decode<V: Codable>(_ type: PrimaryKey<V?>.Type, forKey key: Key) throws -> PrimaryKey<V?> {
		return try decodeIfPresent(type, forKey: key) ?? PrimaryKey(wrappedValue: nil)
	}
	public func decode<T, D, U, V: Codable>(_ type: ForeignKey<T, D, U, V?>.Type, forKey key: Key) throws -> ForeignKey<T, D, U, V?> {
		return try decodeIfPresent(type, forKey: key) ?? ForeignKey(decodedValue: nil)
	}
}

// What a foreign key column references: the target table's name and primary key column.
struct ForeignKeyTarget {
	let tableName: String
	let primaryKeyName: String?
}

// Guards all access to `tableStructureCache`, including the full compute-and-cache
// sequence below, not just the individual dictionary reads/writes. `CRUDTableStructure`
// recurses into itself on the same thread (via `ForeignKeyWrapper.foreignKeyTarget()`
// and `SubTable.tableStructure()`, for foreign-key references and nested sub-tables), so
// a non-recursive lock held across that computation would deadlock the first time a model
// has either. `NSRecursiveLock` permits that same-thread re-entry while still serializing
// distinct threads across the entire sequence — which also prevents a second thread from
// observing a `TableStructure` that's been published into the cache but not yet had its
// `subTables` filled in.
//
// Keyed by type identity, not by name: the type name is unqualified, so two distinct
// types with the same name (nested or function-local types in different scopes, or the
// same name in two modules) would otherwise share one cached structure.
//
// Only the canonical structure is cached: one computed for a top-level decoder
// (`depth == 0`) with no explicit primary key. A sub-table's structure is computed with a
// `depth >= 1` decoder, which truncates the sub-table's own arrays (see
// `CRUDColumnNameDecoder.unkeyedContainer()`), so it has no `subTables`; caching it would
// hand that truncated structure to a later top-level call. A structure computed for an
// explicit `primaryKey` (`create(primaryKey:)`) marks that column, not the default one, so
// it's never cached; only the foreign keys resolved while it's computed see that column
// (through `foreignKeyTargetsInProgress`, below). While one is in progress, nothing else is
// cached either: a structure computed then may have reached the explicit-key one through a
// foreign key. Those structures are kept in `explicitPrimaryKeyScope` instead, and dropped
// when the explicit-key computation ends, so one that's reached again during it isn't
// recomputed (a model whose foreign keys reach the same types along several paths would
// otherwise take exponential time). Sub-table computations neither read nor write the cache
// or the scope: their result is always computed fresh, so it matches what a cold cache gives.
//
// A foreign key column only needs its target's table name and primary key, so a top-level
// computation records those in `foreignKeyTargetsInProgress` before resolving its own
// columns or sub-tables. A foreign key cycle (a self-referencing column, two or more types
// referencing each other, or a sub-table referencing its parent) then finds the entry
// instead of recomputing the structure forever. The entry carries the primary key this
// computation uses, so with an explicit `primaryKey` that's what those foreign keys see.
private let tableStructureCacheLock = NSRecursiveLock()
nonisolated(unsafe) private var tableStructureCache: [ObjectIdentifier:TableStructure] = [:]
nonisolated(unsafe) private var foreignKeyTargetsInProgress: [ObjectIdentifier:ForeignKeyTarget] = [:]
nonisolated(unsafe) private var explicitPrimaryKeyScope: [ObjectIdentifier:TableStructure] = [:]
nonisolated(unsafe) private var explicitPrimaryKeyComputations = 0

// for tests
public func CRUDClearTableStructureCache() {
	tableStructureCacheLock.lock()
	defer { tableStructureCacheLock.unlock() }
	tableStructureCache.removeAll()
}

extension Decodable {
	static func CRUDForeignKeyTarget() throws -> ForeignKeyTarget {
		tableStructureCacheLock.lock()
		defer { tableStructureCacheLock.unlock() }
		if let target = foreignKeyTargetsInProgress[ObjectIdentifier(Self.self)] {
			return target
		}
		let structure = try CRUDTableStructure()
		return ForeignKeyTarget(tableName: structure.tableName, primaryKeyName: structure.primaryKeyName)
	}
	public static func CRUDTableStructure(primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let columnDecoder = CRUDColumnNameDecoder()
		columnDecoder.tableNamePath.append("\(Self.CRUDTableName)")
		_ = try Self.init(from: columnDecoder)
		return try CRUDTableStructure(columnDecoder: columnDecoder, primaryKey: primaryKey)
	}
	public static func CRUDTableStructure(columnDecoder: CRUDColumnNameDecoder, primaryKey: PartialKeyPath<Self>? = nil) throws -> TableStructure {
		let cacheKey = ObjectIdentifier(Self.self)
		let isTopLevel = columnDecoder.depth == 0
		let isCacheable = isTopLevel && primaryKey == nil
		tableStructureCacheLock.lock()
		defer { tableStructureCacheLock.unlock() }
		if isCacheable, let cached = explicitPrimaryKeyScope[cacheKey] ?? tableStructureCache[cacheKey] {
			return cached
		}
		let primaryKeyName: String?
		if let pkpk = primaryKey {
			let pathDecoder = CRUDKeyPathsDecoder()
			let pathInstance = try Self.init(from: pathDecoder)
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: pkpk) else {
				throw CRUDSQLGenError("Could not get column name for primary key \(Self.self).")
			}
			primaryKeyName = pkn
		} else if let key = columnDecoder.collectedKeys.filter({$0.type is PrimaryKeyWrapper.Type }).first {
			primaryKeyName = key.name
		} else if columnDecoder.collectedKeys.map({$0.0}).contains("id") {
			primaryKeyName = "id"
		} else {
			primaryKeyName = nil
		}
		let thisTableName = columnDecoder.tableNamePath.last!
		// Recorded before the columns are resolved; see `foreignKeyTargetsInProgress`.
		let previousTarget = foreignKeyTargetsInProgress[cacheKey]
		if isTopLevel {
			foreignKeyTargetsInProgress[cacheKey] = ForeignKeyTarget(tableName: thisTableName, primaryKeyName: primaryKeyName)
		}
		// Counted before the columns too: a type reached through a foreign key from them may
		// reference this explicit key, so it mustn't be cached either.
		if primaryKey != nil {
			explicitPrimaryKeyComputations += 1
		}
		defer {
			if isTopLevel {
				foreignKeyTargetsInProgress[cacheKey] = previousTarget
			}
			if primaryKey != nil {
				explicitPrimaryKeyComputations -= 1
				if explicitPrimaryKeyComputations == 0 {
					explicitPrimaryKeyScope.removeAll()
				}
			}
		}
		let tableStruct = TableStructure(
			tableName: thisTableName,
			columns: columnDecoder.collectedKeys.map {
				var props: [TableStructure.Column.Property] = []
				if $0.0 == primaryKeyName {
					props.append(.primaryKey)
				}
				if let foreignWrapper = $0.type as? ForeignKeyWrapper.Type,
					let target = try? foreignWrapper.foreignKeyTarget(),
					let foreignPK = target.primaryKeyName {
					props.append(.foreignKey(target.tableName, foreignPK, foreignWrapper.foreignKeyDeleteAction(), foreignWrapper.foreignKeyUpdateAction()))
				}
				var itype: Any.Type
				var optional = $0.optional
				if let wrapper = $0.type as? WrappedCodableProvider.Type {
					itype = wrapper.provideWrappedValueType()
					// The column decoder can't tell that a wrapper holds an Optional (see
					// `CRUDOptional`), so a wrapped Optional is a nullable column of its
					// `Wrapped` type.
					while let wrappedOptional = itype as? CRUDOptional.Type {
						itype = wrappedOptional.crudWrappedType
						optional = true
					}
				} else {
					itype = $0.type
				}
				return .init(name: $0.name, type: itype, optional: optional, properties: props)
			},
			subTables: [],
			indexes: [])
		// Published before filling in `subTables`, so that a sub-table reaching this type again
		// through a foreign key finds it instead of computing it again.
		if isCacheable {
			if explicitPrimaryKeyComputations == 0 {
				tableStructureCache[cacheKey] = tableStruct
			} else {
				explicitPrimaryKeyScope[cacheKey] = tableStruct
			}
		}
		tableStruct.subTables = try columnDecoder.subTables.filter { !$0.matches(Self.self) }.map {
			return try $0.tableStructure()
		}
		return tableStruct
	}
}

public struct Create<OAF: Codable, D: DatabaseProtocol> {
	typealias OverAllForm = OAF
	let fromDatabase: D
	let policy: TableCreatePolicy
	let tableStructure: TableStructure
	init(fromDatabase ft: D, primaryKey: PartialKeyPath<OAF>?, policy p: TableCreatePolicy) throws {
		fromDatabase = ft
		policy = p
		tableStructure = try OverAllForm.CRUDTableStructure(primaryKey: primaryKey)
		let delegate = fromDatabase.configuration.sqlGenDelegate
		let sql = try delegate.getCreateTableSQL(forTable: tableStructure, policy: policy)
		for stat in sql {
			CRUDLogging.log(.query, stat)
			let exeDelegate = try fromDatabase.configuration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
}

public struct Index<OAF: Codable, A: TableProtocol>: FromTableProtocol, TableProtocol {
	public typealias Form = OAF
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	init(fromTable ft: FromTableType, keys: [PartialKeyPath<FromTableType.Form>], unique: Bool) throws {
		fromTable = ft
		let delegate = ft.databaseConfiguration.sqlGenDelegate
		let tableName = "\(OverAllForm.CRUDTableName)"
		let pathDecoder = CRUDKeyPathsDecoder()
		let pathInstance = try OverAllForm.init(from: pathDecoder)
		let keyNames: [String] = try keys.map {
			guard let pkn = try pathDecoder.getKeyPathName(pathInstance, keyPath: $0) else {
				throw CRUDSQLGenError("Could not get column name for index \(OverAllForm.self).")
			}
			return pkn
		}
		let sql = try delegate.getCreateIndexSQL(forTable: tableName, on: keyNames, unique: unique)
		for stat in sql {
			CRUDLogging.log(.query, stat)
			let exeDelegate = try ft.databaseConfiguration.sqlExeDelegate(forSQL: stat)
			_ = try exeDelegate.hasNext()
		}
	}
	public func setState(state: inout SQLGenState) throws {}
	public func setSQL(state: inout SQLGenState) throws {}
}

public extension DatabaseProtocol {
	@discardableResult
	func create<A: Codable>(_ type: A.Type, policy: TableCreatePolicy = .defaultPolicy) throws -> Table<A, Self> {
		let _: Create<A, Self> = try Create(fromDatabase: self, primaryKey: nil, policy: policy)
		return Table(database: self)
	}
	@discardableResult
	func create<A: Codable, V: Equatable>(_ type: A.Type, primaryKey: KeyPath<A, V>? = nil, policy: TableCreatePolicy = .defaultPolicy) throws -> Table<A, Self> {
		let _: Create<A, Self> = try Create(fromDatabase: self, primaryKey: primaryKey, policy: policy)
		return Table(database: self)
	}
}

public extension Table {
	@discardableResult
	func index(unique: Bool = false, _ keys: PartialKeyPath<OverAllForm>...) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: keys, unique: unique)
	}
	// !FIX! Swift 4.0.2 seems to have a problem with type inference for the above func
	// would not let \.name type references to be used
	// this is an ugly work around
	@discardableResult
	func index<V1: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable, V4: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3, key4], unique: unique)
	}
	@discardableResult
	func index<V1: Equatable, V2: Equatable, V3: Equatable, V4: Equatable, V5: Equatable>(unique: Bool = false, _ key: KeyPath<OverAllForm, V1>, _ key2: KeyPath<OverAllForm, V2>, _ key3: KeyPath<OverAllForm, V3>, _ key4: KeyPath<OverAllForm, V4>, _ key5: KeyPath<OverAllForm, V5>) throws -> Index<OverAllForm, Table> {
		return try .init(fromTable: self, keys: [key, key2, key3, key4, key5], unique: unique)
	}
}

