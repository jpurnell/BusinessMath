import Foundation
import Numerics

// MARK: - DuPont Analysis

/// DuPont Analysis - ROE decomposition to understand drivers of profitability.
///
/// DuPont Analysis breaks down Return on Equity (ROE) into component ratios to identify
/// whether ROE is driven by profitability, efficiency, or leverage. This helps investors
/// and analysts understand the quality and sustainability of returns.

// MARK: - 3-Way DuPont Analysis

/// Result of 3-way DuPont Analysis decomposition.
///
/// The 3-way DuPont formula decomposes ROE into three components:
///
/// ```
/// ROE = Net Margin × Asset Turnover × Equity Multiplier
/// ```
///
/// ## Components
///
/// - **Net Margin** (Profitability): How much profit the company generates per dollar of sales
/// - **Asset Turnover** (Efficiency): How efficiently the company uses assets to generate sales
/// - **Equity Multiplier** (Leverage): How much the company relies on debt financing
///
/// ## Interpretation
///
/// - **High Net Margin**: Company has pricing power or cost advantages
/// - **High Asset Turnover**: Company efficiently uses assets (common in retail)
/// - **High Equity Multiplier**: Company uses leverage (higher risk, higher return potential)
///
/// ## Business Model Implications
///
/// - **Luxury goods**: High margin, low turnover, low leverage
/// - **Retail**: Low margin, high turnover, moderate leverage
/// - **Banks**: Moderate margin, low turnover, high leverage
///
/// ## Example
///
/// ```swift
/// let dupont = dupontAnalysis(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Net Margin: \(dupont.netMargin[q1]! * 100)%")
/// print("Asset Turnover: \(dupont.assetTurnover[q1]!)")
/// print("Equity Multiplier: \(dupont.equityMultiplier[q1]!)")
/// print("ROE: \(dupont.roe[q1]! * 100)%")
/// ```
public struct DuPontAnalysis<T: Real & Sendable>: Sendable where T: Codable {
	/// Net profit margin (Net Income / Revenue) - measures profitability
	public let netMargin: TimeSeries<T>

	/// Asset turnover (Revenue / Average Assets) - measures efficiency
	public let assetTurnover: TimeSeries<T>

	/// Equity multiplier (Average Assets / Average Equity) - measures leverage
	public let equityMultiplier: TimeSeries<T>

	/// Return on Equity (Net Income / Average Equity)
	/// Should equal netMargin × assetTurnover × equityMultiplier
	public let roe: TimeSeries<T>

	/// Creates a 3-way DuPont analysis result with all components.
	///
	/// - Parameters:
	///   - netMargin: Net profit margin (Net Income / Revenue)
	///   - assetTurnover: Asset turnover ratio (Revenue / Average Assets)
	///   - equityMultiplier: Equity multiplier (Average Assets / Average Equity)
	///   - roe: Return on equity (Net Income / Average Equity)
	public init(
		netMargin: TimeSeries<T>,
		assetTurnover: TimeSeries<T>,
		equityMultiplier: TimeSeries<T>,
		roe: TimeSeries<T>
	) {
		self.netMargin = netMargin
		self.assetTurnover = assetTurnover
		self.equityMultiplier = equityMultiplier
		self.roe = roe
	}
}

