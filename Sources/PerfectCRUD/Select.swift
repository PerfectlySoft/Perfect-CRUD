//
//  PerfectCRUDSelect.swift
//  PerfectCRUD
//
//  Created by Kyle Jessup on 2017-12-02.
//

import Foundation

/// Steps through the rows of a `Select`.
///
/// `next()` is the `IteratorProtocol` requirement that `for … in` uses. It can't throw, so when the
/// query fails or a row can't be decoded it logs the error through `CRUDLogging` and returns `nil`:
/// the loop simply ends and the remaining rows are lost. Use `nextElement()`, which throws instead,
/// together with `Select.rows()`, or `Select.all()` / `Select.forEachRow(_:)`.
public struct SelectIterator<A: SelectProtocol>: IteratorProtocol {
	public typealias Element = A.OverAllForm
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
	/// Returns the next row, or `nil` at the end of the results. On an error it logs the error and
	/// returns `nil`, so a `for … in` loop stops at the first failing row. See `nextElement()`.
	public mutating func next() -> Element? {
		guard let delegate = exeDelegate else {
			return nil
		}
		do {
			if try delegate.hasNext() {
				let rowDecoder: CRUDRowDecoder<ColumnKey> = CRUDRowDecoder(delegate: delegate)
				return try Element(from: rowDecoder)
			}
		} catch {
			CRUDLogging.log(.error, "Error thrown in SelectIterator.next(). Caught: \(error)")
		}
		return nil
	}
	/// Returns the next row, or `nil` at the end of the results, and throws if the query fails or
	/// the row can't be decoded.
	public mutating func nextElement() throws -> Element? {
		guard let delegate = exeDelegate else {
			return nil
		}
		if try delegate.hasNext() {
			let rowDecoder: CRUDRowDecoder<ColumnKey> = CRUDRowDecoder(delegate: delegate)
			return try Element(from: rowDecoder)
		}
		return nil
	}
}

/// A query's results, read lazily from the database.
///
/// Read them with the throwing `all()`, `forEachRow(_:)` or `rows()`, which report a failed query
/// or a row that can't be decoded.
///
/// `Select` is also a `Sequence`, so `for row in select` (and `map`, `Array(select)` and the other
/// `Sequence` methods) still work, but they can't throw: an error is logged through `CRUDLogging`
/// and the sequence ends early. If the query itself fails (bad SQL, a server error, a joined
/// table's row that can't be decoded) the sequence is empty; if one row fails to decode, iteration
/// stops there and the rows after it are skipped.
public struct Select<OAF: Codable, A: TableProtocol>: SelectProtocol {
	public typealias Iterator = SelectIterator<Select>
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	public let sqlGenState: SQLGenState
	init(fromTable ft: FromTableType, firstRowOnly: Bool = false) throws {
		fromTable = ft
		var state = SQLGenState(delegate: ft.databaseConfiguration.sqlGenDelegate)
		state.command = .select
		state.firstRowOnly = firstRowOnly
		try ft.setState(state: &state)
		try ft.setSQL(state: &state)
		guard state.accumulatedOrderings.isEmpty else {
			throw CRUDSQLGenError("Orderings were not consumed: \(state.accumulatedOrderings)")
		}
		_ = try state.selectTables()
		sqlGenState = state
	}
	/// The `Sequence` iterator used by `for … in`. If the query can't be run it logs the error and
	/// returns an empty iterator. Use `rows()` to get the error instead.
	public func makeIterator() -> Iterator {
		do {
			return try SelectIterator(select: self)
		} catch {
			CRUDLogging.log(.error, "Error thrown in Select.makeIterator() Caught: \(error)")
		}
		return SelectIterator()
	}
	/// Runs the query and returns an iterator whose `nextElement()` throws on a row that can't be
	/// read. Throws if the query can't be run, including when a joined table's rows can't be
	/// decoded. Use it to stop part way through without reading every row:
	///
	///     var rows = try select.rows()
	///     while let row = try rows.nextElement() { … }
	public func rows() throws -> Iterator {
		return try SelectIterator(select: self)
	}
	/// Runs the query and returns every row. Throws if the query fails or any row can't be decoded,
	/// rather than returning the rows before the failure.
	public func all() throws -> [OverAllForm] {
		var iterator = try rows()
		var result: [OverAllForm] = []
		while let row = try iterator.nextElement() {
			result.append(row)
		}
		return result
	}
	/// Runs the query and calls `body` with each row in turn. Throws if the query fails, a row can't
	/// be decoded, or `body` throws; no further rows are read after an error.
	///
	/// Named `forEachRow` rather than `forEach` because a throwing `forEach` here would hide
	/// `Sequence.forEach(_:)` and make every existing `select.forEach { … }` call need `try`.
	public func forEachRow(_ body: (OverAllForm) throws -> Void) throws {
		var iterator = try rows()
		while let row = try iterator.nextElement() {
			try body(row)
		}
	}
}

public struct Ordering<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, Joinable, Selectable, Whereable, Orderable, Limitable {
	public typealias Form = A.Form
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let keys: [PartialKeyPath<A.Form>]
	let descending: Bool
	public func setState(state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	public func setSQL(state: inout SQLGenState) throws {
		state.accumulatedOrderings.append(contentsOf: keys.map { (key: $0, desc: descending) })
		try fromTable.setSQL(state: &state)
	}
}

// `@unchecked`: `keys: [PartialKeyPath<A.Form>]` -- see Join's conformance
// (Join.swift) for why KeyPath types need `@unchecked` here.
extension Ordering: @unchecked Sendable where A: Sendable {}

public struct Limit<OAF: Codable, A: TableProtocol>: TableProtocol, FromTableProtocol, Joinable, Selectable, Whereable, Orderable {
	public typealias Form = A.Form
	public typealias FromTableType = A
	public typealias OverAllForm = OAF
	public let fromTable: FromTableType
	let max: Int
	let skip: Int
	public func setState(state: inout SQLGenState) throws {
		try fromTable.setState(state: &state)
	}
	public func setSQL(state: inout SQLGenState) throws {
		state.currentLimit = (max, skip)
		try fromTable.setSQL(state: &state)
	}
}

// Stored properties beyond `fromTable: A` are plain Ints -- no `@unchecked` needed.
extension Limit: Sendable where A: Sendable {}

