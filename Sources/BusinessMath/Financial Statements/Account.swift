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
public enum AccountError: Error, Sendable, Equatable {
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
/// `Account` uses a role-based system where each account declares its role(s) in financial statements.
/// An account can have one, two, or even all three roles depending on how it appears across statements.
///
/// ## Multi-Role System (v2.0+)
///
/// Accounts now support **multiple roles** across statements:
///
/// ```swift
/// // Single role: Revenue appears only in Income Statement
/// let revenue = try Account(
///     entity: apple,
///     name: "Product Revenue",
///     incomeStatementRole: .productRevenue,
///     timeSeries: revenueSeries
/// )
///
/// // Multi-role: Depreciation appears in both IS and CFS
/// let depreciation = try Account(
///     entity: apple,
///     name: "Depreciation & Amortization",
///     incomeStatementRole: .depreciationAmortization,
///     cashFlowRole: .depreciationAmortizationAddback,
///     timeSeries: daSeries
/// )
///
/// // Multi-role: Inventory appears in both BS and CFS
/// let inventory = try Account(
///     entity: apple,
///     name: "Inventory",
///     balanceSheetRole: .inventory,
///     cashFlowRole: .changeInInventory,
///     timeSeries: inventorySeries
/// )
/// ```
///
/// ## Role Requirements
///
/// Every account must have **at least one role**:
/// - `incomeStatementRole`: Appears in Income Statement
/// - `balanceSheetRole`: Appears in Balance Sheet
/// - `cashFlowRole`: Appears in Cash Flow Statement
///
/// ## Deprecated API
///
/// The old `AccountType` system is deprecated but still functional:
///
/// ```swift
/// // Old API (deprecated, but still works)
/// let oldAccount = try Account(
///     entity: apple,
///     name: "Revenue",
///     type: .revenue,  // Automatically migrates to .revenue role
///     timeSeries: revenueSeries
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Accounts
/// - ``init(entity:name:incomeStatementRole:balanceSheetRole:cashFlowRole:timeSeries:metadata:)``
/// - ``init(entity:name:type:timeSeries:assetType:liabilityType:expenseType:equityType:metadata:)``
///
/// ### Properties
/// - ``entity``
/// - ``name``
/// - ``incomeStatementRole``
/// - ``balanceSheetRole``
/// - ``cashFlowRole``
/// - ``timeSeries``
/// - ``metadata``
///
/// ### Deprecated Properties
/// - ``type``
/// - ``assetType``
/// - ``liabilityType``
/// - ``expenseType``
/// - ``equityType``
public struct Account<T: Real & Sendable>: Codable, Sendable where T: Codable {

	/// The entity that owns this account.
	public let entity: Entity

	/// The name of this account.
	public let name: String

	// MARK: - Multi-Role Properties (v2.0+)

	/// Role in Income Statement (nil if not applicable)
	///
	/// Use this to specify how the account appears in an Income Statement.
	/// Examples: `.revenue`, `.costOfGoodsSold`, `.researchAndDevelopment`
	public let incomeStatementRole: IncomeStatementRole?

	/// Role in Balance Sheet (nil if not applicable)
	///
	/// Use this to specify how the account appears in a Balance Sheet.
	/// Examples: `.cashAndEquivalents`, `.inventory`, `.longTermDebt`
	public let balanceSheetRole: BalanceSheetRole?

	/// Role in Cash Flow Statement (nil if not applicable)
	///
	/// Use this to specify how the account appears in a Cash Flow Statement.
	/// Examples: `.netIncome`, `.capitalExpenditures`, `.changeInReceivables`
	public let cashFlowRole: CashFlowRole?

	/// The time series of values for this account.
	public let timeSeries: TimeSeries<T>

	/// Optional metadata for categorization and description.
	public var metadata: AccountMetadata?

//	// MARK: - Deprecated Properties
//
//	/// The type of this account (revenue, expense, asset, etc.).
//	///
//	/// - Warning: Deprecated in v2.0. Use statement-specific roles instead.
//	@available(*, deprecated, message: "Use incomeStatementRole, balanceSheetRole, or cashFlowRole instead")
//	public let type: AccountType
//
//	/// Subtype for asset accounts (nil for non-asset accounts).
//	///
//	/// - Warning: Deprecated in v2.0. Use balanceSheetRole instead.
//	@available(*, deprecated, message: "Use balanceSheetRole instead")
//	public let assetType: AssetType?
//
//	/// Subtype for liability accounts (nil for non-liability accounts).
//	///
//	/// - Warning: Deprecated in v2.0. Use balanceSheetRole instead.
//	@available(*, deprecated, message: "Use balanceSheetRole instead")
//	public let liabilityType: LiabilityType?
//
//	/// Subtype for expense accounts (nil for non-expense accounts).
//	///
//	/// - Warning: Deprecated in v2.0. Use incomeStatementRole instead.
//	@available(*, deprecated, message: "Use incomeStatementRole instead")
//	public let expenseType: ExpenseType?
//
//	/// Subtype for equity accounts (nil for non-equity accounts).
//	///
//	/// - Warning: Deprecated in v2.0. Use balanceSheetRole instead.
//	@available(*, deprecated, message: "Use balanceSheetRole instead")
//	public let equityType: EquityType?

