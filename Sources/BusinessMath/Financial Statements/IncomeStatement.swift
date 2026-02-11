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

