//
//  AuditTrail.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - AuditAction

/// The type of audit action performed.
public enum AuditAction: String, Codable, Sendable {
	/// Entity or account was created
	case created

	/// Entity or account was updated
	case updated

	/// Entity or account was deleted
	case deleted
}

// MARK: - AuditEntry

/// A single entry in the audit trail.
///
/// `AuditEntry` records who made a change, what was changed, when it was changed,
/// and optionally why it was changed.
public struct AuditEntry: Codable, Sendable {
	/// When the action occurred.
	public let timestamp: Date

	/// The user who performed the action.
	public let user: String

	/// The type of action performed.
	public let action: AuditAction

	/// The entity identifier.
	public let entityId: String

	/// Optional account identifier.
	public let accountId: String?

	/// Optional period affected.
	public let period: Period?

	/// The value before the change (nil for created).
	public let oldValue: Double?

	/// The value after the change (nil for deleted).
	public let newValue: Double?

	/// Optional reason for the change.
	public let reason: String?

	/// Creates an audit entry.
	///
	/// - Parameters:
	///   - timestamp: When the action occurred. Defaults to now.
	///   - user: The user who performed the action.
	///   - action: The type of action performed.
	///   - entityId: The entity identifier.
	///   - accountId: Optional account identifier.
	///   - period: Optional period affected.
	///   - oldValue: The value before the change.
	///   - newValue: The value after the change.
	///   - reason: Optional reason for the change.
	public init(
		timestamp: Date = Date(),
		user: String,
		action: AuditAction,
		entityId: String,
		accountId: String? = nil,
		period: Period? = nil,
		oldValue: Double? = nil,
		newValue: Double? = nil,
		reason: String? = nil
	) {
		self.timestamp = timestamp
		self.user = user
		self.action = action
		self.entityId = entityId
		self.accountId = accountId
		self.period = period
		self.oldValue = oldValue
		self.newValue = newValue
		self.reason = reason
	}
}

// MARK: - AuditReport

/// A report summarizing audit trail entries.
public struct AuditReport: Sendable {
	/// The entries included in this report.
	public let entries: [AuditEntry]

	/// Summary of actions by type.
	public let summary: [String: Int]

	/// Formats the report as a human-readable string.
	public func format() -> String {
		var output = "Audit Report\n"
		output += "=============\n\n"
		output += "Total Entries: \(entries.count)\n\n"

		if !summary.isEmpty {
			output += "Action Summary:\n"
			for (action, count) in summary.sorted(by: { $0.key < $1.key }) {
				output += "  \(action): \(count)\n"
			}
			output += "\n"
		}

		if !entries.isEmpty {
			output += "Entries:\n"
			for (index, entry) in entries.enumerated() {
				output += "\(index + 1). [\(entry.timestamp)] \(entry.user) - \(entry.action.rawValue) - \(entry.entityId)"
				if let account = entry.accountId {
					output += " (\(account))"
				}
				output += "\n"
			}
		}

		return output
	}
}

// MARK: - AuditTrailManager

/// Manages an audit trail of changes to financial data.
///
/// `AuditTrailManager` provides a complete audit logging system with:
/// - Recording changes with full context
/// - Querying by entity, user, date, or action
/// - Generating summary reports
/// - Optional persistence to disk
///
/// ## Basic Usage
///
/// ```swift
/// let manager = AuditTrailManager()
///
/// // Record a change
/// manager.record(AuditEntry(
///     user: "john.doe",
///     action: .updated,
///     entityId: "AAPL",
///     accountId: "Revenue",
///     period: Period.quarter(year: 2024, quarter: 1),
///     oldValue: 100_000,
///     newValue: 105_000,
///     reason: "Corrected sales figures"
/// ))
///
/// // Query entries
/// let recentChanges = manager.query(from: startDate, to: endDate)
/// let aaplChanges = manager.query(entity: "AAPL")
/// let userChanges = manager.query(user: "john.doe")
///
/// // Generate report
/// let report = manager.generateReport(for: DateInterval(start: start, end: end))
/// print(report.format())
/// ```
///
/// ## Persistence
///
/// ```swift
/// // Save to disk automatically
/// let fileURL = URL(fileURLWithPath: "/path/to/audit.json")
/// let manager = AuditTrailManager(storageURL: fileURL)
///
/// // All changes are automatically persisted
/// manager.record(entry)
///
/// // Load from disk when creating new manager
/// let loadedManager = AuditTrailManager(storageURL: fileURL)
/// ```
public final class AuditTrailManager {

