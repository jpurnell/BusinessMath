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
public func returnOnAssets<T: Real>(
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
public func returnOnEquity<T: Real>(
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
public func returnOnInvestedCapital<T: Real>(
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
public func assetTurnover<T: Real>(
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
public func inventoryTurnover<T: Real>(
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
		$0.assetType == .inventory
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
public func daysInventoryOutstanding<T: Real>(
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
public func receivablesTurnover<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) throws -> TimeSeries<T> {
	// Find accounts receivable in balance sheet
	guard let receivables = balanceSheet.assetAccounts.first(where: {
		$0.assetType == .accountsReceivable
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
public func daysSalesOutstanding<T: Real>(
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
public func interestCoverage<T: Real>(
	incomeStatement: IncomeStatement<T>
) throws -> TimeSeries<T> {
	// Find interest expense in income statement
	guard let interestExpense = incomeStatement.expenseAccounts.first(where: {
		$0.name.localizedCaseInsensitiveContains("Interest")
	}) else {
		throw FinancialRatioError.missingExpense("Interest Expense")
	}

	let operatingIncome = incomeStatement.operatingIncome
	let interestTimeSeries = interestExpense.timeSeries

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
public func debtServiceCoverage<T: Real>(
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
