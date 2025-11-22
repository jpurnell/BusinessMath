import Testing
import Foundation
@testable import BusinessMath

@Suite("Schema Migration Tests")
struct SchemaMigrationTests {

	// MARK: - Sample Migrations

	struct Migration_v1_to_v2: SchemaMigration {
		let fromVersion = 1
		let toVersion = 2
		let description = "Add category field with default value"

		func migrate(_ data: inout [String: Any]) throws {
			if data["category"] == nil {
				data["category"] = "Uncategorized"
			}
		}
	}

	struct Migration_v2_to_v3: SchemaMigration {
		let fromVersion = 2
		let toVersion = 3
		let description = "Rename 'revenue' to 'totalRevenue'"

		func migrate(_ data: inout [String: Any]) throws {
			if let revenue = data["revenue"] {
				data["totalRevenue"] = revenue
				data.removeValue(forKey: "revenue")
			}
		}
	}

	struct Migration_v3_to_v4: SchemaMigration {
		let fromVersion = 3
		let toVersion = 4
		let description = "Convert revenue from cents to dollars"

		func migrate(_ data: inout [String: Any]) throws {
			if let revenue = data["totalRevenue"] as? Double {
				data["totalRevenue"] = revenue / 100.0
			}
		}
	}

	// MARK: - Migration Tests

	@Test("Single migration")
	func singleMigration() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())

		let data: [String: Any] = [
			"name": "Acme Corp"
		]

		let migrated = try manager.migrate(data: data, from: 1, to: 2)

		#expect(migrated["category"] as? String == "Uncategorized")
		#expect(migrated["name"] as? String == "Acme Corp")
	}

	@Test("Multiple migrations in sequence")
	func multipleMigrations() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())
		manager.register(Migration_v2_to_v3())
		manager.register(Migration_v3_to_v4())

		let data: [String: Any] = [
			"name": "Acme Corp",
			"revenue": 100_00.0  // In cents
		]

		let migrated = try manager.migrate(data: data, from: 1, to: 4)

		// After all migrations:
		#expect(migrated["category"] as? String == "Uncategorized")  // v1->v2
		#expect(migrated["revenue"] == nil)  // Removed in v2->v3
		#expect(migrated["totalRevenue"] as? Double == 100.0)  // Renamed and converted
	}

	@Test("Migration from v1 to v3")
	func partialMigrationPath() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())
		manager.register(Migration_v2_to_v3())

		let data: [String: Any] = [
			"revenue": 100_000.0
		]

		let migrated = try manager.migrate(data: data, from: 1, to: 3)

		#expect(migrated["category"] != nil)
		#expect(migrated["totalRevenue"] as? Double == 100_000.0)
		#expect(migrated["revenue"] == nil)
	}

	@Test("No migration needed - same version")
	func noMigrationNeeded() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())

		let data: [String: Any] = [
			"name": "Acme Corp",
			"category": "Software"
		]

		let migrated = try manager.migrate(data: data, from: 2, to: 2)

		// Should return unchanged
		#expect(migrated["name"] as? String == "Acme Corp")
		#expect(migrated["category"] as? String == "Software")
	}

	@Test("Missing migration path throws error")
	func missingMigrationPath() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())
		// Missing v2->v3 migration

		let data: [String: Any] = ["name": "Acme Corp"]

		do {
			_ = try manager.migrate(data: data, from: 1, to: 3)
			Issue.record("Should have thrown error")
		} catch MigrationError.noMigrationPath(let from, let to) {
			#expect(from == 2)
			#expect(to == 3)
		}
	}

	@Test("Migration preserves existing data")
	func preserveExistingData() throws {
		let manager = MigrationManager()
		manager.register(Migration_v1_to_v2())

		let data: [String: Any] = [
			"name": "Acme Corp",
			"revenue": 100_000.0,
			"employees": 50
		]

		let migrated = try manager.migrate(data: data, from: 1, to: 2)

		// All original data preserved
		#expect(migrated["name"] as? String == "Acme Corp")
		#expect(migrated["revenue"] as? Double == 100_000.0)
		#expect(migrated["employees"] as? Int == 50)
		// Plus new field
		#expect(migrated["category"] as? String == "Uncategorized")
	}

	@Test("Migration chain with data transformation")
	func migrationChainWithTransformation() throws {
		struct ComplexMigration: SchemaMigration {
			let fromVersion = 1
			let toVersion = 2
			let description = "Split name into firstName and lastName"

			func migrate(_ data: inout [String: Any]) throws {
				if let fullName = data["name"] as? String {
					let parts = fullName.components(separatedBy: " ")
					if parts.count >= 2 {
						data["firstName"] = parts[0]
						data["lastName"] = parts[1...].joined(separator: " ")
						data.removeValue(forKey: "name")
					}
				}
			}
		}

		let manager = MigrationManager()
		manager.register(ComplexMigration())

		let data: [String: Any] = [
			"name": "John Doe"
		]

		let migrated = try manager.migrate(data: data, from: 1, to: 2)

		#expect(migrated["firstName"] as? String == "John")
		#expect(migrated["lastName"] as? String == "Doe")
		#expect(migrated["name"] == nil)
	}

	// MARK: - Error Handling

	@Test("Migration throws error on invalid data")
	func migrationWithError() throws {
		struct FailingMigration: SchemaMigration {
			let fromVersion = 1
			let toVersion = 2
			let description = "Migration that fails"

			func migrate(_ data: inout [String: Any]) throws {
				guard data["requiredField"] != nil else {
					throw MigrationError.migrationFailed(
						version: 2,
						reason: "Missing required field"
					)
				}
			}
		}

		let manager = MigrationManager()
		manager.register(FailingMigration())

		let data: [String: Any] = [:]

		do {
			_ = try manager.migrate(data: data, from: 1, to: 2)
			Issue.record("Should have thrown error")
		} catch MigrationError.migrationFailed(let version, let reason) {
			#expect(version == 2)
			#expect(reason.contains("required field"))
		}
	}
}