	// MARK: - Properties

	private let lock = NSLock()
	private var entries: [AuditEntry] = []
	private let storageURL: URL?

	// MARK: - Initialization

	/// Creates an audit trail manager.
	///
	/// - Parameter storageURL: Optional URL to persist audit trail to disk.
	public init(storageURL: URL? = nil) {
		self.storageURL = storageURL

		// Load from disk if available
		if let url = storageURL {
			loadFromDisk(url)
		}
	}

	// MARK: - Recording

	/// Records an audit entry.
	///
	/// - Parameter entry: The audit entry to record.
	public func record(_ entry: AuditEntry) {
		lock.lock()
		defer { lock.unlock() }

		entries.append(entry)

		// Save to disk if URL is set
		if let url = storageURL {
			saveToDisk(url)
		}
	}

	// MARK: - Querying

	/// Returns all audit entries.
	public func query() -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries
	}

	/// Queries entries for a specific entity.
	///
	/// - Parameter entity: The entity identifier to filter by.
	/// - Returns: All entries for the specified entity.
	public func query(entity: String) -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries.filter { $0.entityId == entity }
	}

	/// Queries entries within a date range.
	///
	/// - Parameters:
	///   - from: Start date (inclusive).
	///   - to: End date (exclusive).
	/// - Returns: All entries within the date range.
	public func query(from: Date, to: Date) -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries.filter { entry in
			entry.timestamp >= from && entry.timestamp < to
		}
	}

	/// Queries entries by user.
	///
	/// - Parameter user: The user identifier to filter by.
	/// - Returns: All entries for the specified user.
	public func query(user: String) -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries.filter { $0.user == user }
	}

	/// Queries entries by action type.
	///
	/// - Parameter action: The action type to filter by.
	/// - Returns: All entries for the specified action.
	public func query(action: AuditAction) -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries.filter { $0.action == action }
	}

	/// Queries entries with multiple filters.
	///
	/// - Parameters:
	///   - entity: Optional entity identifier to filter by.
	///   - user: Optional user identifier to filter by.
	///   - action: Optional action type to filter by.
	/// - Returns: All entries matching all specified filters.
	public func query(entity: String? = nil, user: String? = nil, action: AuditAction? = nil) -> [AuditEntry] {
		lock.lock()
		defer { lock.unlock() }

		return entries.filter { entry in
			if let entity = entity, entry.entityId != entity {
				return false
			}
			if let user = user, entry.user != user {
				return false
			}
			if let action = action, entry.action != action {
				return false
			}
			return true
		}
	}

	// MARK: - Reporting

	/// Generates an audit report for a date range.
	///
	/// - Parameter interval: The date interval to generate a report for.
	/// - Returns: An audit report with entries and summary.
	public func generateReport(for interval: DateInterval) -> AuditReport {
		lock.lock()
		defer { lock.unlock() }

		let filteredEntries = entries.filter { entry in
			interval.contains(entry.timestamp)
		}

		// Generate summary
		var summary: [String: Int] = [:]
		for entry in filteredEntries {
			let actionKey = entry.action.rawValue
			summary[actionKey, default: 0] += 1
		}

		return AuditReport(entries: filteredEntries, summary: summary)
	}

	// MARK: - Management

	/// Clears all audit entries.
	public func clear() {
		lock.lock()
		defer { lock.unlock() }

		entries.removeAll()

		// Clear disk storage if URL is set
		if let url = storageURL {
			saveToDisk(url)
		}
	}

	// MARK: - Persistence

	private func saveToDisk(_ url: URL) {
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let data = try encoder.encode(entries)
			try data.write(to: url)
		} catch {
			// In production, this should be logged
			print("Failed to save audit trail: \(error)")
		}
	}

	private func loadFromDisk(_ url: URL) {
		guard FileManager.default.fileExists(atPath: url.path) else {
			return
		}

		do {
			let data = try Data(contentsOf: url)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			entries = try decoder.decode([AuditEntry].self, from: data)
		} catch {
			// In production, this should be logged
			print("Failed to load audit trail: \(error)")
			entries = []
		}
	}
}
