//
//  IncomeStatement.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - IncomeStatementError

/// Errors that can occur when creating or manipulating income statements.
public enum IncomeStatementError: Error, Sendable {
	/// The entity is missing from one or more accounts
	case entityMismatch

	/// Periods are inconsistent across accounts
	case periodMismatch

	/// No accounts provided
	case noAccounts

	/// Wrong account type (expected revenue or expense)
	case invalidAccountType(expected: AccountType, actual: AccountType)
}

// MARK: - IncomeStatement

/// Income statement (Profit & Loss) for a single entity over multiple periods.
///
/// `IncomeStatement` aggregates accounts with income statement roles to compute financial
/// performance metrics including gross profit, operating income, net income, and
/// various margin ratios.
///
/// ## Creating Income Statements (New Role-Based API)
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let periods = [
///     Period.quarter(year: 2024, quarter: 1),
///     Period.quarter(year: 2024, quarter: 2),
///     Period.quarter(year: 2024, quarter: 3),
///     Period.quarter(year: 2024, quarter: 4)
/// ]
///
/// let productRevenue = try Account(
///     entity: entity,
///     name: "Product Sales",
///     incomeStatementRole: .productRevenue,
///     timeSeries: productSeries
/// )
///
/// let serviceRevenue = try Account(
///     entity: entity,
///     name: "Service Revenue",
///     incomeStatementRole: .serviceRevenue,
///     timeSeries: serviceSeries
/// )
///
/// let cogs = try Account(
///     entity: entity,
///     name: "Cost of Goods Sold",
///     incomeStatementRole: .costOfGoodsSold,
///     timeSeries: cogsSeries
/// )
///
/// let incomeStmt = try IncomeStatement(
///     entity: entity,
///     periods: periods,
///     accounts: [productRevenue, serviceRevenue, cogs]  // Single array!
/// )
/// ```
///
/// ## Accessing Metrics
///
/// ```swift
/// // Aggregated totals
/// let totalRevenue = incomeStmt.totalRevenue
/// let totalExpenses = incomeStmt.totalExpenses
/// let netIncome = incomeStmt.netIncome
///
/// // Profitability metrics
/// let grossProfit = incomeStmt.grossProfit
/// let operatingIncome = incomeStmt.operatingIncome
///
/// // Margin ratios
/// let grossMargin = incomeStmt.grossMargin
/// let operatingMargin = incomeStmt.operatingMargin
/// let netMargin = incomeStmt.netMargin
/// ```
///
/// ## Role-Based Filtering
///
/// Multiple accounts with the same role automatically aggregate:
///
/// ```swift
/// // Two product revenue accounts from different regions
/// let usRevenue = try Account(entity: entity, name: "US Revenue",
///                              incomeStatementRole: .productRevenue, timeSeries: usSeries)
/// let euRevenue = try Account(entity: entity, name: "EU Revenue",
///                              incomeStatementRole: .productRevenue, timeSeries: euSeries)
///
/// let incomeStmt = try IncomeStatement(entity: entity, periods: periods,
///                                       accounts: [usRevenue, euRevenue])
///
/// // Automatically aggregates both accounts
/// let totalProduct = incomeStmt.totalRevenue  // US + EU
/// ```
///
/// ## Materialization for Performance
///
/// For repeated metric access across many companies, use materialization:
///
/// ```swift
/// let materialized = incomeStmt.materialize()
///
/// // All metrics pre-computed
/// let avgGrossMargin = materialized.grossMargin.valuesArray.mean()
/// let avgNetMargin = materialized.netMargin.valuesArray.mean()
/// ```
///
/// ## Topics
///
/// ### Creating Income Statements
/// - ``init(entity:periods:accounts:)``
///
/// ### Properties
/// - ``entity``
/// - ``periods``
/// - ``accounts``
/// - ``revenueAccounts``
/// - ``expenseAccounts``
///
/// ### Aggregated Totals
/// - ``totalRevenue``
/// - ``totalExpenses``
/// - ``netIncome``
///
/// ### Profitability Metrics
/// - ``grossProfit``
/// - ``operatingIncome``
/// - ``ebitda``
///
/// ### Margin Ratios
/// - ``grossMargin``
/// - ``operatingMargin``
/// - ``netMargin``
/// - ``ebitdaMargin``
///
/// ### Materialization
/// - ``materialize()``
/// - ``Materialized``
public struct IncomeStatement<T: Real & Sendable>: Sendable where T: Codable {

	/// The entity this income statement belongs to.
	public let entity: Entity

	/// The periods covered by this income statement.
	public let periods: [Period]

	/// All accounts in this income statement.
	///
	/// Each account must have an `incomeStatementRole` to be included.
	/// Accounts with the same role will be automatically aggregated when computing metrics.
	public let accounts: [Account<T>]

	/// All revenue accounts (accounts with revenue roles).
	///
	/// This computed property filters accounts by their `incomeStatementRole.isRevenue` flag.
	public var revenueAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole?.isRevenue == true }
	}

	/// All expense accounts (accounts with expense roles).
	///
	/// This computed property filters accounts by checking if they're not revenue.
	public var expenseAccounts: [Account<T>] {
		accounts.filter {
			guard let role = $0.incomeStatementRole else { return false }
			return !role.isRevenue
		}
	}

	/// All cost of revenue accounts (COGS, cost of services, etc.).
	public var costOfRevenueAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole?.isCostOfRevenue == true }
	}

	/// All operating expense accounts (R&D, S&M, G&A).
	public var operatingExpenseAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole?.isOperatingExpense == true }
	}

	/// All non-cash charge accounts (D&A, stock-based comp, impairments).
	public var nonCashChargeAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole?.isNonCashCharge == true }
	}

	/// All interest expense accounts.
	public var interestExpenseAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole == .interestExpense }
	}

	/// All tax accounts.
	public var taxAccounts: [Account<T>] {
		accounts.filter { $0.incomeStatementRole == .incomeTaxExpense }
	}

	/// Creates an income statement with validation using the new role-based API.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - accounts: All accounts (must have `incomeStatementRole`)
	///
	/// - Throws: ``FinancialModelError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		accounts: [Account<T>]
	) throws {
		// Validate all accounts have income statement roles
		for account in accounts {
			guard account.incomeStatementRole != nil else {
				throw FinancialModelError.accountMissingRole(
					statement: .incomeStatement,
					accountName: account.name
				)
			}
		}

		// Validate entity and period consistency using shared helpers
		try FinancialStatementHelpers.validateEntityConsistency(accounts: accounts, entity: entity)
		try FinancialStatementHelpers.validatePeriodConsistency(accounts: accounts, periods: periods)

		self.entity = entity
		self.periods = periods
		self.accounts = accounts
	}

	// MARK: - Aggregated Totals

	/// Total revenue across all revenue accounts.
	///
	/// Aggregates all accounts where `incomeStatementRole.isRevenue == true`.
	public var totalRevenue: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(revenueAccounts, periods: periods)
	}

	/// Total expenses across all expense accounts.
	///
	/// Aggregates all accounts where `incomeStatementRole.isRevenue == false`.
	public var totalExpenses: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(expenseAccounts, periods: periods)
	}

	/// Net income (total revenue - total expenses).
	public var netIncome: TimeSeries<T> {
		return totalRevenue - totalExpenses
	}

	// MARK: - Profitability Metrics

	/// Gross profit (revenue - cost of revenue).
	///
	/// Cost of revenue includes accounts where `incomeStatementRole.isCostOfRevenue == true`,
	/// such as COGS, cost of services, fulfillment costs, etc.
	///
	/// For service companies with no cost of revenue accounts, returns total revenue (100% gross margin).
	public var grossProfit: TimeSeries<T> {
		let costOfRevenue = FinancialStatementHelpers.aggregateAccounts(costOfRevenueAccounts, periods: periods)
		return totalRevenue - costOfRevenue
	}

	/// Operating expenses (R&D + S&M + G&A).
	///
	/// Aggregates all accounts where `incomeStatementRole.isOperatingExpense == true`.
	public var operatingExpenses: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(operatingExpenseAccounts, periods: periods)
	}

	/// Operating income (gross profit - operating expenses - non-cash charges).
	///
	/// Operating income (EBIT) includes all operating costs, including depreciation and amortization.
	/// This represents earnings from operations before interest and taxes.
	public var operatingIncome: TimeSeries<T> {
		let nonCashCharges = FinancialStatementHelpers.aggregateAccounts(nonCashChargeAccounts, periods: periods)
		return grossProfit - operatingExpenses - nonCashCharges
	}

	/// EBITDA (Earnings Before Interest, Taxes, Depreciation, and Amortization).
	///
	/// Adds back non-cash charges (D&A, stock-based comp, impairments) to operating income.
	public var ebitda: TimeSeries<T> {
		let nonCashCharges = FinancialStatementHelpers.aggregateAccounts(nonCashChargeAccounts, periods: periods)
		return operatingIncome + nonCashCharges
	}

	// MARK: - Margin Ratios

	/// Gross margin (gross profit / revenue).
	public var grossMargin: TimeSeries<T> {
		return grossProfit / totalRevenue
	}

	/// Operating margin (operating income / revenue).
	public var operatingMargin: TimeSeries<T> {
		return operatingIncome / totalRevenue
	}

	/// Net margin (net income / revenue).
	public var netMargin: TimeSeries<T> {
		return netIncome / totalRevenue
	}

	/// EBITDA margin (EBITDA / revenue).
	public var ebitdaMargin: TimeSeries<T> {
		return ebitda / totalRevenue
	}

	// MARK: - Contribution Margin Analysis (v2.0.0)

	/// All expense accounts classified as variable costs.
	///
	/// Returns accounts where `metadata.isVariableCost == true`. Variable costs scale
	/// with business volume (e.g., raw materials, direct labor, commissions).
	///
	/// ## Business Context
	///
	/// Variable costs are essential for contribution margin analysis and breakeven calculations.
	/// They change proportionally with production or sales volume.
	///
	/// ## Example Usage
	///
	/// ```swift
	/// // Filter variable cost accounts
	/// let variableAccounts = incomeStmt.variableCostAccounts
	///
	/// // Example variable costs: COGS, commissions, shipping
	/// for account in variableAccounts {
	///     print("\(account.name): \(account.metadata?.isVariableCost == true)")
	/// }
	/// ```
	///
	/// - Returns: Array of accounts with variable cost classification
	/// - SeeAlso: ``AccountMetadata/isVariableCost``
	public var variableCostAccounts: [Account<T>] {
		expenseAccounts.filter { $0.metadata?.isVariableCost == true }
	}

	/// All expense accounts classified as fixed costs.
	///
	/// Returns accounts where `metadata.isFixedCost == true`. Fixed costs remain constant
	/// regardless of business volume (e.g., rent, salaries, insurance).
	///
	/// ## Business Context
	///
	/// Fixed costs are used in contribution margin analysis to calculate operating leverage
	/// and breakeven points. They do not change with production or sales volume.
	///
	/// ## Example Usage
	///
	/// ```swift
	/// // Filter fixed cost accounts
	/// let fixedAccounts = incomeStmt.fixedCostAccounts
	///
	/// // Example fixed costs: Rent, salaries, insurance
	/// for account in fixedAccounts {
	///     print("\(account.name): \(account.metadata?.isFixedCost == true)")
	/// }
	/// ```
	///
	/// - Returns: Array of accounts with fixed cost classification
	/// - SeeAlso: ``AccountMetadata/isFixedCost``
	public var fixedCostAccounts: [Account<T>] {
		expenseAccounts.filter { $0.metadata?.isFixedCost == true }
	}

	/// Total variable costs across all expense accounts.
	///
	/// Aggregates all expenses where `metadata.isVariableCost == true`. Variable costs
	/// scale with business volume and are subtracted from revenue to calculate
	/// contribution margin.
	///
	/// ## Business Context
	///
	/// Total variable costs represent expenses that change proportionally with sales volume.
	/// Understanding variable costs is critical for:
	/// - Contribution margin analysis
	/// - Breakeven calculations
	/// - Pricing decisions
	/// - Operating leverage assessment
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let incomeStmt = try IncomeStatement(entity: company, periods: periods, accounts: accounts)
	///
	/// // Get total variable costs per period
	/// let variableCosts = incomeStmt.totalVariableCosts
	///
	/// // If no accounts have cost classification, returns zero
	/// print("Q1 Variable Costs: \(variableCosts.values[0])")
	/// ```
	///
	/// ## Graceful Handling
	///
	/// If no accounts have `isVariableCost = true`, this property returns a time series
	/// of zeros. The income statement remains functional without cost classification.
	///
	/// - Returns: Time series of total variable costs (absolute values, already negative for expenses)
	/// - SeeAlso: ``contributionMargin``, ``totalFixedCosts``
	public var totalVariableCosts: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(variableCostAccounts, periods: periods)
	}

	/// Total fixed costs across all expense accounts.
	///
	/// Aggregates all expenses where `metadata.isFixedCost == true`. Fixed costs remain
	/// constant regardless of business volume and are subtracted from contribution margin
	/// to calculate operating income.
	///
	/// ## Business Context
	///
	/// Total fixed costs represent expenses that do not vary with sales volume. Understanding
	/// fixed costs is essential for:
	/// - Operating leverage analysis
	/// - Breakeven point calculations
	/// - Cost structure decisions
	/// - Profitability forecasting
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let incomeStmt = try IncomeStatement(entity: company, periods: periods, accounts: accounts)
	///
	/// // Get total fixed costs per period
	/// let fixedCosts = incomeStmt.totalFixedCosts
	///
	/// // If no accounts have cost classification, returns zero
	/// print("Q1 Fixed Costs: \(fixedCosts.values[0])")
	/// ```
	///
	/// ## Graceful Handling
	///
	/// If no accounts have `isFixedCost = true`, this property returns a time series
	/// of zeros. The income statement remains functional without cost classification.
	///
	/// - Returns: Time series of total fixed costs (absolute values, already negative for expenses)
	/// - SeeAlso: ``contributionMargin``, ``totalVariableCosts``
	public var totalFixedCosts: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(fixedCostAccounts, periods: periods)
	}

	/// Contribution margin (revenue - variable costs).
	///
	/// Represents the amount available to cover fixed costs and generate profit after
	/// variable costs are subtracted from revenue. This is a key metric for understanding
	/// operational leverage and breakeven analysis.
	///
	/// ## Business Context
	///
	/// Contribution margin shows how much each dollar of sales contributes to covering fixed
	/// costs and profit. A higher contribution margin means:
	/// - Greater ability to absorb fixed costs
	/// - More profit per unit sold
	/// - Higher operating leverage
	///
	/// ## Formula
	///
	/// ```
	/// Contribution Margin = Total Revenue - Total Variable Costs
	/// ```
	///
	/// ## Example Usage
	///
	/// ```swift
	/// // Revenue: $1,000,000
	/// // Variable Costs: $600,000 (60% of revenue)
	/// // Contribution Margin: $400,000 (40% of revenue)
	///
	/// let cm = incomeStmt.contributionMargin
	/// let cmPercent = incomeStmt.contributionMarginPercent
	///
	/// print("Contribution Margin: \(cm.values[0])")        // $400,000
	/// print("Contribution Margin %: \(cmPercent.values[0])")  // 0.40 (40%)
	/// ```
	///
	/// ## Graceful Handling
	///
	/// If no accounts have variable cost classification, contribution margin equals total revenue
	/// (assuming all costs are fixed). The calculation remains valid even without cost classification.
	///
	/// - Returns: Time series of contribution margin
	/// - SeeAlso: ``contributionMarginPercent``, ``totalVariableCosts``, ``operatingLeverage()``
	public var contributionMargin: TimeSeries<T> {
		return totalRevenue - totalVariableCosts
	}

	/// Contribution margin percentage (contribution margin / revenue).
	///
	/// Expresses contribution margin as a percentage of revenue, showing what portion of
	/// each sales dollar remains after variable costs to cover fixed costs and profit.
	///
	/// ## Business Context
	///
	/// Contribution margin percentage is critical for:
	/// - Pricing decisions (minimum acceptable margin)
	/// - Product mix optimization
	/// - Breakeven analysis
	/// - Comparing profitability across products/services
	///
	/// ## Formula
	///
	/// ```
	/// Contribution Margin % = (Revenue - Variable Costs) / Revenue
	/// ```
	///
	/// ## Example Usage
	///
	/// ```swift
	/// // Product A: 70% contribution margin
	/// // Product B: 40% contribution margin
	/// // → Product A contributes more per dollar of sales
	///
	/// let cmPercent = incomeStmt.contributionMarginPercent
	///
	/// for (i, period) in incomeStmt.periods.enumerated() {
	///     print("\(period): \(cmPercent.values[i] * 100)%")
	/// }
	/// ```
	///
	/// ## Interpretation
	///
	/// - **High %** (>50%): Strong pricing power, high margins, scalable business model
	/// - **Medium %** (30-50%): Typical for many businesses, moderate leverage
	/// - **Low %** (<30%): Thin margins, high sensitivity to volume changes
	///
	/// - Returns: Time series of contribution margin as a decimal (0.40 = 40%)
	/// - SeeAlso: ``contributionMargin``, ``grossMargin``
	public var contributionMarginPercent: TimeSeries<T> {
		return contributionMargin / totalRevenue
	}

	/// Operating leverage (contribution margin / operating income).
	///
	/// Measures how sensitive operating income is to changes in revenue. High operating leverage
	/// means a small change in sales produces a large change in operating income (both up and down).
	///
	/// ## Business Context
	///
	/// Operating leverage quantifies the degree to which a business uses fixed costs in its
	/// cost structure. It's essential for:
	/// - Risk assessment (volatility of profits)
	/// - Growth strategy decisions
	/// - Understanding profit sensitivity to revenue changes
	/// - Comparing business models
	///
	/// ## Formula
	///
	/// ```
	/// Operating Leverage = Contribution Margin / Operating Income
	/// ```
	///
	/// ## Example Usage
	///
	/// ```swift
	/// // Company with high fixed costs:
	/// // Contribution Margin: $500,000
	/// // Operating Income: $100,000
	/// // Operating Leverage: 5.0×
	/// // → A 10% increase in revenue yields ~50% increase in operating income
	///
	/// let leverage = incomeStmt.operatingLeverage()
	///
	/// for (i, period) in incomeStmt.periods.enumerated() {
	///     print("\(period): \(leverage.values[i])×")
	/// }
	/// ```
	///
	/// ## Interpretation
	///
	/// - **Leverage > 1**: Each 1% change in revenue changes operating income by leverage%
	/// - **High leverage (>3)**: High fixed costs, high profit volatility, high growth potential
	/// - **Low leverage (<2)**: Low fixed costs, stable profits, lower growth amplification
	///
	/// ## Graceful Handling
	///
	/// Returns infinity (or very large values) when operating income approaches zero.
	/// Returns NaN when both contribution margin and operating income are zero.
	///
	/// - Returns: Time series of operating leverage as a multiplier
	/// - SeeAlso: ``contributionMargin``, ``operatingIncome``
	public func operatingLeverage() -> TimeSeries<T> {
		return contributionMargin / operatingIncome
	}

}