/// Performs 3-way DuPont Analysis to decompose ROE into profitability, efficiency, and leverage.
///
/// The DuPont formula shows that ROE can be improved by:
/// 1. Increasing profit margins (better pricing or cost control)
/// 2. Increasing asset turnover (more efficient use of assets)
/// 3. Increasing leverage (higher equity multiplier, but also higher risk)
///
/// ## Formula
///
/// ```
/// ROE = Net Margin × Asset Turnover × Equity Multiplier
///
/// Net Margin = Net Income / Revenue
/// Asset Turnover = Revenue / Average Assets
/// Equity Multiplier = Average Assets / Average Equity
/// ```
///
/// ## Use Cases
///
/// - **Compare companies**: Understand why one company has higher ROE
/// - **Track trends**: See which component drives ROE changes over time
/// - **Strategy**: Identify which lever to pull to improve ROE
///
/// ## Example
///
/// ```swift
/// let dupont = dupontAnalysis(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Company A: High ROE from margins (luxury brand)
/// // Company B: High ROE from turnover (discount retailer)
/// // Company C: High ROE from leverage (bank)
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - balanceSheet: The company's balance sheet
/// - Returns: DuPontAnalysis struct with all components
public func dupontAnalysis<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> DuPontAnalysis<T> {
	let netIncome = incomeStatement.netIncome
	let revenue = incomeStatement.totalRevenue
	let totalAssets = balanceSheet.totalAssets
	let totalEquity = balanceSheet.totalEquity

	// Calculate averages for balance sheet items
	let averageAssets = averageTimeSeries(totalAssets)
	let averageEquity = averageTimeSeries(totalEquity)

	// Component 1: Net Margin = Net Income / Revenue
	let netMargin = netIncome / revenue

	// Component 2: Asset Turnover = Revenue / Average Assets
	let assetTurnover = revenue / averageAssets

	// Component 3: Equity Multiplier = Average Assets / Average Equity
	let equityMultiplier = averageAssets / averageEquity

	// ROE = Net Income / Average Equity
	// Should also equal: Net Margin × Asset Turnover × Equity Multiplier
	let roe = netIncome / averageEquity

	return DuPontAnalysis(
		netMargin: netMargin,
		assetTurnover: assetTurnover,
		equityMultiplier: equityMultiplier,
		roe: roe
	)
}

// MARK: - 5-Way DuPont Analysis

/// Result of 5-way DuPont Analysis decomposition.
///
/// The 5-way DuPont formula provides a more detailed decomposition, separating
/// operating performance from financing decisions:
///
/// ```
/// ROE = Tax Burden × Interest Burden × Operating Margin × Asset Turnover × Equity Multiplier
/// ```
///
/// ## Components
///
/// - **Tax Burden**: Retention rate after taxes (Net Income / EBT)
/// - **Interest Burden**: Impact of interest expense (EBT / EBIT)
/// - **Operating Margin**: Operating profitability (EBIT / Revenue)
/// - **Asset Turnover**: Asset efficiency (Revenue / Assets)
/// - **Equity Multiplier**: Financial leverage (Assets / Equity)
///
/// ## Operating vs Financing
///
/// The 5-way analysis separates:
/// - **Operating performance**: Operating Margin × Asset Turnover
/// - **Financing impact**: Tax Burden × Interest Burden × Equity Multiplier
///
/// ## When to Use
///
/// Use 5-way analysis when:
/// - Comparing companies with different capital structures
/// - Analyzing impact of debt on returns
/// - Evaluating operating performance independent of financing
///
/// ## Example
///
/// ```swift
/// let dupont5 = dupontAnalysis5Way(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Operating ROA = Operating Margin × Asset Turnover
/// let operatingROA = dupont5.operatingMargin[q1]! * dupont5.assetTurnover[q1]!
///
/// // Impact of financing decisions
/// let financingMultiplier = dupont5.taxBurden[q1]! *
///                          dupont5.interestBurden[q1]! *
///                          dupont5.equityMultiplier[q1]!
/// ```
public struct DuPont5WayAnalysis<T: Real & Sendable>: Sendable where T: Codable {
	/// Tax burden (Net Income / EBT) - measures tax retention rate
	public let taxBurden: TimeSeries<T>

	/// Interest burden (EBT / EBIT) - measures impact of interest expense
	public let interestBurden: TimeSeries<T>

	/// Operating margin (EBIT / Revenue) - measures operating profitability
	public let operatingMargin: TimeSeries<T>

	/// Asset turnover (Revenue / Average Assets) - measures efficiency
	public let assetTurnover: TimeSeries<T>

	/// Equity multiplier (Average Assets / Average Equity) - measures leverage
	public let equityMultiplier: TimeSeries<T>

	/// Return on Equity (Net Income / Average Equity)
	/// Should equal product of all 5 components
	public let roe: TimeSeries<T>

