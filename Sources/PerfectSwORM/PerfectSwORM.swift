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
	associatedtype OverAllForm: Codable
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
	var on: KeyPath<OverAllForm, ComparisonType> { get }
	var equals: KeyPath<Form, ComparisonType> { get }
}

protocol CommandProtocol: QueryItem {
	var sqlGenState: SQLGenState { get }
}

protocol SelectProtocol: Sequence, FromTableProtocol, CommandProtocol {
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

protocol JoinAble: TableProtocol {
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<OverAllForm, [NewType]?>,
													on: KeyPath<OverAllForm, KeyType>,
													equals: KeyPath<NewType, KeyType>) throws -> Join<OverAllForm, Self, NewType, KeyType>
}

protocol SelectAble: TableProtocol {
	func select() throws -> Select<OverAllForm, Self>
}

protocol WhereAble: TableProtocol {
	func `where`(_ expr: Expression) -> Where<OverAllForm, Self>
}

protocol OrderAble: TableProtocol {
	func order(by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, Self>
	func order(descending by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, Self>
}

extension JoinAble {
	func join<NewType: Codable, KeyType: Equatable>(_ to: KeyPath<OverAllForm, [NewType]?>,
													on: KeyPath<OverAllForm, KeyType>,
													equals: KeyPath<NewType, KeyType>) throws -> Join<OverAllForm, Self, NewType, KeyType> {
		return .init(fromTable: self, to: to, on: on, equals: equals)
	}
}

extension SelectAble {
	func select() throws -> Select<OverAllForm, Self> {
		return try .init(fromTable: self)
	}
}

extension WhereAble {
	func `where`(_ expr: Expression) -> Where<OverAllForm, Self> {
		return .init(fromTable: self, expression: expr)
	}
}
extension OrderAble {
	func order(by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, Self> {
		return .init(fromTable: self, keys: by, descending: false)
	}
	func order(descending by: PartialKeyPath<Form>...) throws -> Ordering<OverAllForm, Self> {
		return .init(fromTable: self, keys: by, descending: true)
	}
}

extension FromTableProtocol {
	var databaseConfiguration: DatabaseConfigurationProtocol { return fromTable.databaseConfiguration }
}

extension CommandProtocol {
	func setState(state: inout SQLGenState) throws {}
	func setSQL(state: inout SQLGenState) throws {}
}

extension SQLExeDelegate {
	func bind(_ bindings: Bindings) throws { return try bind(bindings, skip: 0) }
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
	var bindingsEncoder: SwORMBindingsEncoder?
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