	// MARK: - New Initializer (v2.0+)

	/// Creates a new account with role-based categorization.
	///
	/// At least one role must be specified. Accounts can have multiple roles
	/// if they appear in multiple financial statements.
	///
	/// - Parameters:
	///   - entity: The entity that owns this account
	///   - name: The account name (must not be empty)
	///   - incomeStatementRole: Optional role in Income Statement
	///   - balanceSheetRole: Optional role in Balance Sheet
	///   - cashFlowRole: Optional role in Cash Flow Statement
	///   - timeSeries: The time series of values (must not be empty)
	///   - metadata: Optional metadata
	///
	/// - Throws: ``AccountError/invalidName`` if name is empty
	/// - Throws: ``AccountError/emptyTimeSeries`` if timeSeries has no periods
	/// - Throws: ``FinancialModelError/accountMustHaveAtLeastOneRole`` if all roles are nil
	public init(
		entity: Entity,
		name: String,
		incomeStatementRole: IncomeStatementRole? = nil,
		balanceSheetRole: BalanceSheetRole? = nil,
		cashFlowRole: CashFlowRole? = nil,
		timeSeries: TimeSeries<T>,
		metadata: AccountMetadata? = nil
	) throws {
		// Validate name
		guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			throw AccountError.invalidName
		}

		// Validate time series
		guard !timeSeries.periods.isEmpty else {
			throw AccountError.emptyTimeSeries
		}

		// Validate at least one role is specified
		guard incomeStatementRole != nil || balanceSheetRole != nil || cashFlowRole != nil else {
			throw FinancialModelError.accountMustHaveAtLeastOneRole
		}

		self.entity = entity
		self.name = name
		self.incomeStatementRole = incomeStatementRole
		self.balanceSheetRole = balanceSheetRole
		self.cashFlowRole = cashFlowRole
		self.timeSeries = timeSeries
		self.metadata = metadata
	}

	// MARK: - Migration Helpers

	/// Migrates old AccountType to new IncomeStatementRole
	private static func migrateToIncomeStatementRole(type: AccountType, expenseType: ExpenseType? = nil) -> IncomeStatementRole? {
		switch type {
		case .revenue:
			return .revenue
		case .expense:
			// Map expenseType to appropriate IncomeStatementRole
			if let expenseType = expenseType {
				switch expenseType {
				case .costOfGoodsSold:
					return .costOfGoodsSold
				case .operatingExpense:
					return .operatingExpenseOther
				case .depreciationAmortization:
					return .depreciationAmortization
				case .interestExpense:
					return .interestExpense
				case .taxExpense:
					return .incomeTaxExpense
				}
			}
			return .operatingExpenseOther  // Generic expense mapping if no expenseType
		case .operating, .investing, .financing:
			// Cash flow types should not have income statement roles
			return nil
		default:
			return nil
		}
	}

	/// Migrates old AccountType to new BalanceSheetRole
	private static func migrateToBalanceSheetRole(
		type: AccountType,
		assetType: AssetType?,
		liabilityType: LiabilityType?
	) -> BalanceSheetRole? {
		switch type {
		case .asset:
			// Map AssetType to BalanceSheetRole
			if let assetType = assetType {
				switch assetType {
				case .cashAndEquivalents:
					return .cashAndEquivalents
				case .accountsReceivable:
					return .accountsReceivable
				case .inventory:
					return .inventory
				case .propertyPlantEquipment:
					return .propertyPlantEquipment
				case .intangibleAssets:
					return .intangibleAssets
				case .investments:
					return .longTermInvestments
				case .otherCurrentAsset:
					return .otherCurrentAssets
				case .otherLongTermAsset:
					return .otherNonCurrentAssets
				}
			}
			return .otherCurrentAssets

		case .liability:
			// Map LiabilityType to BalanceSheetRole
			if let liabilityType = liabilityType {
				switch liabilityType {
				case .accountsPayable:
					return .accountsPayable
				case .accruedExpenses:
					return .accruedLiabilities
				case .shortTermDebt:
					return .shortTermDebt
				case .currentPortionLongTermDebt:
					return .currentPortionLongTermDebt
				case .otherCurrentLiability:
					return .otherCurrentLiabilities
				case .longTermDebt:
					return .longTermDebt
				case .bonds:
					return .longTermDebt  // Map bonds to long-term debt
				case .capitalLeases:
					return .leaseLiabilities
				case .preferredStock:
					return .preferredStock  // Actually equity
				case .otherLongTermLiability:
					return .otherNonCurrentLiabilities
				}
			}
			return .otherCurrentLiabilities

		case .equity:
			return .retainedEarnings  // Generic equity mapping

		default:
			return nil
		}
	}

