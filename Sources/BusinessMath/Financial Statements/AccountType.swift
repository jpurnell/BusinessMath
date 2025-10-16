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
/// let assetAccount = Account(name: "Cash", type: .asset, timeSeries: cashTS)
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
