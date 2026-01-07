//
//  FinancialRatios.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Numerics

/// # Financial Ratios
///
/// Comprehensive financial ratios that operate across multiple financial statements
/// to provide insights into profitability, efficiency, and leverage.
///
/// ## Ratio Categories
///
/// - **Profitability**: ROA, ROE, ROIC - measure profit generation efficiency
/// - **Efficiency**: Asset turnover, inventory turnover - measure asset utilization
/// - **Leverage**: Interest coverage, debt service coverage - measure debt capacity
///
/// ## Usage
///
/// ```swift
/// let entity = Entity(name: "Acme Corp", ticker: "ACME")
/// let incomeStatement = try IncomeStatement(...)
/// let balanceSheet = try BalanceSheet(...)
///
/// // Calculate return on assets
/// let roa = returnOnAssets(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Analyze Q1 2025 profitability
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Q1 ROA: \(roa[q1]! * 100)%")
/// ```

// MARK: - Errors

/// Errors that can occur when calculating financial ratios.
public enum FinancialRatioError: Error, CustomStringConvertible {
	/// Required account not found in balance sheet.
	case missingAccount(String)

	/// Required expense not found in income statement.
	case missingExpense(String)

	public var description: String {
		switch self {
		case .missingAccount(let name):
			return "Required account '\(name)' not found in balance sheet"
		case .missingExpense(let name):
			return "Required expense '\(name)' not found in income statement"
		}
	}
}

// MARK: - Profitability Ratios

/// Return on Assets (ROA) - measures profit generated per dollar of assets.
///
/// ROA indicates how efficiently a company uses its assets to generate profit.
/// Higher ROA indicates better asset utilization.
///
/// ## Formula
///
/// ```
/// ROA = Net Income / Average Total Assets
/// ```
///
/// ## Average Calculation
///
/// - For first period: Uses beginning total assets (no prior period available)
/// - For subsequent periods: Average of beginning and ending total assets
///
/// ## Interpretation
///
/// - **> 5%**: Generally considered good (varies by industry)
/// - **> 10%**: Excellent asset utilization
/// - **< 0%**: Company is unprofitable
///
/// Capital-intensive industries (manufacturing, utilities) typically have lower ROA
/// than asset-light industries (software, consulting).
///
/// ## Example
///
/// ```swift
/// let roa = returnOnAssets(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("ROA: \(roa[q1]! * 100)%")  // e.g., "ROA: 12.5%"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing net income
///   - balanceSheet: Balance sheet containing total assets
/// - Returns: Time series of ROA ratios (as decimals, e.g., 0.10 = 10%)
public func returnOnAssets<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> TimeSeries<T> {
	let netIncome = incomeStatement.netIncome
	let totalAssets = balanceSheet.totalAssets

	// Calculate average assets for each period
	let averageAssets = averageTimeSeries(totalAssets)

	// ROA = Net Income / Average Assets
	return netIncome / averageAssets
}

/// Return on Equity (ROE) - measures profit generated per dollar of shareholder equity.
///
/// ROE indicates how efficiently a company uses shareholder investments to generate profit.
/// Higher ROE indicates better equity utilization. ROE is often higher than ROA when
/// a company uses debt (financial leverage).
///
/// ## Formula
///
/// ```
/// ROE = Net Income / Average Shareholders' Equity
/// ```
///
/// ## Interpretation
///
/// - **> 15%**: Generally considered good
/// - **> 20%**: Excellent equity returns
/// - **< 0%**: Company is unprofitable or has negative equity
///
/// ## Leverage Effect
///
/// Companies with debt will have higher ROE than ROA because:
/// - Equity is only a portion of total assets
/// - Debt amplifies returns (both positive and negative)
///
/// ## Example
///
/// ```swift
/// let roe = returnOnEquity(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("ROE: \(roe[q1]! * 100)%")  // e.g., "ROE: 18.5%"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing net income
///   - balanceSheet: Balance sheet containing shareholders' equity
/// - Returns: Time series of ROE ratios (as decimals, e.g., 0.15 = 15%)
public func returnOnEquity<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> TimeSeries<T> {
	let netIncome = incomeStatement.netIncome
	let totalEquity = balanceSheet.totalEquity

	// Calculate average equity for each period
	let averageEquity = averageTimeSeries(totalEquity)

	// ROE = Net Income / Average Equity
	return netIncome / averageEquity
}

