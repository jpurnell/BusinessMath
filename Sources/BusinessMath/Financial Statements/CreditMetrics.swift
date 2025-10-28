//
//  CreditMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Numerics

/// # Credit Metrics & Composite Scores
///
/// Composite financial health scores that combine multiple ratios to assess
/// bankruptcy risk and fundamental strength.
///
/// ## Scoring Systems
///
/// - **Altman Z-Score**: Bankruptcy prediction model (manufacturing companies)
/// - **Piotroski F-Score**: 9-point fundamental strength assessment
///
/// ## Usage
///
/// ```swift
/// let entity = Entity(name: "Acme Corp", ticker: "ACME")
/// let incomeStatement = try IncomeStatement(...)
/// let balanceSheet = try BalanceSheet(...)
/// let cashFlowStatement = try CashFlowStatement(...)
///
/// // Calculate Altman Z-Score
/// let marketPrice = TimeSeries(...) // Stock prices
/// let sharesOutstanding = TimeSeries(...) // Share count
///
/// let zScore = altmanZScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let currentPeriod = Period.quarter(year: 2025, quarter: 1)
/// if zScore[currentPeriod]! > 2.99 {
///     print("Safe zone: Low bankruptcy risk")
/// }
///
/// // Calculate Piotroski F-Score
/// let priorPeriod = Period.quarter(year: 2024, quarter: 4)
/// let score = piotroskiScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStatement,
///     period: currentPeriod,
///     priorPeriod: priorPeriod
/// )
///
/// print("F-Score: \(score.totalScore)/9")
/// print("Profitability: \(score.profitability)/4")
/// ```

// MARK: - Piotroski F-Score Types

/// Piotroski F-Score result containing total score and breakdown by category.
///
/// The F-Score is a 9-point scale (0-9) that assesses fundamental strength across
/// three dimensions: profitability, leverage/liquidity, and operating efficiency.
///
/// ## Score Interpretation
///
/// - **8-9 points**: Very strong fundamentals
/// - **7 points**: Strong fundamentals
/// - **5-6 points**: Average fundamentals
/// - **3-4 points**: Weak fundamentals
/// - **0-2 points**: Very weak fundamentals
///
/// ## Components
///
/// - **Profitability** (0-4 points): Earnings quality and improvement
/// - **Leverage** (0-3 points): Balance sheet strength and liquidity
/// - **Efficiency** (0-2 points): Operational effectiveness
///
/// ## Example
///
/// ```swift
/// let score = piotroskiScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStatement,
///     period: currentPeriod,
///     priorPeriod: priorPeriod
/// )
///
/// if score.totalScore >= 7 {
///     print("Strong company")
///     if score.signals["positiveOperatingCashFlow"]! {
///         print("✓ Positive operating cash flow")
///     }
/// }
/// ```
public struct PiotroskiScore {
	/// Total F-Score (0-9 points).
	public let totalScore: Int

	/// Profitability signals (0-4 points).
	public let profitability: Int

	/// Leverage/liquidity signals (0-3 points).
	public let leverage: Int

	/// Operating efficiency signals (0-2 points).
	public let efficiency: Int

	/// Individual signal results (true = 1 point, false = 0 points).
	///
	/// ## Profitability Signals
	/// - `positiveNetIncome`: Net income > 0
	/// - `positiveOperatingCashFlow`: Operating cash flow > 0
	/// - `increasingROA`: ROA improved vs prior period
	/// - `qualityEarnings`: Operating cash flow > Net income
	///
	/// ## Leverage Signals
	/// - `decreasingDebt`: Long-term debt decreased vs prior period
	/// - `increasingCurrentRatio`: Current ratio improved vs prior period
	/// - `noNewEquity`: No new shares issued
	///
	/// ## Efficiency Signals
	/// - `increasingGrossMargin`: Gross margin improved vs prior period
	/// - `increasingAssetTurnover`: Asset turnover improved vs prior period
	public let signals: [String: Bool]
}

// MARK: - Altman Z-Score

