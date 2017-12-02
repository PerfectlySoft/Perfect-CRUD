//
//  TestDeleteMe.swift
//  PerfectSwORM
//
//  Created by Kyle Jessup on 2017-11-26.
//

import Foundation

typealias Expression = SwORMExpression
typealias Bindings = [(String, Expression)]

protocol QueryItem {
	func setState(var state: inout SQLGenState) throws
	func setSQL(var state: inout SQLGenState) throws
}

protocol TableProtocol: QueryItem {
	associatedtype Form: Codable
	var databaseConfiguration: DatabaseConfigurationProtocol { get }
}

protocol FromTableProtocol {
	associatedtype FromTableType: TableProtocol
	var fromTable: FromTableType { get }
}

protocol JoinProtocol: TableProtocol, FromTableProtocol {
	associatedtype ComparisonType: Equatable
	associatedtype OverAllForm: Codable
	var on: KeyPath<OverAllForm, ComparisonType> { get }
	var equals: KeyPath<Form, ComparisonType> { get }
}

protocol CommandProtocol {
	var sqlGenState: SQLGenState { get }
}

protocol SelectProtocol: Sequence, FromTableProtocol, CommandProtocol {
	associatedtype OverAllForm: Codable
	var fromTable: FromTableType { get }
}

protocol SQLGenDelegate {
	var bindings: Bindings { get set }
	func getBinding(for: Expression) throws -> String
	func quote(identifier: String) throws -> String
}

protocol SQLExeDelegate {
	func bind(_ bindings: Bindings, skip: Int) throws
	func hasNext() throws -> Bool
	func next<A: CodingKey>() throws -> KeyedDecodingContainer<A>?
}

protocol DatabaseConfigurationProtocol {
	var sqlGenDelegate: SQLGenDelegate { get }
	func sqlExeDelegate(forSQL: String) throws -> SQLExeDelegate
}

protocol DatabaseProtocol {
	associatedtype Configuration: DatabaseConfigurationProtocol
	var configuration: Configuration { get }
	func table<T: Codable>(_ form: T.Type, ordering: PartialKeyPath<T>...) -> Table<T, Self>
}

struct SelectIterator<A: SelectProtocol>: IteratorProtocol {
	typealias Element = A.OverAllForm
	let select: A?
	let exeDelegate: SQLExeDelegate?
	init(select s: A) throws {
		select = s
		exeDelegate = try SQLTopExeDelegate(genState: s.sqlGenState, configurator: s.fromTable.databaseConfiguration)
	}
	init() {
		select = nil
		exeDelegate = nil
	}
	mutating func next() -> Element? {
		guard let delegate = exeDelegate else {
			return nil
		}
		do {
			if try delegate.hasNext() {
				let rowDecoder: SwORMRowDecoder2<ColumnKey> = SwORMRowDecoder2(delegate: delegate)
				return try Element(from: rowDecoder)
			}
		} catch {
			SwORMLogging.log(.error, "Error thrown in SelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
}

struct Select1<OAF: Codable, A: TableProtocol>: SelectProtocol {
	typealias Iterator = SelectIterator<Select1<OAF, A>>
	typealias FromTableType = A
	typealias OverAllForm = OAF
	let fromTable: FromTableType
	let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType) throws {
		fromTable = ft
		var state = SQLGenState(delegate: ft.databaseConfiguration.sqlGenDelegate)
		state.command = .select
		try ft.setState(state: &state)
		try ft.setSQL(state: &state)
		sqlGenState = state
	}
	func setSQL(var state: inout SQLGenState, delegate: SQLGenDelegate) {}
	func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			SwORMLogging.log(.error, "Error thrown in SwORMSelect.makeIterator() Caught: \(error)")
		}
		return SelectIterator()
	}
}

struct Where<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol {
	typealias Form = OAF
	typealias FromTableType = A
	typealias OverAllForm = OAF
	typealias SelfType = Where<OAF, A>
	var databaseConfiguration: DatabaseConfigurationProtocol { return fromTable.databaseConfiguration }
	let fromTable: FromTableType
	let expression: Expression
	func select() throws -> Select1<Form, SelfType> {
		return try Select1(fromTable: self)
	}
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		state.whereExpr = expression
	}
	func setSQL(var state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
	}
}