	/// Creates a 5-way DuPont analysis result with all components.
	///
	/// - Parameters:
	///   - taxBurden: Tax retention rate (Net Income / EBT)
	///   - interestBurden: Interest burden (EBT / EBIT)
	///   - operatingMargin: Operating profit margin (EBIT / Revenue)
	///   - assetTurnover: Asset turnover ratio (Revenue / Average Assets)
	///   - equityMultiplier: Equity multiplier (Average Assets / Average Equity)
	///   - roe: Return on equity (Net Income / Average Equity)
	public init(
		taxBurden: TimeSeries<T>,
		interestBurden: TimeSeries<T>,
		operatingMargin: TimeSeries<T>,
		assetTurnover: TimeSeries<T>,
		equityMultiplier: TimeSeries<T>,
		roe: TimeSeries<T>
	) {
		self.taxBurden = taxBurden
		self.interestBurden = interestBurden
		self.operatingMargin = operatingMargin
		self.assetTurnover = assetTurnover
		self.equityMultiplier = equityMultiplier
		self.roe = roe
	}
}

/// Performs 5-way DuPont Analysis for detailed ROE decomposition.
///
/// The 5-way decomposition provides superior insights by separating:
/// - Operating performance (EBIT/Revenue, Revenue/Assets)
/// - Financing structure (interest, taxes, leverage)
///
/// ## Formula
///
/// ```
/// ROE = Tax Burden × Interest Burden × Operating Margin × Asset Turnover × Equity Multiplier
///
/// Tax Burden = Net Income / EBT
/// Interest Burden = EBT / EBIT
/// Operating Margin = EBIT / Revenue
/// Asset Turnover = Revenue / Average Assets
/// Equity Multiplier = Average Assets / Average Equity
/// ```
///
/// ## Interpretation
///
/// - **Tax Burden < 1**: Company pays taxes (typical)
/// - **Interest Burden < 1**: Company has interest expense
/// - **Interest Burden = 1**: Company has no debt
/// - **Operating Margin**: Pure operating profitability before financing
///
/// ## Example
///
/// ```swift
/// let dupont5 = dupontAnalysis5Way(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
///
/// // Company with debt will have Interest Burden < 1
/// // Company with high taxes will have Tax Burden < 1
/// // These factors reduce ROE relative to operating performance
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - balanceSheet: The company's balance sheet
/// - Returns: DuPont5WayAnalysis struct with all components
public func dupontAnalysis5Way<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>
) -> DuPont5WayAnalysis<T> {
	let netIncome = incomeStatement.netIncome
	let revenue = incomeStatement.totalRevenue
	let totalAssets = balanceSheet.totalAssets
	let totalEquity = balanceSheet.totalEquity

	// EBIT is the operating income (which already subtracts D&A)
	// Operating Income = Revenue - COGS - Operating Expenses - D&A
	let ebit = incomeStatement.operatingIncome

	// Calculate EBT (Earnings Before Tax) = Net Income + Tax
	let taxAccounts = incomeStatement.taxAccounts

	let taxExpense: TimeSeries<T>
	if !taxAccounts.isEmpty {
		taxExpense = taxAccounts.dropFirst().reduce(taxAccounts[0].timeSeries) { $0 + $1.timeSeries }
	} else {
		let zero = T(0)
		let periods = netIncome.periods
		let zeroValues = periods.map { _ in zero }
		taxExpense = TimeSeries(periods: periods, values: zeroValues)
	}

	let ebt = netIncome + taxExpense

	// Calculate averages for balance sheet items
	let averageAssets = averageTimeSeries(totalAssets)
	let averageEquity = averageTimeSeries(totalEquity)

	// Component 1: Tax Burden = Net Income / EBT
	let taxBurden = netIncome / ebt

	// Component 2: Interest Burden = EBT / EBIT
	let interestBurden = ebt / ebit

	// Component 3: Operating Margin = EBIT / Revenue
	let operatingMargin = ebit / revenue

	// Component 4: Asset Turnover = Revenue / Average Assets
	let assetTurnover = revenue / averageAssets

	// Component 5: Equity Multiplier = Average Assets / Average Equity
	let equityMultiplier = averageAssets / averageEquity

	// ROE = Net Income / Average Equity
	// Should also equal: Tax Burden × Interest Burden × Operating Margin × Asset Turnover × Equity Multiplier
	let roe = netIncome / averageEquity

	return DuPont5WayAnalysis(
		taxBurden: taxBurden,
		interestBurden: interestBurden,
		operatingMargin: operatingMargin,
		assetTurnover: assetTurnover,
		equityMultiplier: equityMultiplier,
		roe: roe
	)
}

// MARK: - Helper Functions

// Note: averageTimeSeries() is defined in TimeSeriesExtensions.swift
// and shared across all financial statement analysis modules.