/// Altman Z-Score - bankruptcy prediction model for manufacturing companies.
///
/// The Z-Score combines five financial ratios weighted by regression coefficients
/// to predict the probability of bankruptcy within two years. Originally developed
/// for publicly-traded manufacturers.
///
/// ## Formula
///
/// ```
/// Z = 1.2×A + 1.4×B + 3.3×C + 0.6×D + 1.0×E
///
/// Where:
/// A = Working Capital / Total Assets
/// B = Retained Earnings / Total Assets
/// C = EBIT / Total Assets
/// D = Market Value of Equity / Total Liabilities
/// E = Sales / Total Assets
/// ```
///
/// ## Interpretation
///
/// - **Z > 2.99**: Safe Zone (Low bankruptcy risk)
/// - **1.81 < Z < 2.99**: Grey Zone (Moderate risk, requires analysis)
/// - **Z < 1.81**: Distress Zone (High bankruptcy risk within 2 years)
///
/// ## Component Meanings
///
/// - **A (Working Capital/Assets)**: Liquidity relative to size
/// - **B (Retained Earnings/Assets)**: Cumulative profitability and age
/// - **C (EBIT/Assets)**: Operating efficiency (ROA before taxes/interest)
/// - **D (Market Equity/Liabilities)**: Solvency (how much assets can decline before insolvency)
/// - **E (Sales/Assets)**: Asset turnover (revenue generation efficiency)
///
/// ## Limitations
///
/// - Designed for manufacturing companies (asset-heavy businesses)
/// - Less accurate for service, financial, or tech companies
/// - Market cap component makes it sensitive to stock market volatility
/// - Z-Score > 10 often indicates calculation errors or data issues
///
/// ## Variants
///
/// - **Z-Score**: Original (public manufacturers)
/// - **Z'-Score**: Private companies (uses book equity instead of market)
/// - **Z''-Score**: Non-manufacturers and emerging markets
///
/// ## Example
///
/// ```swift
/// let zScore = altmanZScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let currentPeriod = Period.quarter(year: 2025, quarter: 1)
/// let z = zScore[currentPeriod]!
///
/// switch z {
/// case ..<1.81:
///     print("⚠️ Distress Zone (Z = \(z)): High bankruptcy risk")
/// case 1.81..<2.99:
///     print("⚡ Grey Zone (Z = \(z)): Moderate risk")
/// default:
///     print("✓ Safe Zone (Z = \(z)): Low bankruptcy risk")
/// }
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing EBIT and sales
///   - balanceSheet: Balance sheet with working capital, retained earnings, assets, liabilities
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Number of shares outstanding (for market cap calculation)
/// - Returns: Time series of Z-Scores
public func altmanZScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	// Component A: Working Capital / Total Assets
	let workingCapital = balanceSheet.currentAssets - balanceSheet.currentLiabilities
	let totalAssets = balanceSheet.totalAssets
	let a = workingCapital / totalAssets

	// Component B: Retained Earnings / Total Assets
	let retainedEarnings = balanceSheet.retainedEarnings
	let b = retainedEarnings / totalAssets

	// Component C: EBIT / Total Assets
	let ebit = incomeStatement.operatingIncome
	let c = ebit / totalAssets

	// Component D: Market Value of Equity / Total Liabilities
	let marketValue = marketPrice * sharesOutstanding
	let totalLiabilities = balanceSheet.totalLiabilities
	let d = marketValue / totalLiabilities

	// Component E: Sales / Total Assets
	let sales = incomeStatement.totalRevenue
	let e = sales / totalAssets

	// Z-Score = 1.2×A + 1.4×B + 3.3×C + 0.6×D + 1.0×E
	// Create constant TimeSeries for coefficients
	let periods = totalAssets.periods
	let coeffA = TimeSeries(periods: periods, values: Array(repeating: T(12) / T(10), count: periods.count))  // 1.2
	let coeffB = TimeSeries(periods: periods, values: Array(repeating: T(14) / T(10), count: periods.count))  // 1.4
	let coeffC = TimeSeries(periods: periods, values: Array(repeating: T(33) / T(10), count: periods.count))  // 3.3
	let coeffD = TimeSeries(periods: periods, values: Array(repeating: T(6) / T(10), count: periods.count))   // 0.6

	// Break up expression to avoid compiler timeout
	let term1 = a * coeffA  // 1.2×A
	let term2 = b * coeffB  // 1.4×B
	let term3 = c * coeffC  // 3.3×C
	let term4 = d * coeffD  // 0.6×D
	let term5 = e           // 1.0×E = E

	return term1 + term2 + term3 + term4 + term5
}

