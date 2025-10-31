import Testing
import Foundation
@testable import BusinessMath

@Suite("Audit Trail Tests")
struct AuditTrailTests {

	// MARK: - Basic Operations

	@Test("Record audit entry")
	func recordEntry() throws {
		let manager = AuditTrailManager()

		let entry = AuditEntry(
			user: "john.doe",
			action: .created,
			entityId: "TEST",
			accountId: "Revenue",
			period: Period.quarter(year: 2024, quarter: 1),
			oldValue: nil,
			newValue: 100_000,
			reason: "Initial setup"
		)

		manager.record(entry)

		let entries = manager.query()
		#expect(entries.count == 1)
		#expect(entries[0].user == "john.doe")
		#expect(entries[0].action == .created)
	}

	@Test("Query by entity")
	func queryByEntity() throws {
		let manager = AuditTrailManager()

		manager.record(AuditEntry(
			user: "user1",
			action: .created,
			entityId: "AAPL"
		))

		manager.record(AuditEntry(
			user: "user2",
			action: .updated,
			entityId: "MSFT"
		))

		manager.record(AuditEntry(
			user: "user3",
			action: .created,
			entityId: "AAPL"
		))

		let aaplEntries = manager.query(entity: "AAPL")
		#expect(aaplEntries.count == 2)
		#expect(aaplEntries.allSatisfy { $0.entityId == "AAPL" })
	}

	@Test("Query by date range")
	func queryByDateRange() throws {
		let manager = AuditTrailManager()

		let now = Date()
		let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
		let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

		manager.record(AuditEntry(
			timestamp: yesterday,
			user: "user1",
			action: .created,
			entityId: "TEST"
		))

		manager.record(AuditEntry(
			timestamp: now,
			user: "user2",
			action: .updated,
			entityId: "TEST"
		))

		let todayEntries = manager.query(from: now, to: tomorrow)
		#expect(todayEntries.count == 1)
		#expect(todayEntries[0].user == "user2")
	}

	@Test("Query by user")
	func queryByUser() throws {
		let manager = AuditTrailManager()

		manager.record(AuditEntry(user: "alice", action: .created, entityId: "TEST"))
		manager.record(AuditEntry(user: "bob", action: .updated, entityId: "TEST"))
		manager.record(AuditEntry(user: "alice", action: .deleted, entityId: "TEST"))

		let aliceEntries = manager.query(user: "alice")
		#expect(aliceEntries.count == 2)
		#expect(aliceEntries.allSatisfy { $0.user == "alice" })
	}

	@Test("Query by action type")
	func queryByAction() throws {
		let manager = AuditTrailManager()

		manager.record(AuditEntry(user: "user1", action: .created, entityId: "TEST"))
		manager.record(AuditEntry(user: "user2", action: .updated, entityId: "TEST"))
		manager.record(AuditEntry(user: "user3", action: .created, entityId: "TEST"))

		let createdEntries = manager.query(action: .created)
		#expect(createdEntries.count == 2)
		#expect(createdEntries.allSatisfy { $0.action == .created })
	}

	@Test("Query with multiple filters")
	func queryMultipleFilters() throws {
		let manager = AuditTrailManager()

		let now = Date()

		manager.record(AuditEntry(
			timestamp: now,
			user: "alice",
			action: .created,
			entityId: "AAPL"
		))

		manager.record(AuditEntry(
			timestamp: now,
			user: "alice",
			action: .updated,
			entityId: "MSFT"
		))

		manager.record(AuditEntry(
			timestamp: now,
			user: "bob",
			action: .created,
			entityId: "AAPL"
		))

		let filtered = manager.query(
			entity: "AAPL",
			user: "alice",
			action: .created
		)

		#expect(filtered.count == 1)
		#expect(filtered[0].user == "alice")
		#expect(filtered[0].entityId == "AAPL")
		#expect(filtered[0].action == .created)
	}

	// MARK: - Audit Report

	@Test("Generate audit report")
	func generateReport() throws {
		let manager = AuditTrailManager()

		let start = Date()
		Thread.sleep(forTimeInterval: 0.01)

		manager.record(AuditEntry(user: "user1", action: .created, entityId: "TEST"))
		manager.record(AuditEntry(user: "user2", action: .updated, entityId: "TEST"))
		manager.record(AuditEntry(user: "user3", action: .created, entityId: "TEST"))

		Thread.sleep(forTimeInterval: 0.01)
		let end = Date()

		let report = manager.generateReport(
			for: DateInterval(start: start, end: end)
		)

		#expect(report.entries.count == 3)
		#expect(report.summary["created"] == 2)
		#expect(report.summary["updated"] == 1)
	}

	@Test("Audit report format")
	func reportFormat() throws {
		let manager = AuditTrailManager()

		manager.record(AuditEntry(user: "user1", action: .created, entityId: "TEST"))
		manager.record(AuditEntry(user: "user2", action: .updated, entityId: "TEST"))

		let now = Date()
		let report = manager.generateReport(
			for: DateInterval(start: now.addingTimeInterval(-3600), end: now)
		)

		let formatted = report.format()

		#expect(formatted.contains("Audit Report"))
		#expect(formatted.contains("Total Entries: 2"))
		#expect(formatted.contains("created"))
		#expect(formatted.contains("updated"))
	}

	// MARK: - Persistence

	@Test("Save and load from disk")
	func persistence() throws {
		let tempDir = FileManager.default.temporaryDirectory
		let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
		defer { try? FileManager.default.removeItem(at: fileURL) }

		// Create manager with storage
		let manager1 = AuditTrailManager(storageURL: fileURL)

		manager1.record(AuditEntry(
			user: "user1",
			action: .created,
			entityId: "TEST",
			oldValue: nil,
			newValue: 100_000
		))

		// Create new manager pointing to same file
		let manager2 = AuditTrailManager(storageURL: fileURL)

		let entries = manager2.query()
		#expect(entries.count == 1)
		#expect(entries[0].user == "user1")
		#expect(entries[0].newValue == 100_000)
	}

	@Test("Clear audit trail")
	func clearTrail() throws {
		let manager = AuditTrailManager()

		manager.record(AuditEntry(user: "user1", action: .created, entityId: "TEST"))
		manager.record(AuditEntry(user: "user2", action: .updated, entityId: "TEST"))

		#expect(manager.query().count == 2)

		manager.clear()

		#expect(manager.query().isEmpty)
	}
}