struct Join1<OAF: Codable, A: TableProtocol, B: Codable, O: Equatable>: TableProtocol, JoinProtocol {
	typealias Form = B
	typealias FromTableType = A
	typealias ComparisonType = O
	typealias OverAllForm = OAF
	typealias SelfType = Join1<OAF, A, B, O>
	var databaseConfiguration: DatabaseConfigurationProtocol { return fromTable.databaseConfiguration }
	let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	let on: KeyPath<OverAllForm, ComparisonType>
	let equals: KeyPath<Form, ComparisonType>
	let ordering: [PartialKeyPath<Form>]
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<OverAllForm, [NewType]?>,
													on: KeyPath<OverAllForm, KeyType>,
													equals: KeyPath<NewType, KeyType>,
													ordering: KeyPath<NewType, KeyType>...) throws -> Join1<OverAllForm, SelfType, NewType, KeyType> {
		return Join1<OverAllForm, SelfType, NewType, KeyType>(fromTable: self, to: to, on: on, equals: equals, ordering: ordering)
	}
	func select() throws -> Select1<OAF, SelfType> {
		return try Select1(fromTable: self)
	}
	func `where`(_ expr: Expression) -> Where<OverAllForm, SelfType> {
		return Where(fromTable: self, expression: expr)
	}
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: SQLGenState.PropertyJoinData(to: to, on: on, equals: equals))
	}
	func setSQL(var state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
		let tableData = state.tableData
		let delegate = state.delegate
		guard let firstTable = tableData.first,
			let myTableIndex = tableData.index(where: { Form.self == $0.type }) else {
			throw SwORMSQLGenError("No tables specified.")
		}
		let joinTables = Array(tableData[1..<myTableIndex]) + Array(tableData[(myTableIndex+1)...])
		let myTable = tableData[myTableIndex]
		let nameQ = try delegate.quote(identifier: "\(Form.self)")
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		let fNameQ = try delegate.quote(identifier: "\(firstTable.type)")
		let fAliasQ = try delegate.quote(identifier: firstTable.alias)
		let lhsStr = try Expression.keyPath(on).sqlSnippet(state: state)
		let rhsStr = try Expression.keyPath(equals).sqlSnippet(state: state)
		switch state.command {
		case .select:
			var sqlStr =
			"""
			SELECT DISTINCT \(aliasQ).*
			FROM \(nameQ) AS \(aliasQ)
			JOIN \(fNameQ) AS \(fAliasQ) ON \(lhsStr) = \(rhsStr)
			
			"""
			if let whereExpr = state.whereExpr {
				let referencedTypes = whereExpr.referencedTypes()
				for type in referencedTypes {
					guard type != firstTable.type && type != Form.self else {
						continue
					}
					guard let joinTable = joinTables.first(where: { type == $0.type }) else {
						throw SwORMSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw SwORMSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: "\(joinTable.type)")
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			SwORMLogging.log(.query, sqlStr)
		// ordering
		case .insert, .update, .delete:()
		//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw SwORMSQLGenError("SQL command was not set.")
		}
	}
}

struct Table<A: Codable, C: DatabaseProtocol>: TableProtocol {
	typealias Form = A
	typealias DatabaseType = C
	typealias SelfType = Table<A, C>
	var databaseConfiguration: DatabaseConfigurationProtocol { return database.configuration }
	let database: DatabaseType
	let ordering: [PartialKeyPath<Form>]
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<Form, [NewType]?>,
													on: KeyPath<Form, KeyType>,
													equals: KeyPath<NewType, KeyType>,
													ordering: KeyPath<NewType, KeyType>...) throws -> Join1<Form, SelfType, NewType, KeyType> {
		return Join1(fromTable: self, to: to, on: on, equals: equals, ordering: ordering)
	}
	func select() throws -> Select1<Form, SelfType> {
		return try Select1(fromTable: self)
	}
	func `where`(_ expr: Expression) -> Where<Form, SelfType> {
		return Where(fromTable: self, expression: expr)
	}
	func setState(var state: inout SQLGenState) throws {
		try state.addTable(type: Form.self)
	}
	func setSQL(var state: inout SQLGenState) throws {
		let tableData = state.tableData
		let delegate = state.delegate
		guard let myTable = tableData.first else {
			throw SwORMSQLGenError("No tables specified.")
		}
		let nameQ = try delegate.quote(identifier: "\(Form.self)")
		let aliasQ = try delegate.quote(identifier: myTable.alias)
		switch state.command {
		case .select:
			var sqlStr =
			"""
			SELECT DISTINCT \(aliasQ).*
			FROM \(nameQ) AS \(aliasQ)
			
			"""
			if let whereExpr = state.whereExpr {
				let joinTables = tableData[1...].map { $0 }
				let referencedTypes = whereExpr.referencedTypes()
				for type in referencedTypes {
					guard let joinTable = joinTables.first(where: { type == $0.type }) else {
						throw SwORMSQLGenError("Unknown type included in where clause \(type).")
					}
					guard let joinData = joinTable.joinData else {
						throw SwORMSQLGenError("Join without a clause \(type).")
					}
					let nameQ = try delegate.quote(identifier: "\(joinTable.type)")
					let aliasQ = try delegate.quote(identifier: joinTable.alias)
					let lhsStr = try Expression.keyPath(joinData.on).sqlSnippet(state: state)
					let rhsStr = try Expression.keyPath(joinData.equals).sqlSnippet(state: state)
					sqlStr += "JOIN \(nameQ) AS \(aliasQ) ON \(lhsStr) = \(rhsStr)\n"
				}
				sqlStr += "WHERE \(try whereExpr.sqlSnippet(state: state))\n"
			}
			state.statements.append(.init(sql: sqlStr, bindings: delegate.bindings))
			state.delegate.bindings = []
			SwORMLogging.log(.query, sqlStr)
			// ordering
		case .insert, .update, .delete:()
//			state.fromStr.append("\(myTable)")
		case .unknown:
			throw SwORMSQLGenError("SQL command was not set.")
		}
	}
}

