import Foundation

/// Granular roles for accounts appearing in Income Statements
///
/// This enum provides precise categorization for revenue, expense, and tax accounts
/// within an Income Statement. Each role enables automated aggregation and analysis
/// without relying on string-based account name matching.
///
/// # Role Categories
///
/// **Revenue**: All income-generating activities
/// - Generic revenue and specific types (product, service, subscription, licensing)
/// - Interest income from investments
///
/// **Cost of Revenue**: Direct costs of delivering products/services
/// - Manufacturing costs (COGS)
/// - Service delivery costs
///
/// **Operating Expenses**: Costs of running the business
/// - R&D, Sales & Marketing, General & Administrative
/// - Other operating expenses
///
/// **Non-Cash Charges**: Accounting expenses without cash outflow
/// - Depreciation & Amortization
/// - Impairments, stock-based compensation, restructuring charges
///
/// **Non-Operating**: Items outside core business operations
/// - Interest expense, foreign exchange gains/losses
/// - Investment and asset sale gains/losses
///
/// **Taxes**: Income tax expense
///
/// # Usage
///
/// ```swift
/// // Create a revenue account
/// let salesAccount = try Account(
///     entity: myEntity,
///     name: "Product Sales",
///     timeSeries: salesData,
///     incomeStatementRole: .productRevenue
/// )
///
/// // Check if account is revenue
/// if salesAccount.incomeStatementRole?.isRevenue == true {
///     // Include in revenue calculations
/// }
/// ```
protocol StatementRole {
	var roleStatements: String { get }
	var description: String { get }
}

/// Categorizes line items on an income statement by their functional role.
///
/// Provides semantic classification of revenue, cost, and expense accounts
/// for income statement preparation and analysis. Each role identifies whether
/// an item represents revenue, cost of revenue, operating expenses, non-cash charges,
/// or non-operating items.
///
/// ## Example
/// ```swift
/// let salesRole = IncomeStatementRole.revenue
/// if salesRole.isRevenue {
///     // Include in revenue section
/// }
/// ```
public enum IncomeStatementRole: String, Sendable, Hashable, Codable, CaseIterable, StatementRole {
	var roleStatements: String { return "Income Statement"}
	
	var description: String {
		var type: String = ""
		if isRevenue { type += "Revenue" }
		if isCostOfRevenue { type += "CostOfRevenue"}
		if isOperatingExpense { type += "OperatingExpense"}
		if isNonCashCharge { type += "NonCashCharge"}
		if isNonOperating { type += "NonOperating"}
		type += ": \(self.rawValue)"
		return type
	}
	
    // ═══════════════════════════════════════════════════════════
    // REVENUE CATEGORIES
    // ═══════════════════════════════════════════════════════════

    /// Generic revenue (use when specific type doesn't apply)
    case revenue

    /// Revenue from product sales
    case productRevenue

    /// Revenue from service fees
    case serviceRevenue

    /// Recurring subscription revenue (e.g., SaaS)
    case subscriptionRevenue

    /// Revenue from licensing intellectual property
    case licensingRevenue

    /// Interest income from investments
    case interestIncome

    /// Other revenue sources not categorized above
    case otherRevenue

    // ═══════════════════════════════════════════════════════════
    // COST OF REVENUE
    // ═══════════════════════════════════════════════════════════

    /// Cost of Goods Sold - direct manufacturing/product costs
    case costOfGoodsSold

    /// Cost of Services - direct service delivery costs
    case costOfServices

    // ═══════════════════════════════════════════════════════════
    // OPERATING EXPENSES
    // ═══════════════════════════════════════════════════════════

    /// Research & Development expenses
    case researchAndDevelopment

    /// Sales & Marketing expenses
    case salesAndMarketing

    /// General & Administrative expenses
    case generalAndAdministrative

    /// Other operating expenses not categorized above
    case operatingExpenseOther

    // ═══════════════════════════════════════════════════════════
    // NON-CASH OPERATING CHARGES
    // ═══════════════════════════════════════════════════════════

    /// Depreciation & Amortization expense
    case depreciationAmortization

    /// Asset impairment charges
    case impairmentCharges

    /// Stock-based compensation expense
    case stockBasedCompensation

    /// One-time restructuring charges
    case restructuringCharges

    // ═══════════════════════════════════════════════════════════
    // NON-OPERATING ITEMS
    // ═══════════════════════════════════════════════════════════

    /// Interest expense on debt
    case interestExpense

    /// Foreign exchange gains/losses
    case foreignExchangeGainLoss

    /// Gains/losses on investment portfolio
    case gainLossOnInvestments

    /// Gains/losses on asset sales/disposals
    case gainLossOnAssetSales

    /// Other non-operating items not categorized above
    case otherNonOperating

    // ═══════════════════════════════════════════════════════════
    // TAXES
    // ═══════════════════════════════════════════════════════════

    /// Income tax expense
    case incomeTaxExpense

    // ═══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ═══════════════════════════════════════════════════════════

    /// Returns `true` if this role represents a revenue category
    ///
    /// Includes: revenue, productRevenue, serviceRevenue, subscriptionRevenue,
    /// licensingRevenue, and otherRevenue
    ///
    /// Note: `interestIncome` is classified as non-operating, not revenue
    public var isRevenue: Bool {
        [.revenue, .productRevenue, .serviceRevenue,
         .subscriptionRevenue, .licensingRevenue, .otherRevenue].contains(self)
    }

    /// Returns `true` if this role represents a cost of revenue
    ///
    /// Includes: costOfGoodsSold, costOfServices
    public var isCostOfRevenue: Bool {
        [.costOfGoodsSold, .costOfServices].contains(self)
    }

    /// Returns `true` if this role represents an operating expense
    ///
    /// Includes: researchAndDevelopment, salesAndMarketing,
    /// generalAndAdministrative, operatingExpenseOther
    public var isOperatingExpense: Bool {
        [.researchAndDevelopment, .salesAndMarketing,
         .generalAndAdministrative, .operatingExpenseOther].contains(self)
    }

    /// Returns `true` if this role represents a non-cash charge
    ///
    /// Non-cash charges reduce accounting income but don't affect operating cash flow.
    ///
    /// Includes: depreciationAmortization, impairmentCharges,
    /// stockBasedCompensation, restructuringCharges
    public var isNonCashCharge: Bool {
        [.depreciationAmortization, .impairmentCharges,
         .stockBasedCompensation, .restructuringCharges].contains(self)
    }

    /// Returns `true` if this role represents a non-operating item
    ///
    /// Non-operating items are outside the core business operations.
    ///
    /// Includes: interestExpense, interestIncome, foreignExchangeGainLoss,
    /// gainLossOnInvestments, gainLossOnAssetSales, otherNonOperating
    public var isNonOperating: Bool {
        [.interestExpense, .interestIncome, .foreignExchangeGainLoss,
         .gainLossOnInvestments, .gainLossOnAssetSales, .otherNonOperating].contains(self)
    }
}