@Suite("Additional MigrationManager Tests")
struct MigrationManagerAdditionalTests {
	
	struct M1to2: SchemaMigration {
		let fromVersion = 1
		let toVersion = 2
		let description = "Add x"
		func migrate(_ data: inout [String: Any]) throws {
			data["x"] = 1
		}
	}
	
	struct M2to3: SchemaMigration {
		let fromVersion = 2
		let toVersion = 3
		let description = "Add y"
		func migrate(_ data: inout [String: Any]) throws {
			data["y"] = 2
		}
	}
	
	struct M3to4: SchemaMigration {
		let fromVersion = 3
		let toVersion = 4
		let description = "Add z"
		func migrate(_ data: inout [String: Any]) throws {
			data["z"] = 3
		}
	}
	
	@Test("Migrations can be registered in any order")
	func registrationOrderIndependence() throws {
		let manager = MigrationManager()
			// Intentionally register out of order
		manager.register(M3to4())
		manager.register(M1to2())
		manager.register(M2to3())
		
		let data: [String: Any] = ["name": "Acme"]
		let migrated = try manager.migrate(data: data, from: 1, to: 4)
		
		#expect(migrated["x"] as? Int == 1)
		#expect(migrated["y"] as? Int == 2)
		#expect(migrated["z"] as? Int == 3)
		#expect(migrated["name"] as? String == "Acme")
	}
	
	@Test("Downgrades are rejected")
	func downgradesRejected() throws {
		let manager = MigrationManager()
		manager.register(M1to2())
		
		do {
			_ = try manager.migrate(data: [:], from: 2, to: 1)
			Issue.record("Expected downgrade to be rejected")
		} catch let MigrationError.noMigrationPath(from, to) {
				// Either (from: 2, to: 1) or a first missing hop after 2; accept either
			#expect(from >= to)
		} catch {
			Issue.record("Unexpected error: \(error)")
		}
	}
	
	@Test("Failing migration in the middle of a chain reports failing version")
		func midChainFailureReportsVersion() throws {
			struct Failing2to3: SchemaMigration {
				let fromVersion = 2
				let toVersion = 3
				let description = "Always fails"
				func migrate(_ data: inout [String: Any]) throws {
					throw MigrationError.migrationFailed(version: 3, reason: "Forced failure")
				}
			}

			let manager = MigrationManager()
			manager.register(M1to2())
			manager.register(Failing2to3())

			do {
				_ = try manager.migrate(data: [:], from: 1, to: 3)
				Issue.record("Expected migration to fail at v3")
			} catch MigrationError.migrationFailed(let version, let reason) {
				#expect(version == 3)
				#expect(reason.contains("Forced"))
			} catch {
				Issue.record("Unexpected error: \(error)")
			}
		}

		@Test("Same-version migration is a no-op even when migrations exist")
		func sameVersionIsNoOp() throws {
			let manager = MigrationManager()
			manager.register(M1to2())

			let data: [String: Any] = ["a": 1]
			let migrated = try manager.migrate(data: data, from: 1, to: 1)

			#expect(migrated["a"] as? Int == 1)
			#expect(migrated.count == data.count)
		}
}