/// Return on Invested Capital (ROIC) - measures return on all capital invested in the business.
///
/// ROIC measures how efficiently a company generates returns from all capital (both debt and equity).
/// It's a capital-structure-neutral metric that shows operating performance.
///
/// ## Formula
///
/// ```
/// ROIC = NOPAT / Invested Capital
///
/// Where:
/// NOPAT = Operating Income × (1 - Tax Rate)
/// Invested Capital = Total Assets - Current Liabilities
/// ```
///
/// ## Why NOPAT?
///
/// Net Operating Profit After Tax (NOPAT) excludes:
/// - Interest expense (to be capital-structure neutral)
/// - Non-operating items (to focus on core business)
///
/// ## Interpretation
///
/// - **> 10%**: Generally considered good
/// - **> 15%**: Excellent capital efficiency
/// - **> WACC**: Company creates value (ROIC > cost of capital)
/// - **< WACC**: Company destroys value
///
/// ## Comparison to Other Metrics
///
/// - **vs ROE**: ROIC is capital-structure neutral (not affected by debt levels)
/// - **vs ROA**: ROIC focuses on invested capital (excludes current liabilities)
///
/// ## Example
///
/// ```swift
/// let roic = returnOnInvestedCapital(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     taxRate: 0.21  // 21% corporate tax rate
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("ROIC: \(roic[q1]! * 100)%")  // e.g., "ROIC: 14.2%"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing operating income
///   - balanceSheet: Balance sheet containing assets and current liabilities
///   - taxRate: Corporate tax rate (as decimal, e.g., 0.21 for 21%)
/// - Returns: Time series of ROIC ratios (as decimals, e.g., 0.10 = 10%)
public func returnOnInvestedCapital<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	taxRate: T
) -> TimeSeries<T> {
	let operatingIncome = incomeStatement.operatingIncome
	let totalAssets = balanceSheet.totalAssets
	let currentLiabilities = balanceSheet.currentLiabilities

	// Calculate NOPAT = Operating Income × (1 - Tax Rate)
	let one = T(1)
	let nopat = operatingIncome.mapValues { $0 * (one - taxRate) }

	// Calculate Invested Capital = Total Assets - Current Liabilities
	let investedCapital = totalAssets - currentLiabilities

	// Calculate average invested capital for each period
	let averageInvestedCapital = averageTimeSeries(investedCapital)

	// ROIC = NOPAT / Average Invested Capital
	return nopat / averageInvestedCapital
}

// MARK: - Efficiency Ratios (Asset Turnover)

/// Asset Turnover - revenue generated per dollar of total assets.
///
/// Asset turnover measures how efficiently a company uses its assets to generate revenue.
/// Higher turnover indicates better asset utilization.
///
/// ## Formula
///
/// ```
/// Asset Turnover = Revenue / Average Total Assets
/// ```
///
/// ## Interpretation
///
/// - **> 1.0**: Company generates more than $1 of revenue per $1 of assets (efficient)
/// - **< 1.0**: Company generates less than $1 of revenue per $1 of assets
/// - **Industry variation**: Retail/services have higher turnover than capital-intensive industries
///
/// ## Industry Benchmarks
///
/// - **Retail**: 2.0 - 3.0 (fast-moving inventory, low asset base)
/// - **Manufacturing**: 0.5 - 1.5 (heavy equipment, slower turnover)
/// - **Software/Services**: 0.8 - 2.0 (low capital requirements)
///
/// ## Example
///
/// ```swift
/// let turnover = assetTurnover(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Asset Turnover: \(turnover[q1]!)x")  // e.g., "Asset Turnover: 1.5x"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue
///   - balanceSheet: Balance sheet containing total assets
/// - Returns: Time series of asset turnover ratios
public func assetTurnover<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> TimeSeries<T> {
	let revenue = incomeStatement.totalRevenue
	let totalAssets = balanceSheet.totalAssets

	// Calculate average assets for each period
	let averageAssets = averageTimeSeries(totalAssets)

	// Asset Turnover = Revenue / Average Assets
	return revenue / averageAssets
}

/// Inventory Turnover - how many times inventory is sold and replaced per period.
///
/// Inventory turnover measures how quickly a company sells through its inventory.
/// Higher turnover indicates faster inventory movement (generally better).
///
/// ## Formula
///
/// ```
/// Inventory Turnover = Cost of Goods Sold / Average Inventory
/// ```
///
/// ## Interpretation
///
/// - **> 6**: Fast-moving inventory (retail, perishables)
/// - **3-6**: Moderate turnover (manufacturing)
/// - **< 3**: Slow-moving inventory (luxury goods, heavy equipment)
///
/// ## Requirements
///
/// - Balance sheet must have an account with category "Current" containing "Inventory" in the name
/// - Income statement must have COGS (identified by name or category)
///
/// ## Example
///
/// ```swift
/// let turnover = try inventoryTurnover(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Inventory Turnover: \(turnover[q1]!)x")  // e.g., "Inventory Turnover: 8.0x"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing COGS
///   - balanceSheet: Balance sheet containing inventory account
/// - Returns: Time series of inventory turnover ratios
/// - Throws: ``FinancialRatioError/missingAccount(_:)`` if inventory account not found
/// - Throws: ``FinancialRatioError/missingExpense(_:)`` if COGS not found
public func inventoryTurnover<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	// Find COGS in income statement
	guard let cogs = incomeStatement.expenseAccounts.first(where: {
		$0.name.localizedCaseInsensitiveContains("Cost of Goods Sold") ||
		$0.name.localizedCaseInsensitiveContains("COGS")
	}) else {
		throw FinancialRatioError.missingExpense("Cost of Goods Sold (COGS)")
	}

	// Find inventory in balance sheet
	guard let inventory = balanceSheet.assetAccounts.first(where: {
		$0.balanceSheetRole == .inventory
	}) else {
		throw FinancialRatioError.missingAccount("Inventory")
	}

	let cogsTimeSeries = cogs.timeSeries
	let inventoryTimeSeries = inventory.timeSeries

	// Calculate average inventory for each period
	let averageInventory = averageTimeSeries(inventoryTimeSeries)

	// Inventory Turnover = COGS / Average Inventory
	return cogsTimeSeries / averageInventory
}

