//
//  AccountType.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

// MARK: - AccountType

/// The fundamental type of a financial account.
///
/// AccountType classifies accounts by their role in financial statements.
/// This classification determines how accounts are aggregated and reported.
///
/// ## Account Categories
///
/// **Income Statement Accounts**
/// - ``revenue``: Income from business operations
/// - ``expense``: Costs of doing business
///
/// **Balance Sheet Accounts**
/// - ``asset``: Resources owned by the business
/// - ``liability``: Obligations owed to others
/// - ``equity``: Owner's stake in the business
///
/// **Cash Flow Statement Accounts**
/// - ``operating``: Cash from core business activities
/// - ``investing``: Cash from buying/selling assets
/// - ``financing``: Cash from debt and equity
///
/// ## Example
/// ```swift
/// let revenueAccount = Account(name: "Sales", type: .revenue, timeSeries: salesTS)
/// let assetAccount = Account(name: "Cash", type: .asset, subtype: .cashAndEquivalents, timeSeries: cashTS)
/// ```
public enum AccountType: String, Codable, Equatable, Sendable {
	// MARK: - Income Statement Accounts

	/// Revenue accounts represent income from business operations.
	///
	/// Examples: Sales Revenue, Service Revenue, Interest Income, Other Income
	case revenue

	/// Expense accounts represent costs of doing business.
	///
	/// Examples: Cost of Goods Sold, Operating Expenses, Interest Expense, Taxes
	case expense

	// MARK: - Balance Sheet Accounts

	/// Asset accounts represent resources owned by the business.
	///
	/// Examples: Cash, Accounts Receivable, Inventory, Equipment, Buildings
	case asset

	/// Liability accounts represent obligations owed to others.
	///
	/// Examples: Accounts Payable, Loans Payable, Bonds, Deferred Revenue
	case liability

	/// Equity accounts represent the owner's stake in the business.
	///
	/// Examples: Common Stock, Retained Earnings, Additional Paid-In Capital
	case equity

	// MARK: - Cash Flow Statement Accounts

	/// Operating cash flow from core business activities.
	///
	/// Examples: Cash from customers, Cash to suppliers, Cash for operating expenses
	case operating

	/// Investing cash flow from buying/selling long-term assets.
	///
	/// Examples: Purchase of equipment, Sale of investments, Capital expenditures
	case investing

	/// Financing cash flow from debt and equity transactions.
	///
	/// Examples: Issuing stock, Borrowing money, Paying dividends, Repaying debt
	case financing
}

// MARK: - AssetType

/// Subcategory for asset accounts.
///
/// Provides granular classification of assets for balance sheet calculations
/// without relying on string-based metadata.
///
/// ## Example
/// ```swift
/// let cash = Account(name: "Cash", type: .asset, subtype: .cashAndEquivalents, ...)
/// let inventory = Account(name: "Inventory", type: .asset, subtype: .inventory, ...)
/// ```
public enum AssetType: String, Codable, Equatable, Sendable {
	// MARK: - Current Assets

	/// Cash and cash equivalents (liquid assets).
	case cashAndEquivalents

	/// Accounts receivable (amounts owed by customers).
	case accountsReceivable

	/// Inventory (goods held for sale).
	case inventory

	/// Other current assets (prepaid expenses, etc.).
	case otherCurrentAsset

	// MARK: - Long-Term Assets

	/// Property, plant, and equipment (fixed assets).
	case propertyPlantEquipment

	/// Intangible assets (patents, goodwill, etc.).
	case intangibleAssets

	/// Long-term investments.
	case investments

	/// Other long-term assets.
	case otherLongTermAsset
}

// MARK: - LiabilityType

/// Subcategory for liability accounts.
///
/// Provides granular classification of liabilities for balance sheet and
/// leverage calculations without relying on string-based metadata.
///
/// ## Example
/// ```swift
/// let debt = Account(name: "Senior Notes", type: .liability, subtype: .longTermDebt, ...)
/// let ap = Account(name: "Accounts Payable", type: .liability, subtype: .accountsPayable, ...)
/// ```
public enum LiabilityType: String, Codable, Equatable, Sendable {
	// MARK: - Current Liabilities

	/// Accounts payable (amounts owed to suppliers).
	case accountsPayable

	/// Accrued expenses (wages, utilities, etc.).
	case accruedExpenses

	/// Short-term debt (debt maturing within 1 year).
	case shortTermDebt

	/// Current portion of long-term debt.
	case currentPortionLongTermDebt

	/// Other current liabilities.
	case otherCurrentLiability

	// MARK: - Long-Term Liabilities