// MARK: - Piotroski F-Score

/// Piotroski F-Score - 9-point fundamental strength assessment.
///
/// The F-Score aggregates 9 binary signals (0 or 1) across profitability, leverage,
/// and operating efficiency. It's designed to identify strong companies with improving
/// fundamentals, particularly useful for value investing.
///
/// ## Scoring Components
///
/// ### Profitability (4 points max)
/// 1. **Positive Net Income** (1 point): Net income > 0
/// 2. **Positive Operating Cash Flow** (1 point): Operating cash flow > 0
/// 3. **Increasing ROA** (1 point): ROA improved vs prior period
/// 4. **Quality of Earnings** (1 point): Operating cash flow > Net income
///
/// ### Leverage/Liquidity (3 points max)
/// 5. **Decreasing Leverage** (1 point): Long-term debt decreased vs prior period
/// 6. **Increasing Liquidity** (1 point): Current ratio improved vs prior period
/// 7. **No New Equity** (1 point): Shares outstanding did not increase
///
/// ### Operating Efficiency (2 points max)
/// 8. **Increasing Margin** (1 point): Gross margin improved vs prior period
/// 9. **Increasing Turnover** (1 point): Asset turnover improved vs prior period
///
/// ## Interpretation
///
/// - **F ≥ 7**: Strong fundamentals (buy signal for value investors)
/// - **4 ≤ F < 7**: Average fundamentals
/// - **F < 4**: Weak fundamentals (potential sell signal)
///
/// ## Use Cases
///
/// - **Value investing**: Identifying strong companies in distressed sectors
/// - **Fundamental screening**: Filtering stocks by financial health
/// - **Trend analysis**: Tracking fundamental improvement/deterioration
/// - **Bankruptcy prediction**: Very low scores (0-2) indicate distress
///
/// ## Example
///
/// ```swift
/// let currentPeriod = Period.quarter(year: 2025, quarter: 1)
/// let priorPeriod = Period.quarter(year: 2024, quarter: 4)
///
/// let score = piotroskiScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStatement,
///     period: currentPeriod,
///     priorPeriod: priorPeriod
/// )
///
/// print("F-Score: \(score.totalScore)/9")
/// print("  Profitability: \(score.profitability)/4")
/// print("  Leverage: \(score.leverage)/3")
/// print("  Efficiency: \(score.efficiency)/2")
///
/// // Check individual signals
/// if score.signals["qualityEarnings"]! {
///     print("✓ High-quality earnings (OCF > NI)")
/// }
/// if !score.signals["noNewEquity"]! {
///     print("⚠️ Dilution: New shares issued")
/// }
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement for current and prior periods
///   - balanceSheet: Balance sheet for current and prior periods
///   - cashFlowStatement: Cash flow statement for current and prior periods
///   - period: Current period to evaluate
///   - priorPeriod: Prior period for year-over-year comparisons
/// - Returns: PiotroskiScore with total score, component scores, and individual signals
public func piotroskiScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	cashFlowStatement: CashFlowStatement<T>,
	period: Period,
	priorPeriod: Period
) -> PiotroskiScore {
	var signals: [String: Bool] = [:]

	// MARK: Profitability Signals (4 points max)

	// 1. Positive net income
	let netIncome = incomeStatement.netIncome[period]!
	signals["positiveNetIncome"] = netIncome > T(0)

	// 2. Positive operating cash flow
	let operatingCashFlow = cashFlowStatement.operatingCashFlow[period]!
	signals["positiveOperatingCashFlow"] = operatingCashFlow > T(0)

	// 3. Increasing ROA
	let totalAssetsCurrent = balanceSheet.totalAssets[period]!
	let totalAssetsPrior = balanceSheet.totalAssets[priorPeriod]!
	let roaCurrent = netIncome / totalAssetsCurrent
	let netIncomePrior = incomeStatement.netIncome[priorPeriod]!
	let roaPrior = netIncomePrior / totalAssetsPrior
	signals["increasingROA"] = roaCurrent > roaPrior

	// 4. Quality of earnings (operating cash flow > net income)
	signals["qualityEarnings"] = operatingCashFlow > netIncome

	// MARK: Leverage/Liquidity Signals (3 points max)

	// 5. Decreasing long-term debt
	let ltDebt = balanceSheet.longTermDebt
	let ltDebtCurrent = ltDebt[period] ?? T(0)
	let ltDebtPrior = ltDebt[priorPeriod] ?? T(0)
	// If no debt in either period, count as positive (no increase)
	signals["decreasingDebt"] = ltDebtCurrent <= ltDebtPrior

	// 6. Increasing current ratio
	let currentAssetsCurrent = balanceSheet.currentAssets[period]!
	let currentLiabilitiesCurrent = balanceSheet.currentLiabilities[period]!
	let currentRatioCurrent = currentAssetsCurrent / currentLiabilitiesCurrent

	let currentAssetsPrior = balanceSheet.currentAssets[priorPeriod]!
	let currentLiabilitiesPrior = balanceSheet.currentLiabilities[priorPeriod]!
	let currentRatioPrior = currentAssetsPrior / currentLiabilitiesPrior

	signals["increasingCurrentRatio"] = currentRatioCurrent > currentRatioPrior

	// 7. No new equity issuance
	let totalEquityCurrent = balanceSheet.totalEquity[period]!
	let totalEquityPrior = balanceSheet.totalEquity[priorPeriod]!

	// Check if common stock increased (proxy for new issuance)
	// More sophisticated: check if equity increased beyond retained earnings
	let retainedEarningsCurrent = balanceSheet.retainedEarnings[period]!
	let retainedEarningsPrior = balanceSheet.retainedEarnings[priorPeriod]!
	let retainedEarningsChange = retainedEarningsCurrent - retainedEarningsPrior
	let equityChange = totalEquityCurrent - totalEquityPrior

	// If equity increase exceeds retained earnings increase, new shares were issued
	signals["noNewEquity"] = equityChange <= retainedEarningsChange

	// MARK: Operating Efficiency Signals (2 points max)

	// 8. Increasing gross margin
	let grossProfitCurrent = incomeStatement.grossProfit[period]!
	let revenueCurrent = incomeStatement.totalRevenue[period]!
	let grossMarginCurrent = grossProfitCurrent / revenueCurrent

	let grossProfitPrior = incomeStatement.grossProfit[priorPeriod]!
	let revenuePrior = incomeStatement.totalRevenue[priorPeriod]!
	let grossMarginPrior = grossProfitPrior / revenuePrior

	signals["increasingGrossMargin"] = grossMarginCurrent > grossMarginPrior

	// 9. Increasing asset turnover
	let assetTurnoverCurrent = revenueCurrent / totalAssetsCurrent
	let assetTurnoverPrior = revenuePrior / totalAssetsPrior
	signals["increasingAssetTurnover"] = assetTurnoverCurrent > assetTurnoverPrior

	// MARK: Calculate Scores

	let profitabilitySignals = [
		"positiveNetIncome",
		"positiveOperatingCashFlow",
		"increasingROA",
		"qualityEarnings"
	]
	let profitability = profitabilitySignals.filter { signals[$0]! }.count

	let leverageSignals = [
		"decreasingDebt",
		"increasingCurrentRatio",
		"noNewEquity"
	]
	let leverage = leverageSignals.filter { signals[$0]! }.count

	let efficiencySignals = [
		"increasingGrossMargin",
		"increasingAssetTurnover"
	]
	let efficiency = efficiencySignals.filter { signals[$0]! }.count

	let totalScore = profitability + leverage + efficiency

	return PiotroskiScore(
		totalScore: totalScore,
		profitability: profitability,
		leverage: leverage,
		efficiency: efficiency,
		signals: signals
	)
}

/// Alias for ``piotroskiScore(incomeStatement:balanceSheet:cashFlowStatement:period:priorPeriod:)``.
///
/// This function provides an alternative name that matches common financial analysis terminology.
///
/// - Parameters:
///   - incomeStatement: Income statement for analysis
///   - balanceSheet: Balance sheet for analysis
///   - cashFlowStatement: Cash flow statement for analysis
///   - period: Current period being analyzed
///   - priorPeriod: Prior period for comparison
/// - Returns: Piotroski F-Score (0-9) with breakdown by category
public func piotroskiFScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	cashFlowStatement: CashFlowStatement<T>,
	period: Period,
	priorPeriod: Period
) -> PiotroskiScore {
	return piotroskiScore(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		cashFlowStatement: cashFlowStatement,
		period: period,
		priorPeriod: priorPeriod
	)
}