/// Days Inventory Outstanding (DIO) - average number of days inventory is held.
///
/// DIO measures how many days, on average, it takes to sell through inventory.
/// Lower DIO indicates faster inventory turnover (generally better for cash flow).
///
/// ## Formula
///
/// ```
/// DIO = 365 / Inventory Turnover
/// ```
///
/// Alternatively:
/// ```
/// DIO = (Average Inventory / COGS) × 365
/// ```
///
/// ## Interpretation
///
/// - **< 30 days**: Very fast turnover (fresh food, fast fashion)
/// - **30-60 days**: Fast turnover (general retail)
/// - **60-90 days**: Moderate turnover (manufacturing)
/// - **> 90 days**: Slow turnover (luxury goods, seasonal items)
///
/// ## Cash Conversion Cycle
///
/// DIO is part of the Cash Conversion Cycle:
/// ```
/// Cash Conversion Cycle = DIO + DSO - DPO
/// ```
/// Where DSO = Days Sales Outstanding, DPO = Days Payables Outstanding
///
/// ## Example
///
/// ```swift
/// let dio = try daysInventoryOutstanding(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("DIO: \(dio[q1]!) days")  // e.g., "DIO: 45.6 days"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing COGS
///   - balanceSheet: Balance sheet containing inventory account
/// - Returns: Time series of days inventory outstanding
/// - Throws: ``FinancialRatioError`` if required accounts not found
public func daysInventoryOutstanding<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	let turnover = try inventoryTurnover(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet
	)

	// DIO = 365 / Inventory Turnover
	let daysPerYear = T(365)
	return turnover.mapValues { daysPerYear / $0 }
}

/// Receivables Turnover - how quickly receivables are collected.
///
/// Receivables turnover measures how many times per period a company collects
/// its average accounts receivable balance. Higher turnover indicates faster collection.
///
/// ## Formula
///
/// ```
/// Receivables Turnover = Revenue / Average Accounts Receivable
/// ```
///
/// ## Interpretation
///
/// - **> 12**: Very fast collection (< 30 days)
/// - **6-12**: Fast collection (30-60 days)
/// - **4-6**: Moderate collection (60-90 days)
/// - **< 4**: Slow collection (> 90 days)
///
/// ## Requirements
///
/// - Balance sheet must have a current asset account containing "Receivable" in the name
///
/// ## Example
///
/// ```swift
/// let turnover = try receivablesTurnover(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Receivables Turnover: \(turnover[q1]!)x")  // e.g., "Receivables Turnover: 6.0x"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue
///   - balanceSheet: Balance sheet containing receivables account
/// - Returns: Time series of receivables turnover ratios
/// - Throws: ``FinancialRatioError/missingAccount(_:)`` if receivables account not found
public func receivablesTurnover<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	// Find accounts receivable in balance sheet
	guard let receivables = balanceSheet.assetAccounts.first(where: {
		$0.balanceSheetRole == .accountsReceivable
	}) else {
		throw FinancialRatioError.missingAccount("Accounts Receivable")
	}

	let revenue = incomeStatement.totalRevenue
	let receivablesTimeSeries = receivables.timeSeries

	// Calculate average receivables for each period
	let averageReceivables = averageTimeSeries(receivablesTimeSeries)

	// Receivables Turnover = Revenue / Average Receivables
	return revenue / averageReceivables
}

/// Days Sales Outstanding (DSO) - average number of days to collect receivables.
///
/// DSO measures how many days, on average, it takes to collect payment after a sale.
/// Lower DSO indicates faster collection (better for cash flow).
///
/// ## Formula
///
/// ```
/// DSO = 365 / Receivables Turnover
/// ```
///
/// Alternatively:
/// ```
/// DSO = (Average Receivables / Revenue) × 365
/// ```
///
/// ## Interpretation
///
/// - **< 30 days**: Excellent collection (cash businesses, net-30 terms)
/// - **30-45 days**: Good collection (net-30 to net-45 terms)
/// - **45-60 days**: Acceptable collection (net-60 terms)
/// - **> 60 days**: Slow collection (may indicate collection issues)
///
/// ## Credit Policy Impact
///
/// DSO directly reflects credit policy:
/// - Net-30 terms → DSO should be ~30-35 days
/// - Net-60 terms → DSO should be ~60-65 days
/// - Net-90 terms → DSO should be ~90-95 days
///
/// ## Example
///
/// ```swift
/// let dso = try daysSalesOutstanding(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("DSO: \(dso[q1]!) days")  // e.g., "DSO: 42.5 days"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue
///   - balanceSheet: Balance sheet containing receivables account
/// - Returns: Time series of days sales outstanding
/// - Throws: ``FinancialRatioError`` if required accounts not found
public func daysSalesOutstanding<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	let turnover = try receivablesTurnover(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet
	)

	// DSO = 365 / Receivables Turnover
	let daysPerYear = T(365)
	return turnover.mapValues { daysPerYear / $0 }
}

