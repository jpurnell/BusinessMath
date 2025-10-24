//
//  Account.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - AccountError

/// Errors that can occur when creating or manipulating accounts.
public enum AccountError: Error, Sendable {
	/// The account name is invalid (empty or whitespace only)
	case invalidName

	/// The time series is empty (no periods)
	case emptyTimeSeries

	/// The account type doesn't match expected category
	case invalidAccountType(expected: AccountCategory, actual: AccountType)
}

// MARK: - AccountMetadata

/// Metadata for categorizing and describing an account.
///
/// Use metadata to provide additional context about accounts that can be used
/// for filtering, grouping, and reporting.
///
/// ## Example
/// ```swift
/// var metadata = AccountMetadata()
/// metadata.description = "Primary revenue from product sales"
/// metadata.category = "Sales"
/// metadata.subCategory = "Product Revenue"
/// metadata.tags = ["recurring", "core"]
/// metadata.externalId = "ACCT-1001"
/// ```
public struct AccountMetadata: Codable, Equatable, Sendable {
	/// Detailed description of the account
	public var description: String?

	/// High-level category (e.g., "COGS", "Operating Expenses", "Current Assets")
	public var category: String?

	/// Subcategory for finer granularity (e.g., "Salaries", "Marketing", "Inventory")
	public var subCategory: String?

	/// Tags for flexible grouping and filtering
	public var tags: [String]

	/// External system identifier for data integration
	public var externalId: String?

	/// Creates empty metadata.
	public init() {
		self.tags = []
	}

	/// Creates metadata with the specified properties.
	///
	/// - Parameters:
	///   - description: Account description
	///   - category: High-level category
	///   - subCategory: Subcategory
	///   - tags: Tags for grouping
	///   - externalId: External system identifier
	public init(
		description: String? = nil,
		category: String? = nil,
		subCategory: String? = nil,
		tags: [String] = [],
		externalId: String? = nil
	) {
		self.description = description
		self.category = category
		self.subCategory = subCategory
		self.tags = tags
		self.externalId = externalId
	}
}

// MARK: - Account

/// A financial account belonging to a specific entity.
///
/// `Account` combines an ``Entity``, ``AccountType``, and ``TimeSeries`` to represent
/// a financial account over multiple time periods. Accounts are the building blocks
/// of financial statements.
///
/// ## Creating Accounts
///
/// ```swift
/// let apple = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
///
/// let periods = [
///     Period.quarter(year: 2024, quarter: 1),
///     Period.quarter(year: 2024, quarter: 2),
///     Period.quarter(year: 2024, quarter: 3),
///     Period.quarter(year: 2024, quarter: 4)
/// ]
///
/// let values: [Double] = [90_000, 95_000, 100_000, 105_000]
/// let revenueSeries = TimeSeries(periods: periods, values: values)
///
/// let revenueAccount = try Account(
///     entity: apple,
///     name: "Product Revenue",
///     type: .revenue,
///     timeSeries: revenueSeries
/// )
/// ```
///
/// ## Adding Metadata
///
/// ```swift
/// var metadata = AccountMetadata()
/// metadata.category = "Sales"
/// metadata.tags = ["recurring", "core"]
///
/// let account = try Account(
///     entity: apple,
///     name: "Subscription Revenue",
///     type: .revenue,
///     timeSeries: revenueSeries,
///     metadata: metadata
/// )
/// ```
///
/// ## Accessing Values
///
/// ```swift
/// let q1 = Period.quarter(year: 2024, quarter: 1)
/// if let value = account.timeSeries[q1] {
///     print("Q1 Revenue: \(value)")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Accounts
/// - ``init(entity:name:type:timeSeries:metadata:)``
///
/// ### Properties
/// - ``entity``
/// - ``name``
/// - ``type``
/// - ``timeSeries``
/// - ``metadata``
///
/// ### Account Categorization
/// - ``isIncomeStatement``
/// - ``isBalanceSheet``
/// - ``isCashFlow``
public struct Account<T: Real & Sendable>: Codable, Sendable where T: Codable {

	/// The entity that owns this account.
	public let entity: Entity

	/// The name of this account.
	public let name: String

	/// The type of this account (revenue, expense, asset, etc.).
	public let type: AccountType

	/// The time series of values for this account.
	public let timeSeries: TimeSeries<T>

	/// Subtype for asset accounts (nil for non-asset accounts).
	public let assetType: AssetType?

	/// Subtype for liability accounts (nil for non-liability accounts).
	public let liabilityType: LiabilityType?

	/// Subtype for expense accounts (nil for non-expense accounts).
	public let expenseType: ExpenseType?

	/// Subtype for equity accounts (nil for non-equity accounts).
	public let equityType: EquityType?

	/// Optional metadata for categorization and description.
	public var metadata: AccountMetadata?

	/// Creates a new account with validation.
	///
	/// - Parameters:
	///   - entity: The entity that owns this account
	///   - name: The account name (must not be empty)
	///   - type: The account type
	///   - timeSeries: The time series of values (must not be empty)
	///   - assetType: Subtype for asset accounts (required if type is .asset)
	///   - liabilityType: Subtype for liability accounts (required if type is .liability)
	///   - expenseType: Subtype for expense accounts (required if type is .expense)
	///   - equityType: Subtype for equity accounts (required if type is .equity)
	///   - metadata: Optional metadata
	///
	/// - Throws: ``AccountError/invalidName`` if name is empty
	/// - Throws: ``AccountError/emptyTimeSeries`` if timeSeries has no periods
	public init(
		entity: Entity,
		name: String,
		type: AccountType,
		timeSeries: TimeSeries<T>,
		assetType: AssetType? = nil,
		liabilityType: LiabilityType? = nil,
		expenseType: ExpenseType? = nil,
		equityType: EquityType? = nil,
		metadata: AccountMetadata? = nil
	) throws {
		guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			throw AccountError.invalidName
		}
		guard !timeSeries.periods.isEmpty else {
			throw AccountError.emptyTimeSeries
		}

		self.entity = entity
		self.name = name
		self.type = type
		self.timeSeries = timeSeries
		self.assetType = assetType
		self.liabilityType = liabilityType
		self.expenseType = expenseType
		self.equityType = equityType
		self.metadata = metadata
	}

	// MARK: - Account Categorization

	/// Returns true if this is an income statement account.
	public var isIncomeStatement: Bool {
		return type.isIncomeStatement
	}

	/// Returns true if this is a balance sheet account.
	public var isBalanceSheet: Bool {
		return type.isBalanceSheet
	}

	/// Returns true if this is a cash flow statement account.
	public var isCashFlow: Bool {
		return type.isCashFlow
	}

	/// The high-level category this account belongs to.
	public var category: AccountCategory {
		return type.category
	}
}

// MARK: - Account + Equatable

extension Account: Equatable {
	/// Accounts are equal if they have the same entity, name, and type.
	///
	/// Note: This does not compare time series values or metadata.
	public static func == (lhs: Account<T>, rhs: Account<T>) -> Bool {
		return lhs.entity == rhs.entity &&
			lhs.name == rhs.name &&
			lhs.type == rhs.type
	}
}

// MARK: - Account + Hashable

extension Account: Hashable {
	/// Accounts hash based on entity, name, and type.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(entity)
		hasher.combine(name)
		hasher.combine(type)
	}
}

// MARK: - Account + CustomStringConvertible

extension Account: CustomStringConvertible {
	/// A textual representation of this account.
	public var description: String {
		return "\(entity.name) - \(name) (\(type))"
	}
}