// MARK: - Materialized Income Statement

extension IncomeStatement {

	/// Materialized version of an income statement with pre-computed metrics.
	///
	/// Use `Materialized` when computing metrics repeatedly across many companies.
	/// All metrics are computed once and stored, trading memory for speed.
	///
	/// ## Example
	/// ```swift
	/// let materialized = incomeStmt.materialize()
	///
	/// // Metrics are pre-computed, not recalculated on each access
	/// for period in materialized.periods {
	///     print("Period: \(period)")
	///     print("  Gross Margin: \(materialized.grossMargin[period] ?? 0)")
	///     print("  Operating Margin: \(materialized.operatingMargin[period] ?? 0)")
	///     print("  Net Margin: \(materialized.netMargin[period] ?? 0)")
	/// }
	/// ```
	public struct Materialized: Sendable {
		/// The entity this income statement belongs to.
		public let entity: Entity

		/// The time periods covered by this statement.
		public let periods: [Period]

		/// All accounts in the income statement (revenue and expenses).
		public let accounts: [Account<T>]

		// Pre-computed totals

		/// Total revenue across all periods (sum of all revenue accounts).
		public let totalRevenue: TimeSeries<T>

		/// Total expenses across all periods (sum of all expense accounts).
		public let totalExpenses: TimeSeries<T>