	/// Long-term debt (loans, term debt).
	case longTermDebt

	/// Bonds payable.
	case bonds

	/// Capital lease obligations.
	case capitalLeases

	/// Preferred stock (treated as quasi-debt for capital structure).
	case preferredStock

	/// Other long-term liabilities.
	case otherLongTermLiability
}

// MARK: - ExpenseType

/// Subcategory for expense accounts.
///
/// Provides granular classification of expenses for income statement
/// calculations without relying on string-based metadata.
///
/// ## Example
/// ```swift
/// let cogs = Account(name: "Cost of Goods Sold", type: .expense, subtype: .costOfGoodsSold, ...)
/// let interest = Account(name: "Interest Expense", type: .expense, subtype: .interestExpense, ...)
/// ```
public enum ExpenseType: String, Codable, Equatable, Sendable {
	/// Cost of goods sold (direct costs of production).
	case costOfGoodsSold

	/// Operating expenses (SG&A, R&D, etc.).
	case operatingExpense

	/// Depreciation and amortization.
	case depreciationAmortization

	/// Interest expense.
	case interestExpense

	/// Tax expense.
	case taxExpense
}

// MARK: - EquityType

/// Subcategory for equity accounts.
///
/// Provides granular classification of equity for balance sheet calculations
/// without relying on string-based metadata.
///
/// ## Example
/// ```swift
/// let stock = Account(name: "Common Stock", type: .equity, subtype: .commonStock, ...)
/// let retained = Account(name: "Retained Earnings", type: .equity, subtype: .retainedEarnings, ...)
/// ```
public enum EquityType: String, Codable, Equatable, Sendable {
	/// Common stock (par value + additional paid-in capital).
	case commonStock

	/// Retained earnings (accumulated profits).
	case retainedEarnings

	/// Additional paid-in capital (APIC).
	case additionalPaidInCapital

	/// Treasury stock (repurchased shares).
	case treasuryStock

	/// Accumulated other comprehensive income (AOCI).
	case accumulatedOtherComprehensiveIncome
}

// MARK: - AccountCategory

/// Higher-level categorization of accounts.
///
/// AccountCategory groups related account types into the three main
/// financial statements: Income Statement, Balance Sheet, and Cash Flow Statement.
///
/// ## Example
/// ```swift
/// let type = AccountType.revenue
/// let category = type.category  // .incomeStatement
/// ```
public enum AccountCategory: String, Codable, Equatable, Sendable {
	/// Accounts that appear on the Income Statement (P&L).
	case incomeStatement

	/// Accounts that appear on the Balance Sheet.
	case balanceSheet

	/// Accounts that appear on the Cash Flow Statement.
	case cashFlowStatement
}

// MARK: - AccountType + Category

extension AccountType {
	/// Returns the high-level category this account type belongs to.
	///
	/// ## Example
	/// ```swift
	/// AccountType.revenue.category  // .incomeStatement
	/// AccountType.asset.category    // .balanceSheet
	/// AccountType.operating.category // .cashFlowStatement
	/// ```
	public var category: AccountCategory {
		switch self {
		case .revenue, .expense:
			return .incomeStatement
		case .asset, .liability, .equity:
			return .balanceSheet
		case .operating, .investing, .financing:
			return .cashFlowStatement
		}
	}

	/// Returns true if this is an income statement account type.
	public var isIncomeStatement: Bool {
		return category == .incomeStatement
	}

	/// Returns true if this is a balance sheet account type.
	public var isBalanceSheet: Bool {
		return category == .balanceSheet
	}

	/// Returns true if this is a cash flow statement account type.
	public var isCashFlow: Bool {
		return category == .cashFlowStatement
	}
}

// MARK: - Normal Balance

extension AccountType {
	/// The normal balance direction for this account type.
	///
	/// In double-entry bookkeeping:
	/// - **Debit accounts**: Assets and Expenses (increases are positive)
	/// - **Credit accounts**: Liabilities, Equity, and Revenue (increases are positive)
	///
	/// This is used for validation and accounting equation checks.
	///
	/// ## Example
	/// ```swift
	/// AccountType.asset.isDebitAccount     // true
	/// AccountType.revenue.isCreditAccount  // true
	/// ```
	public var isDebitAccount: Bool {
		switch self {
		case .asset, .expense:
			return true
		case .liability, .equity, .revenue:
			return false
		case .operating, .investing, .financing:
			return true  // Cash flows are typically presented as net changes
		}
	}

	/// Returns true if this is a credit account (liability, equity, or revenue).
	public var isCreditAccount: Bool {
		return !isDebitAccount
	}
}