struct Database<C: DatabaseConfigurationProtocol>: DatabaseProtocol {
	typealias Configuration = C
	let configuration: Configuration
	func table<T: Codable>(_ form: T.Type, ordering: PartialKeyPath<T>...) -> Table<T, Database<C>> {
		return Table(database: self, ordering: ordering)
	}
}

extension SQLExeDelegate {
	func bind(_ bindings: Bindings) throws { return try bind(bindings, skip: 0) }
}

struct SQLGenState {
	enum Command: String {
		case select = "SELECT", insert = "INSERT INTO", update = "UPDATE", delete = "DELETE FROM", unknown = "unknown"
	}
	struct TableData {
		let type: Any.Type
		let alias: String
		let modelInstance: Any?
		let keyPathDecoder: SwORMKeyPathsDecoder
		let joinData: PropertyJoinData?
	}
	struct PropertyJoinData {
		let to: AnyKeyPath
		let on: AnyKeyPath
		let equals: AnyKeyPath
	}
	struct Statement {
		let sql: String
		let bindings: Bindings
	}
	var delegate: SQLGenDelegate
	var aliasCounter = 0
	var tableData: [TableData] = []
	var command: Command = .unknown
	var whereExpr: Expression?
	var statements: [Statement] = []
	init(delegate d: SQLGenDelegate) {
		delegate = d
	}
	mutating func addTable<A: Codable>(type: A.Type, joinData: PropertyJoinData? = nil) throws {
		let decoder = SwORMKeyPathsDecoder()
		let model = try A(from: decoder)
		tableData.append(.init(type: type,
								   alias: nextAlias(),
								   modelInstance: model,
								   keyPathDecoder: decoder,
								   joinData: joinData))
	}
	mutating func getAlias<A: Codable>(type: A.Type) -> String? {
		return tableData.first { $0.type == type }?.alias
	}
	func getTableData(type: Any.Type) -> TableData? {
		return tableData.first { $0.type == type }
	}
	mutating func nextAlias() -> String {
		defer { aliasCounter += 1 }
		return "t\(aliasCounter)"
	}
	func getTableName<A: Codable>(type: A.Type) -> String {
		return "\(type)" // this is where table name mapping might go
	}
	
	mutating func getKeyName<A: Codable>(type: A.Type, key: PartialKeyPath<A>) throws -> String? {
		guard let td = getTableData(type: type),
			let instance = td.modelInstance as? A,
			let name = try td.keyPathDecoder.getKeyPathName(instance, keyPath: key) else {
			return nil
		}
		return name
	}
}

