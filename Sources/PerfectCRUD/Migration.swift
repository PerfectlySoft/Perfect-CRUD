//
//  Migration.swift
//  PerfectCRUD
//
//  Phase 3 (ADR-0001): a versioned migration system layered above --
//  not replacing -- TableCreatePolicy.reconcileTable. Individual migrations
//  are free to call db.create(_:policy: .reconcileTable) for simple
//  additive column changes, or drop to db.sql("ALTER TABLE ...") for
//  anything reconcileTable can't express (e.g. changing a column's type);
//  both run through the unmodified SQLGenDelegate/SQLExeDelegate seam.
//  This file is purely additive orchestration on top.
//

import Foundation

/// Tracks which migrations have been applied to a database. One row per
/// applied migration, in application order (`appliedAt` ascending).
public struct CRUDMigrationRecord: Codable, TableNameProvider, Sendable {
	public static let tableName = "perfectcrud_migrations"
	public var identifier: String
	public var appliedAt: Date
	public init(identifier: String, appliedAt: Date) {
		self.identifier = identifier
		self.appliedAt = appliedAt
	}
}

/// A versioned migration system. Migrations are applied in **registration
/// order**, not a lexical/timestamp sort on `identifier` -- matching GRDB's
/// actual behavior and avoiding a naming-convention footgun. Convention
/// (documented, not enforced): date-prefixed identifiers such as
/// `"2026_07_create_posts"`.
///
/// Concurrency note: registration (`register`) is expected to happen once,
/// at startup, before any `migrate(_:)` call -- not concurrently with one.
/// `migrate(_:)`/`rollbackLast(_:)` themselves are safe to call from
/// multiple tasks (the registered-migrations list is read under a lock),
/// but running `migrate()` from every server instance's own startup path
/// against a **shared network database** is not: see the "Concurrent-
/// migrator race" risk in the ADR-0001 implementation plan. Run it from
/// exactly one process/deploy step for a network connector; SQLite's
/// single-writer semantics make this less of a concern there.
public final class DatabaseMigrator<C: DatabaseConfigurationProtocol>: @unchecked Sendable {
	public struct Migration: Sendable {
		public let identifier: String
		public let up: @Sendable (Database<C>) throws -> Void
		public let down: (@Sendable (Database<C>) throws -> Void)?
		public init(identifier: String,
					up: @escaping @Sendable (Database<C>) throws -> Void,
					down: (@Sendable (Database<C>) throws -> Void)? = nil) {
			self.identifier = identifier
			self.up = up
			self.down = down
		}
	}

	private let lock = NSLock()
	private var migrations: [Migration] = []
	private var identifiers: Set<String> = []

	public init() {}

	/// Registers a migration. Throws if `identifier` is already registered
	/// -- migrations are meant to be a fixed, reviewed sequence, not
	/// silently overwritable.
	public func register(_ identifier: String,
						  up: @escaping @Sendable (Database<C>) throws -> Void,
						  down: (@Sendable (Database<C>) throws -> Void)? = nil) throws {
		lock.lock(); defer { lock.unlock() }
		guard !identifiers.contains(identifier) else {
			throw CRUDSQLGenError("Migration \"\(identifier)\" is already registered.")
		}
		identifiers.insert(identifier)
		migrations.append(Migration(identifier: identifier, up: up, down: down))
	}

	private func snapshot() -> [Migration] {
		lock.lock(); defer { lock.unlock() }
		return migrations
	}

	/// Applies every registered migration not yet recorded, in registration
	/// order, each inside its own transaction. Returns the identifiers newly
	/// applied (empty if the database was already current).
	@discardableResult
	public func migrate(_ db: Database<C>) throws -> [String] {
		try db.create(CRUDMigrationRecord.self, policy: .shallow)
		let applied = Set(try db.table(CRUDMigrationRecord.self).select().map { $0.identifier })
		var newly: [String] = []
		for migration in snapshot() where !applied.contains(migration.identifier) {
			try db.transaction {
				try migration.up(db)
				try db.table(CRUDMigrationRecord.self).insert(.init(identifier: migration.identifier, appliedAt: Date()))
			}
			newly.append(migration.identifier)
		}
		return newly
	}

	/// Rolls back only the most recently applied migration (by `appliedAt`).
	/// Throws if nothing has been applied, if that migration is no longer
	/// registered, or if it has no `down`. Down-migrations are opt-in and
	/// never inferred -- auto-generating a reverse of an arbitrary
	/// `ALTER`/`DROP` is unsafe.
	@discardableResult
	public func rollbackLast(_ db: Database<C>) throws -> String {
		guard let lastRecord = try db.table(CRUDMigrationRecord.self)
			.order(descending: \CRUDMigrationRecord.appliedAt)
			.limit(1)
			.first() else {
			throw CRUDSQLGenError("No migrations have been applied.")
		}
		guard let migration = snapshot().first(where: { $0.identifier == lastRecord.identifier }) else {
			throw CRUDSQLGenError("Migration \"\(lastRecord.identifier)\" is applied but no longer registered -- cannot determine how to roll it back.")
		}
		guard let down = migration.down else {
			throw CRUDSQLGenError("Migration \"\(lastRecord.identifier)\" has no `down` -- cannot roll back.")
		}
		try db.transaction {
			try down(db)
			try db.table(CRUDMigrationRecord.self)
				.where(\CRUDMigrationRecord.identifier == lastRecord.identifier)
				.delete()
		}
		return lastRecord.identifier
	}
}