/// Days Payable Outstanding (DPO) - average number of days to pay suppliers.
///
/// DPO measures how many days, on average, a company takes to pay its suppliers.
/// Higher DPO means the company is taking longer to pay (keeping cash longer).
///
/// ## Formula
///
/// ```
/// DPO = (Average Accounts Payable / COGS) × 365
/// ```
///
/// ## Interpretation
///
/// - **> 90 days**: Slow payment (may strain supplier relationships)
/// - **60-90 days**: Moderate payment terms
/// - **30-60 days**: Fast payment (net-30 to net-60 terms)
/// - **< 30 days**: Very fast payment
///
/// ## Strategic Implications
///
/// - **Higher DPO**: Preserves cash, but may damage supplier relationships
/// - **Lower DPO**: Builds goodwill, may earn early payment discounts
/// - Compare to credit terms (net-30, net-60, etc.)
///
/// ## Cash Conversion Cycle
///
/// DPO reduces the cash conversion cycle:
/// ```
/// Cash Conversion Cycle = DIO + DSO - DPO
/// ```
///
/// ## Example
///
/// ```swift
/// let dpo = try daysPayableOutstanding(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("DPO: \(dpo[q1]!) days")  // e.g., "DPO: 45.2 days"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing COGS
///   - balanceSheet: Balance sheet containing accounts payable
/// - Returns: Time series of days payable outstanding
/// - Throws: ``FinancialRatioError`` if required accounts not found
public func daysPayableOutstanding<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	// Find COGS in income statement
	guard let cogs = incomeStatement.expenseAccounts.first(where: {
		$0.name.localizedCaseInsensitiveContains("Cost of Goods Sold") ||
		$0.name.localizedCaseInsensitiveContains("COGS")
	}) else {
		throw FinancialRatioError.missingExpense("Cost of Goods Sold (COGS)")
	}

	// Find accounts payable in balance sheet
	guard let payables = balanceSheet.liabilityAccounts.first(where: {
		$0.balanceSheetRole == .accountsPayable
	}) else {
		throw FinancialRatioError.missingAccount("Accounts Payable")
	}

	let cogsTimeSeries = cogs.timeSeries
	let payablesTimeSeries = payables.timeSeries

	// Calculate average payables for each period
	let averagePayables = averageTimeSeries(payablesTimeSeries)

	// DPO = (Average Payables / COGS) × 365
	let daysPerYear = T(365)
	return (averagePayables / cogsTimeSeries).mapValues { $0 * daysPerYear }
}

// MARK: - Leverage Ratios (Debt Coverage)

/// Interest Coverage Ratio - ability to pay interest expense from operating income.
///
/// Interest coverage measures how many times a company can pay its interest expense
/// from its operating income. Higher ratio indicates greater ability to service debt.
///
/// ## Formula
///
/// ```
/// Interest Coverage = Operating Income / Interest Expense
/// ```
///
/// Also known as "Times Interest Earned" (TIE).
///
/// ## Interpretation
///
/// - **> 3.0**: Healthy coverage (low risk of defaulting on interest)
/// - **2.0-3.0**: Acceptable coverage (some risk in downturns)
/// - **1.5-2.0**: Thin coverage (vulnerable to profit declines)
/// - **< 1.5**: At risk of not covering interest (financial distress)
/// - **< 1.0**: Operating income insufficient to pay interest
///
/// ## Requirements
///
/// Income statement must have an interest expense account (identified by name).
///
/// ## Example
///
/// ```swift
/// let coverage = try interestCoverage(incomeStatement: incomeStatement)
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Interest Coverage: \(coverage[q1]!)x")  // e.g., "Interest Coverage: 5.2x"
/// ```
///
/// - Parameter incomeStatement: Income statement containing operating income and interest expense
/// - Returns: Time series of interest coverage ratios
/// - Throws: ``FinancialRatioError/missingExpense(_:)`` if interest expense not found
public func interestCoverage<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>
) throws -> TimeSeries<T> {
	// Find interest expense in income statement
	guard let interestExpense = incomeStatement.expenseAccounts.first(where: {
		$0.name.localizedCaseInsensitiveContains("Interest")
	}) else {
		throw FinancialRatioError.missingExpense("Interest Expense")
	}

	let operatingIncome = incomeStatement.operatingIncome
	print("Operating Income:\t\(operatingIncome.valuesArray)")
	let interestTimeSeries = interestExpense.timeSeries
	print("Interest Time Series:\t\(interestTimeSeries.valuesArray)")

	// Interest Coverage = Operating Income / Interest Expense
	return operatingIncome / interestTimeSeries
}

/// Debt Service Coverage Ratio (DSCR) - ability to pay all debt obligations.
///
/// DSCR measures whether a company generates sufficient operating income to cover
/// all debt payments (both principal and interest). This is a more comprehensive
/// measure than interest coverage alone.
///
/// ## Formula
///
/// ```
/// DSCR = Operating Income / Total Debt Service
/// ```
///
/// Where:
/// ```
/// Total Debt Service = Principal Payments + Interest Payments
/// ```
///
/// ## Interpretation
///
/// - **> 1.5**: Strong coverage (preferred by lenders)
/// - **1.25-1.5**: Adequate coverage (acceptable for most loans)
/// - **1.0-1.25**: Tight coverage (lenders may require additional collateral)
/// - **< 1.0**: Insufficient income to service debt (default risk)
///
/// ## Lender Requirements
///
/// - **Commercial real estate**: Typically require DSCR > 1.25
/// - **Business loans**: Often require DSCR > 1.5
/// - **Project finance**: May require DSCR > 2.0
///
/// ## Example
///
/// ```swift
/// let dscr = try debtServiceCoverage(
///     incomeStatement: incomeStatement,
///     principalPayments: principalSeries,
///     interestPayments: interestSeries
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("DSCR: \(dscr[q1]!)x")  // e.g., "DSCR: 1.8x"
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing operating income
///   - principalPayments: Time series of principal payments on debt
///   - interestPayments: Time series of interest payments on debt
/// - Returns: Time series of debt service coverage ratios
public func debtServiceCoverage<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	principalPayments: TimeSeries<T>,
	interestPayments: TimeSeries<T>
) -> TimeSeries<T> {
	let operatingIncome = incomeStatement.operatingIncome

	// Total Debt Service = Principal + Interest
	let totalDebtService = principalPayments + interestPayments

	// DSCR = Operating Income / Total Debt Service
	return operatingIncome / totalDebtService
}