struct SQLTopExeDelegate: SQLExeDelegate {
	let genState: SQLGenState
	let master: (table: SQLGenState.TableData, delegate: SQLExeDelegate)
	let subObjects: [String:(onKeyName: String, onKey: AnyKeyPath, equalsKey: AnyKeyPath, objects: [Any])]
	init(genState state: SQLGenState, configurator: DatabaseConfigurationProtocol) throws {
		genState = state
		let delegates: [(table: SQLGenState.TableData, delegate: SQLExeDelegate)] = try zip(state.tableData, state.statements).map {
			let sd = try configurator.sqlExeDelegate(forSQL: $0.1.sql)
			try sd.bind($0.1.bindings)
			return ($0.0, sd)
		}
		guard !delegates.isEmpty else {
			throw SwORMSQLExeError("No tables in query.")
		}
		master = delegates[0]
		guard let modelInstance = master.table.modelInstance else {
			throw SwORMSQLExeError("No model instance for type \(master.table.type).")
		}
		let joins = delegates[1...]
		let keyPathDecoder = master.table.keyPathDecoder
		subObjects = Dictionary(uniqueKeysWithValues: try joins.map {
			let (joinTable, joinDelegate) = $0
			guard let joinData = joinTable.joinData,
				let type = joinTable.type as? Codable.Type,
				let keyStr = try keyPathDecoder.getKeyPathName(modelInstance, keyPath: joinData.to),
				let onKeyStr = try keyPathDecoder.getKeyPathName(modelInstance, keyPath: joinData.on) else {
					throw SwORMSQLExeError("No join data on \(joinTable.type)")
			}
			var ary: [Codable] = []
			while try joinDelegate.hasNext() {
				let decoder = SwORMRowDecoder2<ColumnKey>(delegate: joinDelegate)
				ary.append(try type.init(from: decoder))
			}
			return (keyStr, (onKeyStr, joinData.on, joinData.equals, ary))
		})
	}
	func bind(_ bindings: Bindings, skip: Int) throws {
		try master.delegate.bind(bindings, skip: skip)
	}
	
	func hasNext() throws -> Bool {
		return try master.delegate.hasNext()
	}
	
	func next<A>() throws -> KeyedDecodingContainer<A>? where A : CodingKey {
		guard let k: KeyedDecodingContainer<A> = try master.delegate.next() else {
			return nil
		}
		return KeyedDecodingContainer<A>(SQLTopRowReader(exeDelegate: self, subRowReader: k))
	}
}

class SQLTopRowReader<K : CodingKey>: KeyedDecodingContainerProtocol {
	typealias Key = K
	var codingPath: [CodingKey] = []
	var allKeys: [Key] = []
	let exeDelegate: SQLTopExeDelegate
	let subRowReader: KeyedDecodingContainer<K>
	init(exeDelegate e: SQLTopExeDelegate, subRowReader s: KeyedDecodingContainer<K>) {
		exeDelegate = e
		subRowReader = s
	}
	func contains(_ key: Key) -> Bool {
		return subRowReader.contains(key) || nil != exeDelegate.subObjects.index(forKey: key.stringValue)
	}
	func decodeNil(forKey key: Key) throws -> Bool {
		if nil != exeDelegate.subObjects.index(forKey: key.stringValue) {
			return false
		}
		return try subRowReader.decodeNil(forKey: key)
	}
	func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode(_ type: String.Type, forKey key: Key) throws -> String {
		return try subRowReader.decode(type, forKey: key)
	}
	func decode<T>(_ intype: T.Type, forKey key: Key) throws -> T where T : Decodable {
		if let (onKeyName, onKey, equalsKey, objects) = exeDelegate.subObjects[key.stringValue],
			objects is T,
			let columnKey = Key(stringValue: onKeyName),
			let comparisonType = type(of: onKey).valueType as? Decodable.Type {
			// I could not get this to compile. because comparisonType isn't known at compile time?
			//let keyValue = try subRowReader.decode(comparisonType, forKey: columnKey)
			let theseObjs: [Any]
			switch comparisonType {
			case let i as Bool.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Int.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Int8.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Int16.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Int32.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Int64.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as UInt.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as UInt8.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as UInt16.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as UInt32.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as UInt64.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Float.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Double.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as String.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Date.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			case let i as Data.Type:
				let keyValue = try subRowReader.decode(i, forKey: columnKey)
				theseObjs = filteredValues(objects, lhs: keyValue, rhsKey: equalsKey)
			default:
				throw SwORMSQLExeError("Invalid join comparison type \(comparisonType).")
			}
			return theseObjs as! T
		}
		return try subRowReader.decode(intype, forKey: key)
	}
	private func filteredValues<ComparisonType: Equatable>(_ values: [Any], lhs: ComparisonType, rhsKey: AnyKeyPath) -> [Any] {
		return values.flatMap {
			guard let rhs = $0[keyPath: rhsKey] as? ComparisonType,
				lhs == rhs else {
					return nil
			}
			return $0
		}
	}
	func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
		return try subRowReader.nestedContainer(keyedBy: type, forKey: key)
	}
	func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
		return try subRowReader.nestedUnkeyedContainer(forKey: key)
	}
	func superDecoder() throws -> Decoder {
		return try subRowReader.superDecoder()
	}
	func superDecoder(forKey key: Key) throws -> Decoder {
		return try subRowReader.superDecoder(forKey: key)
	}
}