		/// Net income: totalRevenue - totalExpenses.
		public let netIncome: TimeSeries<T>

		// Pre-computed profitability metrics

		/// Gross profit: Revenue - Cost of Goods Sold.
		public let grossProfit: TimeSeries<T>

		/// Operating expenses: SG&A and other operating costs.
		public let operatingExpenses: TimeSeries<T>

		/// Operating income (EBIT): Gross Profit - Operating Expenses.
		public let operatingIncome: TimeSeries<T>

		/// EBITDA: Operating Income + Depreciation + Amortization.
		public let ebitda: TimeSeries<T>

		// Pre-computed margins

		/// Gross margin: Gross Profit / Total Revenue.
		public let grossMargin: TimeSeries<T>

		/// Operating margin: Operating Income / Total Revenue.
		public let operatingMargin: TimeSeries<T>

		/// Net margin: Net Income / Total Revenue.
		public let netMargin: TimeSeries<T>

		/// EBITDA margin: EBITDA / Total Revenue.
		public let ebitdaMargin: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` income statement with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			accounts: accounts,
			totalRevenue: totalRevenue,
			totalExpenses: totalExpenses,
			netIncome: netIncome,
			grossProfit: grossProfit,
			operatingExpenses: operatingExpenses,
			operatingIncome: operatingIncome,
			ebitda: ebitda,
			grossMargin: grossMargin,
			operatingMargin: operatingMargin,
			netMargin: netMargin,
			ebitdaMargin: ebitdaMargin
		)
	}
}

// MARK: - Codable Conformance

/// Codable conformance for IncomeStatement enables JSON serialization.
///
/// Only encodes the essential data (entity, periods, accounts). Computed properties
/// like totals and margins are recalculated upon decoding.
///
/// ## Example
/// ```swift
/// let statement = IncomeStatement(...)
/// let json = try JSONEncoder().encode(statement)
/// let decoded = try JSONDecoder().decode(IncomeStatement<Double>.self, from: json)
/// ```
extension IncomeStatement: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case accounts
	}

	/// Encode the income statement to an encoder.
	///
	/// Only encodes entity, periods, and accounts. Computed metrics are not encoded.
	///
	/// - Parameter encoder: The encoder to write to
	/// - Throws: EncodingError if encoding fails
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(accounts, forKey: .accounts)
	}

	/// Decode an income statement from a decoder.
	///
	/// Reconstructs the income statement from entity, periods, and accounts.
	/// All computed metrics (totals, margins) are automatically recalculated.
	///
	/// - Parameter decoder: The decoder to read from
	/// - Throws: DecodingError if decoding fails, or validation errors from init
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let accounts = try container.decode([Account<T>].self, forKey: .accounts)

		try self.init(
			entity: entity,
			periods: periods,
			accounts: accounts
		)
	}
}