// MARK: - Helper Functions

// Note: averageTimeSeries() is defined in TimeSeriesExtensions.swift
// and shared across all financial statement analysis modules.

// MARK: - Convenience Structs for Ratio Analysis

/// Profitability ratios - measures profit generation efficiency.
///
/// Contains all key profitability metrics in a single structure for easy analysis.
///
/// ## Example
///
/// ```swift
/// let profitability = profitabilityRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Gross Margin: \(profitability.grossMargin[q1]! * 100)%")
/// print("ROE: \(profitability.roe[q1]! * 100)%")
/// ```
public struct ProfitabilityRatios<T: Real & Sendable>: Sendable where T: Codable {
	/// Gross profit as percentage of revenue
	public let grossMargin: TimeSeries<T>

	/// Operating income as percentage of revenue
	public let operatingMargin: TimeSeries<T>

	/// Net income as percentage of revenue
	public let netMargin: TimeSeries<T>

	/// EBITDA as percentage of revenue
	public let ebitdaMargin: TimeSeries<T>

	/// Return on Assets - Net Income / Average Assets
	public let roa: TimeSeries<T>

	/// Return on Equity - Net Income / Average Equity
	public let roe: TimeSeries<T>

	/// Return on Invested Capital - NOPAT / Average Invested Capital
	public let roic: TimeSeries<T>

	public init(
		grossMargin: TimeSeries<T>,
		operatingMargin: TimeSeries<T>,
		netMargin: TimeSeries<T>,
		ebitdaMargin: TimeSeries<T>,
		roa: TimeSeries<T>,
		roe: TimeSeries<T>,
		roic: TimeSeries<T>
	) {
		self.grossMargin = grossMargin
		self.operatingMargin = operatingMargin
		self.netMargin = netMargin
		self.ebitdaMargin = ebitdaMargin
		self.roa = roa
		self.roe = roe
		self.roic = roic
	}
}

/// Calculate all profitability ratios at once.
///
/// Convenience function that computes all key profitability metrics and returns them
/// in a single structure. Assumes a 21% tax rate for ROIC calculation.
///
/// ## Example
///
/// ```swift
/// let profitability = profitabilityRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// print("Gross Margin: \(profitability.grossMargin[q1]! * 100)%")
/// print("ROE: \(profitability.roe[q1]! * 100)%")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue and expenses
///   - balanceSheet: Balance sheet containing assets and equity
/// - Returns: Structure containing all profitability ratios
public func profitabilityRatios<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> ProfitabilityRatios<T> where T: ExpressibleByFloatLiteral {
	let taxRate: T = 0.21
	return ProfitabilityRatios(
		grossMargin: incomeStatement.grossMargin,
		operatingMargin: incomeStatement.operatingMargin,
		netMargin: incomeStatement.netMargin,
		ebitdaMargin: incomeStatement.ebitdaMargin,
		roa: returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet),
		roe: returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet),
		roic: returnOnInvestedCapital(incomeStatement: incomeStatement, balanceSheet: balanceSheet, taxRate: taxRate)
	)
}

/// Calculate all profitability ratios at once with custom tax rate.
///
/// Convenience function that computes all key profitability metrics and returns them
/// in a single structure with a custom tax rate for ROIC calculation.
///
/// ## Example
///
/// ```swift
/// let profitability = profitabilityRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     taxRate: 0.25
/// )
///
/// print("ROIC: \(profitability.roic[q1]! * 100)%")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue and expenses
///   - balanceSheet: Balance sheet containing assets and equity
///   - taxRate: Corporate tax rate for ROIC calculation
/// - Returns: Structure containing all profitability ratios
public func profitabilityRatios<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	taxRate: T
) -> ProfitabilityRatios<T> {
	return ProfitabilityRatios(
		grossMargin: incomeStatement.grossMargin,
		operatingMargin: incomeStatement.operatingMargin,
		netMargin: incomeStatement.netMargin,
		ebitdaMargin: incomeStatement.ebitdaMargin,
		roa: returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet),
		roe: returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet),
		roic: returnOnInvestedCapital(incomeStatement: incomeStatement, balanceSheet: balanceSheet, taxRate: taxRate)
	)
}

/// Efficiency ratios - measures asset utilization effectiveness.
///
/// Contains all key efficiency metrics including turnover ratios and cash conversion cycle.
///
/// ## Optional Properties
///
/// Some properties may be nil if the required accounts are not present:
/// - `inventoryTurnover`, `daysInventoryOutstanding`: Require inventory account (not all companies track inventory)
/// - `receivablesTurnover`, `daysSalesOutstanding`: Require accounts receivable (not all companies have credit sales)
/// - `daysPayableOutstanding`: Requires accounts payable (not all companies track payables)
/// - `cashConversionCycle`: Requires all three working capital metrics above
///
/// ## Example
///
/// ```swift
/// let efficiency = efficiencyRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Asset Turnover: \(efficiency.assetTurnover[q1]!)x")
/// if let ccc = efficiency.cashConversionCycle {
///     print("Cash Conversion Cycle: \(ccc[q1]!) days")
/// }
/// ```
public struct EfficiencyRatios<T: Real & Sendable>: Sendable where T: Codable {
	/// Revenue / Average Assets (always available)
	public let assetTurnover: TimeSeries<T>

	/// COGS / Average Inventory (nil if no inventory account)
	public let inventoryTurnover: TimeSeries<T>?

	/// Revenue / Average Receivables (nil if no receivables account)
	public let receivablesTurnover: TimeSeries<T>?

