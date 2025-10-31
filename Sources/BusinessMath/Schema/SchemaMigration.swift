//
//  SchemaMigration.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - MigrationError

/// Errors that can occur during schema migration.
public enum MigrationError: Error {
	/// No migration path exists from one version to another.
	case noMigrationPath(from: Int, to: Int)

	/// A migration failed.
	case migrationFailed(version: Int, reason: String)
}

// MARK: - SchemaMigration

/// A migration from one schema version to another.
///
/// `SchemaMigration` defines a single step in migrating data from one schema
/// version to the next. Migrations can add fields, remove fields, rename fields,
/// or transform data.
///
/// ## Example
///
/// ```swift
/// struct AddCategoryMigration: SchemaMigration {
///     let fromVersion = 1
///     let toVersion = 2
///     let description = "Add category field with default value"
///
///     func migrate(_ data: inout [String: Any]) throws {
///         if data["category"] == nil {
///             data["category"] = "Uncategorized"
///         }
///     }
/// }
/// ```
///
/// ## Migration Guidelines
///
/// - Each migration should handle a single version increment
/// - Migrations should be idempotent when possible
/// - Migrations should preserve existing data unless explicitly removing it
/// - Use descriptive names and descriptions for migrations
public protocol SchemaMigration {
	/// The schema version this migration applies from.
	var fromVersion: Int { get }

	/// The schema version this migration migrates to.
	var toVersion: Int { get }

	/// A human-readable description of what this migration does.
	var description: String { get }

	/// Performs the migration on the provided data.
	///
	/// The data dictionary is passed as an `inout` parameter, allowing the
	/// migration to modify it in place.
	///
	/// - Parameter data: The data to migrate (modified in place).
	/// - Throws: `MigrationError.migrationFailed` if the migration fails.
	func migrate(_ data: inout [String: Any]) throws
}

// MARK: - MigrationManager

/// Manages and executes schema migrations.
///
/// `MigrationManager` maintains a registry of migrations and can automatically
/// migrate data through multiple versions by chaining migrations together.
///
/// ## Basic Usage
///
/// ```swift
/// let manager = MigrationManager()
///
/// // Register migrations
/// manager.register(Migration_v1_to_v2())
/// manager.register(Migration_v2_to_v3())
/// manager.register(Migration_v3_to_v4())
///
/// // Migrate data from v1 to v4
/// let data: [String: Any] = [
///     "name": "Acme Corp",
///     "revenue": 10000.0
/// ]
///
/// let migrated = try manager.migrate(data: data, from: 1, to: 4)
/// ```
///
/// ## Migration Chains
///
/// The manager automatically chains migrations together to find a path from
/// the source version to the target version. For example, to migrate from
/// version 1 to version 4, it will execute:
/// 1. Migration v1 -> v2
/// 2. Migration v2 -> v3
/// 3. Migration v3 -> v4
///
/// ## Error Handling
///
/// If no migration path exists, the manager throws
/// `MigrationError.noMigrationPath`. If a migration fails, it throws
/// `MigrationError.migrationFailed`.
public class MigrationManager {
	private var migrations: [Int: any SchemaMigration] = [:]

	/// Creates a migration manager.
	public init() {}

	/// Registers a migration.
	///
	/// - Parameter migration: The migration to register.
	public func register(_ migration: any SchemaMigration) {
		migrations[migration.fromVersion] = migration
	}

	/// Migrates data from one schema version to another.
	///
	/// Automatically chains migrations together to migrate across multiple versions.
	/// If `from` equals `to`, returns the data unchanged.
	///
	/// - Parameters:
	///   - data: The data to migrate.
	///   - from: The current schema version of the data.
	///   - to: The target schema version.
	/// - Returns: The migrated data.
	/// - Throws: `MigrationError.noMigrationPath` if no migration path exists,
	///           or `MigrationError.migrationFailed` if a migration fails.
	public func migrate(data: [String: Any], from: Int, to: Int) throws -> [String: Any] {
		// No migration needed
		if from == to {
			return data
		}

		// Find migration path
		var currentVersion = from
		var currentData = data

		while currentVersion < to {
			guard let migration = migrations[currentVersion] else {
				throw MigrationError.noMigrationPath(from: currentVersion, to: to)
			}

			// Execute migration
			try migration.migrate(&currentData)
			currentVersion = migration.toVersion
		}

		// Verify we reached the target version
		guard currentVersion == to else {
			throw MigrationError.noMigrationPath(from: currentVersion, to: to)
		}

		return currentData
	}

	/// Returns all registered migrations.
	public var registeredMigrations: [any SchemaMigration] {
		return Array(migrations.values)
	}

	/// Returns the migration for a specific version, if registered.
	///
	/// - Parameter fromVersion: The source version.
	/// - Returns: The migration for that version, or nil if not registered.
	public func migration(from fromVersion: Int) -> (any SchemaMigration)? {
		return migrations[fromVersion]
	}
}
