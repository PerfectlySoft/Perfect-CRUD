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
	func table<T: Codable>(_ form: T.Type) -> Table<T, Self>
}

extension FromTableProtocol {
	var databaseConfiguration: DatabaseConfigurationProtocol { return fromTable.databaseConfiguration }
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

struct Select<OAF: Codable, A: TableProtocol>: SelectProtocol {
	typealias Iterator = SelectIterator<Select<OAF, A>>
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
		guard state.accumulatedOrderings.isEmpty else {
			throw SwORMSQLGenError("Orderings were not consumed: \(state.accumulatedOrderings)")
		}
		sqlGenState = state
	}
	func setSQL(var state: inout SQLGenState, delegate: SQLGenDelegate) {}
	func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			SwORMLogging.log(.error, "Error thrown in Select.makeIterator() Caught: \(error)")
		}
		return SelectIterator()
	}
}

struct Where<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol {
	typealias Form = OAF
	typealias FromTableType = A
	typealias OverAllForm = OAF
	typealias SelfType = Where<OAF, A>
	let fromTable: FromTableType
	let expression: Expression
	func select() throws -> Select<Form, SelfType> {
		return try .init(fromTable: self)
	}
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		state.whereExpr = expression
	}
	func setSQL(var state: inout SQLGenState) throws {
		try fromTable.setSQL(state: &state)
	}
}

struct Ordering<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol {
	typealias Form = A.Form
	typealias FromTableType = A
	typealias OverAllForm = OAF
	typealias SelfType = Ordering<OAF, A>
	let fromTable: FromTableType
	let keys: [PartialKeyPath<A.Form>]
	let descending: Bool
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<OverAllForm, [NewType]?>,
													on: KeyPath<OverAllForm, KeyType>,
													equals: KeyPath<NewType, KeyType>) throws -> Join<OverAllForm, SelfType, NewType, KeyType> {
		return .init(fromTable: self, to: to, on: on, equals: equals)
	}
	func order(by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, SelfType> {
		return .init(fromTable: self, keys: by, descending: false)
	}
	func order(descending by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, SelfType> {
		return .init(fromTable: self, keys: by, descending: true)
	}
	func `where`(_ expr: Expression) -> Where<OverAllForm, SelfType> {
		return .init(fromTable: self, expression: expr)
	}
	func select() throws -> Select<OverAllForm, SelfType> {
		return try .init(fromTable: self)
	}
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	func setSQL(var state: inout SQLGenState) throws {
		state.accumulatedOrderings.append(contentsOf: keys.map { (key: $0, desc: descending) })
		try fromTable.setSQL(state: &state)
	}
}

struct Join<OAF: Codable, A: TableProtocol, B: Codable, O: Equatable>: TableProtocol, JoinProtocol {
	typealias Form = B
	typealias FromTableType = A
	typealias ComparisonType = O
	typealias OverAllForm = OAF
	typealias SelfType = Join<OAF, A, B, O>
	let fromTable: FromTableType
	let to: KeyPath<OverAllForm, [Form]?>
	let on: KeyPath<OverAllForm, ComparisonType>
	let equals: KeyPath<Form, ComparisonType>
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<OverAllForm, [NewType]?>,
													on: KeyPath<OverAllForm, KeyType>,
													equals: KeyPath<NewType, KeyType>) throws -> Join<OverAllForm, SelfType, NewType, KeyType> {
		return .init(fromTable: self, to: to, on: on, equals: equals)
	}
	func select() throws -> Select<OAF, SelfType> {
		return try .init(fromTable: self)
	}
	func `where`(_ expr: Expression) -> Where<OverAllForm, SelfType> {
		return .init(fromTable: self, expression: expr)
	}
	func order(by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, SelfType> {
		return .init(fromTable: self, keys: by, descending: false)
	}
	func order(descending by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, SelfType> {
		return .init(fromTable: self, keys: by, descending: true)
	}
	func setState(var state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
		try state.addTable(type: Form.self, joinData: .init(to: to, on: on, equals: equals))
	}
	func setSQL(var state: inout SQLGenState) throws {
		let orderings = state.consumeOrderings()
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
			if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))"
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
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<Form, [NewType]?>,
													on: KeyPath<Form, KeyType>,
													equals: KeyPath<NewType, KeyType>) throws -> Join<Form, SelfType, NewType, KeyType> {
		return .init(fromTable: self, to: to, on: on, equals: equals)
	}
	func select() throws -> Select<Form, SelfType> {
		return try .init(fromTable: self)
	}
	func `where`(_ expr: Expression) -> Where<Form, SelfType> {
		return .init(fromTable: self, expression: expr)
	}
	func order(by: PartialKeyPath<Form>...) throws -> Ordering<Form, SelfType> {
		return .init(fromTable: self, keys: by, descending: false)
	}
	func order(descending by: PartialKeyPath<Form>...) throws -> Ordering<Form, SelfType> {
		return .init(fromTable: self, keys: by, descending: true)
	}
	func setState(var state: inout SQLGenState) throws {
		try state.addTable(type: Form.self)
	}
	func setSQL(var state: inout SQLGenState) throws {
		let orderings = state.consumeOrderings()
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
			if !orderings.isEmpty {
				let m = try orderings.map { "\(try Expression.keyPath($0.key).sqlSnippet(state: state))\($0.desc ? " DESC" : "")" }
				sqlStr += "ORDER BY \(m.joined(separator: ", "))"
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
	func table<T: Codable>(_ form: T.Type) -> Table<T, Database<C>> {
		return .init(database: self)
	}
}

extension SQLExeDelegate {
	func bind(_ bindings: Bindings) throws { return try bind(bindings, skip: 0) }
}

struct SQLGenState {
	enum Command {
		case select, insert, update, delete, unknown
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
	typealias Ordering = (key: AnyKeyPath, desc: Bool)
	var delegate: SQLGenDelegate
	var aliasCounter = 0
	var tableData: [TableData] = []
	var command: Command = .unknown
	var whereExpr: Expression?
	var statements: [Statement] = [] // statements count must match tableData count for exe to succeed
	var accumulatedOrderings: [Ordering] = []
	init(delegate d: SQLGenDelegate) {
		delegate = d
	}
	mutating func consumeOrderings() -> [Ordering] {
		defer { accumulatedOrderings = [] }
		return accumulatedOrderings
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









