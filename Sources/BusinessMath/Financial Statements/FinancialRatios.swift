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

// MARK: - Helper Functions

/// Calculate average time series using beginning and ending values for each period.
///
/// For financial ratios that use average balance sheet values:
/// - First period: Uses beginning value (no prior period)
/// - Subsequent periods: (Beginning + Ending) / 2
///
/// This approach is standard in financial analysis to smooth period fluctuations.
///
/// - Parameter timeSeries: The time series to average
/// - Returns: Time series of averaged values
private func averageTimeSeries<T: Real>(_ timeSeries: TimeSeries<T>) -> TimeSeries<T> {
	let periods = timeSeries.periods
	guard !periods.isEmpty else {
		return timeSeries
	}

	var averagedValues: [Period: T] = [:]
	let two = T(2)

	for i in 0..<periods.count {
		let currentPeriod = periods[i]
		let currentValue = timeSeries[currentPeriod]!

		if i == 0 {
			// First period: no prior period, use current value
			averagedValues[currentPeriod] = currentValue
		} else {
			// Subsequent periods: average of prior and current
			let priorPeriod = periods[i - 1]
			let priorValue = timeSeries[priorPeriod]!
			averagedValues[currentPeriod] = (priorValue + currentValue) / two
		}
	}

	return TimeSeries(
		data: averagedValues,
		metadata: TimeSeriesMetadata(
			name: "Averaged \(timeSeries.metadata.name)",
			description: timeSeries.metadata.description,
			unit: timeSeries.metadata.unit
		)
	)
}