	/// Average days to collect receivables (nil if no receivables account)
	public let daysSalesOutstanding: TimeSeries<T>?

	/// Average days inventory is held (nil if no inventory account)
	public let daysInventoryOutstanding: TimeSeries<T>?

	/// Average days to pay suppliers (nil if no payables account)
	public let daysPayableOutstanding: TimeSeries<T>?

	/// Cash conversion cycle: DIO + DSO - DPO (nil if any component missing)
	public let cashConversionCycle: TimeSeries<T>?

	public init(
		assetTurnover: TimeSeries<T>,
		inventoryTurnover: TimeSeries<T>?,
		receivablesTurnover: TimeSeries<T>?,
		daysSalesOutstanding: TimeSeries<T>?,
		daysInventoryOutstanding: TimeSeries<T>?,
		daysPayableOutstanding: TimeSeries<T>?,
		cashConversionCycle: TimeSeries<T>?
	) {
		self.assetTurnover = assetTurnover
		self.inventoryTurnover = inventoryTurnover
		self.receivablesTurnover = receivablesTurnover
		self.daysSalesOutstanding = daysSalesOutstanding
		self.daysInventoryOutstanding = daysInventoryOutstanding
		self.daysPayableOutstanding = daysPayableOutstanding
		self.cashConversionCycle = cashConversionCycle
	}
}