	/// Migrates old AccountType to new CashFlowRole
	private static func migrateToCashFlowRole(type: AccountType) -> CashFlowRole? {
		switch type {
		case .operating:
			return .otherOperatingActivities
		case .investing:
			return .otherInvestingActivities
		case .financing:
			return .otherFinancingActivities
		default:
			return nil
		}
	}

	/// Infers AccountType from new roles (for backward compatibility)
	private static func inferAccountType(
		incomeStatementRole: IncomeStatementRole?,
		balanceSheetRole: BalanceSheetRole?,
		cashFlowRole: CashFlowRole?
	) -> AccountType {
		// Priority: IS > BS > CFS
		if let isRole = incomeStatementRole {
			return isRole.isRevenue ? .revenue : .expense
		}
		if let bsRole = balanceSheetRole {
			if bsRole.isAsset { return .asset }
			if bsRole.isLiability { return .liability }
			if bsRole.isEquity { return .equity }
		}
		if let cfRole = cashFlowRole {
			if cfRole.isOperating { return .operating }
			if cfRole.isInvesting { return .investing }
			if cfRole.isFinancing { return .financing }
		}
		return .expense  // Default fallback
	}

	/// Infers AssetType from BalanceSheetRole (for backward compatibility)
	private static func inferAssetType(from role: BalanceSheetRole?) -> AssetType? {
		guard let role = role else { return nil }

		switch role {
		case .cashAndEquivalents:
			return .cashAndEquivalents
		case .accountsReceivable:
			return .accountsReceivable
		case .inventory:
			return .inventory
		case .propertyPlantEquipment, .accumulatedDepreciation:
			return .propertyPlantEquipment
		case .intangibleAssets, .goodwill:
			return .intangibleAssets
		case .longTermInvestments:
			return .investments
		case .otherCurrentAssets, .prepaidExpenses:
			return .otherCurrentAsset
		case .otherNonCurrentAssets, .deferredTaxAssets, .rightOfUseAssets:
			return .otherLongTermAsset
		default:
			return nil
		}
	}

	/// Infers LiabilityType from BalanceSheetRole (for backward compatibility)
	private static func inferLiabilityType(from role: BalanceSheetRole?) -> LiabilityType? {
		guard let role = role else { return nil }

		switch role {
		case .accountsPayable:
			return .accountsPayable
		case .accruedLiabilities:
			return .accruedExpenses
		case .shortTermDebt:
			return .shortTermDebt
		case .currentPortionLongTermDebt:
			return .currentPortionLongTermDebt
		case .otherCurrentLiabilities, .deferredRevenue:
			return .otherCurrentLiability
		case .longTermDebt:
			return .longTermDebt
		case .leaseLiabilities:
			return .capitalLeases
		case .otherNonCurrentLiabilities, .deferredTaxLiabilities, .pensionLiabilities:
			return .otherLongTermLiability
		default:
			return nil
		}
	}

	// MARK: - Account Categorization

	/// Returns true if this is an income statement account.
	public var isIncomeStatement: Bool {
		return incomeStatementRole != nil
	}

	/// Returns true if this is a balance sheet account.
	public var isBalanceSheet: Bool {
		return balanceSheetRole != nil
	}

	/// Returns true if this is a cash flow statement account.
	public var isCashFlow: Bool {
		return cashFlowRole != nil
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
			lhs.incomeStatementRole == rhs.incomeStatementRole &&
			lhs.balanceSheetRole == rhs.balanceSheetRole &&
			lhs.cashFlowRole == rhs.cashFlowRole
	}
}

// MARK: - Account + Hashable

extension Account: Hashable {
	/// Accounts hash based on entity, name, and type.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(entity)
		hasher.combine(name)
		hasher.combine(incomeStatementRole)
		hasher.combine(balanceSheetRole)
		hasher.combine(cashFlowRole)
	}
}

// MARK: - Account + CustomStringConvertible

extension Account: CustomStringConvertible {
	/// A textual representation of this account.
	public var description: String {
		let role = "\(incomeStatementRole?.description ?? "") | \(balanceSheetRole?.description ?? "") | \(cashFlowRole?.description ?? "")"
		return "\(entity.name) - \(name) (\(role))"
	}
}
