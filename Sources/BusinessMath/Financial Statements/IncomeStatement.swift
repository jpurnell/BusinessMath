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
/// `IncomeStatement` aggregates revenue and expense accounts to compute financial
/// performance metrics including gross profit, operating income, net income, and
/// various margin ratios.
///
/// ## Creating Income Statements
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
/// let revenueAccount = try Account(
///     entity: entity,
///     name: "Product Sales",
///     type: .revenue,
///     timeSeries: revenueSeries
/// )
///
/// var cogsMetadata = AccountMetadata()
/// cogsMetadata.category = "COGS"
///
/// let cogsAccount = try Account(
///     entity: entity,
///     name: "Cost of Goods Sold",
///     type: .expense,
///     timeSeries: cogsSeries,
///     metadata: cogsMetadata
/// )
///
/// let incomeStmt = try IncomeStatement(
///     entity: entity,
///     periods: periods,
///     revenueAccounts: [revenueAccount],
///     expenseAccounts: [cogsAccount]
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
/// - ``init(entity:periods:revenueAccounts:expenseAccounts:)``
///
/// ### Properties
/// - ``entity``
/// - ``periods``
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

	/// All revenue accounts.
	public let revenueAccounts: [Account<T>]

	/// All expense accounts.
	public let expenseAccounts: [Account<T>]

	/// Creates an income statement with validation.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - revenueAccounts: Revenue accounts (must have type .revenue)
	///   - expenseAccounts: Expense accounts (must have type .expense)
	///
	/// - Throws: ``IncomeStatementError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		revenueAccounts: [Account<T>],
		expenseAccounts: [Account<T>]
	) throws {
		// Validate entity consistency
		for account in revenueAccounts + expenseAccounts {
			guard account.entity == entity else {
				throw IncomeStatementError.entityMismatch
			}
		}

		// Validate account types
		for account in revenueAccounts {
			guard account.type == .revenue else {
				throw IncomeStatementError.invalidAccountType(expected: .revenue, actual: account.type)
			}
		}

		for account in expenseAccounts {
			guard account.type == .expense else {
				throw IncomeStatementError.invalidAccountType(expected: .expense, actual: account.type)
			}
		}

		self.entity = entity
		self.periods = periods
		self.revenueAccounts = revenueAccounts
		self.expenseAccounts = expenseAccounts
	}

	// MARK: - Aggregated Totals

	/// Total revenue across all revenue accounts.
	public var totalRevenue: TimeSeries<T> {
		return aggregateAccounts(revenueAccounts)
	}

	/// Total expenses across all expense accounts.
	public var totalExpenses: TimeSeries<T> {
		return aggregateAccounts(expenseAccounts)
	}

	/// Net income (total revenue - total expenses).
	public var netIncome: TimeSeries<T> {
		return totalRevenue - totalExpenses
	}

	// MARK: - Profitability Metrics

	/// Gross profit (revenue - cost of goods sold).
	///
	/// COGS accounts are identified by `metadata.category == "COGS"`.
	public var grossProfit: TimeSeries<T> {
		let cogs = expenseAccounts.filter { $0.metadata?.category == "COGS" }
		let cogsTotal = aggregateAccounts(cogs)
		return totalRevenue - cogsTotal
	}

	/// Operating income (gross profit - operating expenses).
	///
	/// Operating expenses are identified by `metadata.category == "Operating"`.
	public var operatingIncome: TimeSeries<T> {
		let opex = expenseAccounts.filter { $0.metadata?.category == "Operating" }
		let opexTotal = aggregateAccounts(opex)
		return grossProfit - opexTotal
	}

	/// EBITDA (Earnings Before Interest, Taxes, Depreciation, and Amortization).
	///
	/// Adds back depreciation and amortization (identified by tag "D&A") to operating income.
	public var ebitda: TimeSeries<T> {
		let da = expenseAccounts.filter { $0.metadata?.tags.contains("D&A") ?? false }
		let daTotal = aggregateAccounts(da)
		return operatingIncome + daTotal
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

	// MARK: - Helper Methods

	/// Aggregates multiple accounts into a single time series.
	private func aggregateAccounts(_ accounts: [Account<T>]) -> TimeSeries<T> {
		guard !accounts.isEmpty else {
			// Return zero-filled series for empty account list
			let zeros = Array(repeating: T(0), count: periods.count)
			return TimeSeries(periods: periods, values: zeros)
		}

		// Start with first account's time series
		var result = accounts[0].timeSeries

		// Add remaining accounts
		for account in accounts.dropFirst() {
			result = result + account.timeSeries
		}

		return result
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
		public let entity: Entity
		public let periods: [Period]

		public let revenueAccounts: [Account<T>]
		public let expenseAccounts: [Account<T>]

		// Pre-computed totals
		public let totalRevenue: TimeSeries<T>
		public let totalExpenses: TimeSeries<T>
		public let netIncome: TimeSeries<T>

		// Pre-computed profitability metrics
		public let grossProfit: TimeSeries<T>
		public let operatingIncome: TimeSeries<T>
		public let ebitda: TimeSeries<T>

		// Pre-computed margins
		public let grossMargin: TimeSeries<T>
		public let operatingMargin: TimeSeries<T>
		public let netMargin: TimeSeries<T>
		public let ebitdaMargin: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` income statement with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			revenueAccounts: revenueAccounts,
			expenseAccounts: expenseAccounts,
			totalRevenue: totalRevenue,
			totalExpenses: totalExpenses,
			netIncome: netIncome,
			grossProfit: grossProfit,
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

extension IncomeStatement: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case revenueAccounts
		case expenseAccounts
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(revenueAccounts, forKey: .revenueAccounts)
		try container.encode(expenseAccounts, forKey: .expenseAccounts)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let revenueAccounts = try container.decode([Account<T>].self, forKey: .revenueAccounts)
		let expenseAccounts = try container.decode([Account<T>].self, forKey: .expenseAccounts)

		try self.init(
			entity: entity,
			periods: periods,
			revenueAccounts: revenueAccounts,
			expenseAccounts: expenseAccounts
		)
	}
}