/// Calculate all efficiency ratios at once.
///
/// Convenience function that computes all key efficiency metrics and returns them
/// in a single structure. Gracefully handles missing accounts by returning nil for
/// ratios that cannot be calculated.
///
/// ## Optional Ratios
///
/// Ratios are nil if required accounts are missing:
/// - Inventory-related metrics require inventory account
/// - Receivables-related metrics require accounts receivable
/// - Payables-related metrics require accounts payable
/// - Cash conversion cycle requires all three working capital components
///
/// ## Example
///
/// ```swift
/// let efficiency = efficiencyRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Asset turnover is always available
/// print("Asset Turnover: \(efficiency.assetTurnover[q1]!)x")
///
/// // Check for optional metrics
/// if let ccc = efficiency.cashConversionCycle {
///     print("CCC: \(ccc[q1]!) days")
/// } else {
///     print("CCC not available (missing working capital accounts)")
/// }
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue and optionally COGS
///   - balanceSheet: Balance sheet containing assets and optionally working capital accounts
/// - Returns: Structure containing all efficiency ratios (some may be nil)
public func efficiencyRatios<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> EfficiencyRatios<T> {
	let assetTurnoverRatio = assetTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
	let inventoryTurnoverRatio = try? inventoryTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
	let receivablesTurnoverRatio = try? receivablesTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
	let dso = try? daysSalesOutstanding(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
	let dio = try? daysInventoryOutstanding(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
	let dpo = try? daysPayableOutstanding(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

	// Cash Conversion Cycle = DIO + DSO - DPO (only if all three available)
	let ccc: TimeSeries<T>?
	if let dio = dio, let dso = dso, let dpo = dpo {
		ccc = dio + dso - dpo
	} else {
		ccc = nil
	}

	return EfficiencyRatios(
		assetTurnover: assetTurnoverRatio,
		inventoryTurnover: inventoryTurnoverRatio,
		receivablesTurnover: receivablesTurnoverRatio,
		daysSalesOutstanding: dso,
		daysInventoryOutstanding: dio,
		daysPayableOutstanding: dpo,
		cashConversionCycle: ccc
	)
}

/// Liquidity ratios - measures ability to meet short-term obligations.
///
/// Contains all key liquidity metrics for assessing near-term financial health.
///
/// ## Example
///
/// ```swift
/// let liquidity = liquidityRatios(balanceSheet: balanceSheet)
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Current Ratio: \(liquidity.currentRatio[q1]!)")
/// print("Quick Ratio: \(liquidity.quickRatio[q1]!)")
/// ```
public struct LiquidityRatios<T: Real & Sendable>: Sendable where T: Codable {
	/// Current Assets / Current Liabilities
	public let currentRatio: TimeSeries<T>

	/// (Current Assets - Inventory) / Current Liabilities
	public let quickRatio: TimeSeries<T>

	/// Cash / Current Liabilities
	public let cashRatio: TimeSeries<T>

	/// Current Assets - Current Liabilities
	public let workingCapital: TimeSeries<T>

	public init(
		currentRatio: TimeSeries<T>,
		quickRatio: TimeSeries<T>,
		cashRatio: TimeSeries<T>,
		workingCapital: TimeSeries<T>
	) {
		self.currentRatio = currentRatio
		self.quickRatio = quickRatio
		self.cashRatio = cashRatio
		self.workingCapital = workingCapital
	}
}

/// Calculate all liquidity ratios at once.
///
/// Convenience function that computes all key liquidity metrics and returns them
/// in a single structure.
///
/// ## Example
///
/// ```swift
/// let liquidity = liquidityRatios(balanceSheet: balanceSheet)
///
/// print("Current Ratio: \(liquidity.currentRatio[q1]!)")
/// print("Working Capital: $\(liquidity.workingCapital[q1]!)")
/// ```
///
/// - Parameter balanceSheet: Balance sheet containing assets and liabilities
/// - Returns: Structure containing all liquidity ratios
public func liquidityRatios<T: Real & Sendable>(
	balanceSheet: BalanceSheet<T>
) -> LiquidityRatios<T> {
	return LiquidityRatios(
		currentRatio: balanceSheet.currentRatio,
		quickRatio: balanceSheet.quickRatio,
		cashRatio: balanceSheet.cashRatio,
		workingCapital: balanceSheet.workingCapital
	)
}

/// Solvency ratios - measures ability to meet long-term obligations.
///
/// Contains all key solvency metrics for assessing long-term financial health and leverage.
///
/// ## Optional Properties
///
/// Some properties may be nil if the required accounts are not present:
/// - `interestCoverage`: Requires interest expense (not all companies have debt)
/// - `debtServiceCoverage`: Optional, requires principal and interest payment data
///
/// ## Example
///
/// ```swift
/// let solvency = solvencyRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Debt-to-Equity: \(solvency.debtToEquity[q1]!)")
/// if let coverage = solvency.interestCoverage {
///     print("Interest Coverage: \(coverage[q1]!)x")
/// }
/// ```
public struct SolvencyRatios<T: Real & Sendable>: Sendable where T: Codable {
	/// Total Liabilities / Total Equity (always available)
	public let debtToEquity: TimeSeries<T>

	/// Total Liabilities / Total Assets (always available)
	public let debtToAssets: TimeSeries<T>

	/// Total Equity / Total Assets (always available)
	public let equityRatio: TimeSeries<T>

	/// Operating Income / Interest Expense (nil if no interest expense)
	public let interestCoverage: TimeSeries<T>?

	/// Operating Income / (Principal + Interest) (nil if payment data not provided)
	public let debtServiceCoverage: TimeSeries<T>?

	public init(
		debtToEquity: TimeSeries<T>,
		debtToAssets: TimeSeries<T>,
		equityRatio: TimeSeries<T>,
		interestCoverage: TimeSeries<T>? = nil,
		debtServiceCoverage: TimeSeries<T>? = nil
	) {
		self.debtToEquity = debtToEquity
		self.debtToAssets = debtToAssets
		self.equityRatio = equityRatio
		self.interestCoverage = interestCoverage
		self.debtServiceCoverage = debtServiceCoverage
	}
}

/// Calculate all solvency ratios at once.
///
/// Convenience function that computes all key solvency metrics and returns them
/// in a single structure. Gracefully handles missing accounts by returning nil for
/// ratios that cannot be calculated.
///
/// ## Optional Ratios
///
/// Ratios are nil if required accounts are missing:
/// - `interestCoverage`: Requires interest expense account (not all companies have debt)
/// - `debtServiceCoverage`: Requires principal and interest payment data (optional parameter)
///
/// ## Example
///
/// ```swift
/// let solvency = solvencyRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Leverage ratios are always available
/// print("Debt-to-Equity: \(solvency.debtToEquity[q1]!)")
///
/// // Interest coverage may be nil for debt-free companies
/// if let coverage = solvency.interestCoverage {
///     print("Interest Coverage: \(coverage[q1]!)x")
/// } else {
///     print("No interest expense (debt-free company)")
/// }
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing operating income and optionally interest
///   - balanceSheet: Balance sheet containing assets, liabilities, and equity
///   - principalPayments: Optional time series of principal payments
///   - interestPayments: Optional time series of interest payments
/// - Returns: Structure containing all solvency ratios (some may be nil)
public func solvencyRatios<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	principalPayments: TimeSeries<T>? = nil,
	interestPayments: TimeSeries<T>? = nil
) -> SolvencyRatios<T> {
	let interestCoverageRatio = try? interestCoverage(incomeStatement: incomeStatement)

	// Calculate debt service coverage if payment data provided
	let dscr: TimeSeries<T>?
	if let principal = principalPayments, let interest = interestPayments {
		dscr = debtServiceCoverage(
			incomeStatement: incomeStatement,
			principalPayments: principal,
			interestPayments: interest
		)
	} else {
		dscr = nil
	}

	return SolvencyRatios(
		debtToEquity: balanceSheet.debtToEquity,
		debtToAssets: balanceSheet.debtRatio,
		equityRatio: balanceSheet.equityRatio,
		interestCoverage: interestCoverageRatio,
		debtServiceCoverage: dscr
	)
}

/// Calculate solvency ratios with automatic principal payment derivation.
///
/// Convenience overload that automatically calculates principal payments from
/// period-over-period reductions in the debt account balance. This eliminates
/// the need to manually compute principal payments when you have a debt account
/// on the balance sheet.
///
/// Principal payments are calculated as the reduction in debt balance from one
/// period to the next:
///
/// ```
/// Principal Payment(t) = Debt Balance(t-1) - Debt Balance(t)
/// ```
///
/// For increasing debt balances (new borrowing), principal payments will be
/// negative, which is appropriate for the debt service coverage calculation.
///
/// ## When to Use This Overload
///
/// Use this convenience method when:
/// - You have a debt account with period-over-period balance changes
/// - Debt balance decreases represent principal repayments
/// - You want automatic calculation instead of manual specification
///
/// Use the explicit `principalPayments` parameter when:
/// - Principal payments don't match balance sheet changes (e.g., refinancing)
/// - You need to exclude certain debt transactions
/// - You have off-balance-sheet debt obligations
///
/// ## Example
///
/// ```swift
/// // Find the long-term debt account
/// let debtAccount = balanceSheet.liabilityAccounts.first {
///     $0.name.contains("Long-term Debt")
/// }!
///
/// // Interest expense from income statement
/// let interestAccount = incomeStatement.expenseAccounts.first {
///     $0.name.contains("Interest")
/// }!
///
/// // Automatically derives principal payments from debt reduction
/// let solvency = solvencyRatios(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     debtAccount: debtAccount,
///     interestAccount: interestAccount
/// )
///
/// // Debt service coverage is now available
/// print("DSCR: \(solvency.debtServiceCoverage![q1]!)x")
/// ```
///
/// ## See Also
///
/// - ``solvencyRatios(incomeStatement:balanceSheet:principalPayments:interestPayments:)``
/// - ``debtServiceCoverage(incomeStatement:principalPayments:interestPayments:)``
///
/// - Parameters:
///   - incomeStatement: Income statement containing operating income
///   - balanceSheet: Balance sheet containing the debt account
///   - debtAccount: Debt liability account to derive principal payments from
///   - interestAccount: Interest expense account from income statement
/// - Returns: Structure containing all solvency ratios including debt service coverage
public func solvencyRatios<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	debtAccount: Account<T>,
	interestAccount: Account<T>
) -> SolvencyRatios<T> {
	// Derive principal payments from period-over-period debt reduction
	// debt.diff() returns currentBalance - previousBalance
	// For declining debt, this is negative, so we negate to get positive principal payments
	let debtChanges = debtAccount.timeSeries.diff(lag: 1)
	let principalPayments = debtChanges.mapValues { -$0 }  // Negate: reduction = payment
	// Interest payments from income statement
	let interestPayments = interestAccount.timeSeries
	// Delegate to the main implementation
	return solvencyRatios(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		principalPayments: principalPayments,
		interestPayments: interestPayments
	)
}

/// Valuation metrics - market-based valuation ratios.
///
/// Contains all key market valuation metrics for assessing whether a stock is
/// over or undervalued relative to fundamentals.
///
/// ## Example
///
/// ```swift
/// let valuation = valuationMetrics(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     sharesOutstanding: 1_000_000,
///     marketPrice: 50.0
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/E Ratio: \(valuation.priceToEarnings[q1]!)")
/// print("EV/EBITDA: \(valuation.evToEbitda[q1]!)")
/// ```
public struct ValuationMetrics<T: Real & Sendable>: Sendable where T: Codable {
	/// Market capitalization (shares × price)
	public let marketCap: TimeSeries<T>

	/// Price-to-Earnings ratio
	public let priceToEarnings: TimeSeries<T>

	/// Price-to-Book ratio
	public let priceToBook: TimeSeries<T>

	/// Price-to-Sales ratio
	public let priceToSales: TimeSeries<T>

	/// Enterprise Value (Market Cap + Debt - Cash)
	public let enterpriseValue: TimeSeries<T>

	/// EV / EBITDA ratio
	public let evToEbitda: TimeSeries<T>

	/// EV / Sales ratio
	public let evToSales: TimeSeries<T>

	public init(
		marketCap: TimeSeries<T>,
		priceToEarnings: TimeSeries<T>,
		priceToBook: TimeSeries<T>,
		priceToSales: TimeSeries<T>,
		enterpriseValue: TimeSeries<T>,
		evToEbitda: TimeSeries<T>,
		evToSales: TimeSeries<T>
	) {
		self.marketCap = marketCap
		self.priceToEarnings = priceToEarnings
		self.priceToBook = priceToBook
		self.priceToSales = priceToSales
		self.enterpriseValue = enterpriseValue
		self.evToEbitda = evToEbitda
		self.evToSales = evToSales
	}
}

/// Calculate all valuation metrics at once.
///
/// Convenience function that computes all key market valuation metrics and returns them
/// in a single structure. Requires market data (shares outstanding and price per share).
///
/// ## Example
///
/// ```swift
/// let valuation = valuationMetrics(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     sharesOutstanding: 1_000_000,
///     marketPrice: 50.0
/// )
///
/// print("P/E: \(valuation.priceToEarnings[q1]!)")
/// print("EV/EBITDA: \(valuation.evToEbitda[q1]!)")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing earnings and revenue
///   - balanceSheet: Balance sheet containing assets, debt, and equity
///   - sharesOutstanding: Number of shares outstanding (can vary by period)
///   - marketPrice: Market price per share (can vary by period)
/// - Returns: Structure containing all valuation metrics
public func valuationMetrics<T: Real & Sendable>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	sharesOutstanding: T,
	marketPrice: T
) -> ValuationMetrics<T> {
	let netIncome = incomeStatement.netIncome
	let revenue = incomeStatement.totalRevenue
	let ebitda = incomeStatement.ebitda
	let equity = balanceSheet.totalEquity
	let debt = balanceSheet.interestBearingDebt

	// Get cash from balance sheet using the cashAndEquivalents property
	// (which already handles the case of no cash accounts by returning zeros)
	let cash = balanceSheet.cashAndEquivalents

	// Market Cap = Shares Outstanding × Price
	let marketCap = netIncome.mapValues { _ in sharesOutstanding * marketPrice }

	// P/E = Market Cap / Net Income
	let pe = marketCap / netIncome

	// P/B = Market Cap / Equity
	let pb = marketCap / equity

	// P/S = Market Cap / Revenue
	let ps = marketCap / revenue

	// EV = Market Cap + Debt - Cash
	let ev = marketCap + debt - cash

	// EV/EBITDA
	let evToEbitda = ev / ebitda

	// EV/Sales
	let evToSales = ev / revenue

	return ValuationMetrics(
		marketCap: marketCap,
		priceToEarnings: pe,
		priceToBook: pb,
		priceToSales: ps,
		enterpriseValue: ev,
		evToEbitda: evToEbitda,
		evToSales: evToSales
	)
}
