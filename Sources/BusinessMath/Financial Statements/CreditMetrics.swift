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
/// let prices = [100.0, 102.5, 99.0, 105.0]
/// let entity = Entity(id: "ACME", name: "Acme Corp")
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let cashFlowStatement = try CashFlowStatement<Double>.documentationFixture
///
/// // Calculate Altman Z-Score
/// let marketPrice = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130]) // Stock prices
/// let sharesOutstanding = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130]) // Share count
///
/// let zScore = altmanZScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let currentPeriod = Period.quarter(year: 2025, quarter: 1)
/// // The lookup is optional because a period the statements do not cover has no Z-Score.
/// // `?? 0` here would report 0.00 — documented below as the distress zone — for a company
/// // that was merely not asked about.
/// if let z = zScore[currentPeriod], z > 2.99 {
///     print("Safe zone: Low bankruptcy risk")
/// }
///
/// // Calculate Piotroski F-Score
/// let priorPeriod = Period.quarter(year: 2024, quarter: 4)
/// let score = try piotroskiScore(
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
/// let cashFlowStatement = try CashFlowStatement<Double>.documentationFixture
/// let company = Entity.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let currentPeriod = Period.documentationQuarters[1]
/// let priorPeriod = Period.documentationQuarters[0]
///
/// let score = try piotroskiScore(
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
	/// All nine signals below are always present: `piotroskiScore(...)` assigns every
	/// key unconditionally. Subscripting with one of these literal names is therefore
	/// safe to force-unwrap; any other key is `nil`.
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
/// let period = Period.documentationQuarters[0]
/// let marketPrice = TimeSeries(periods: Period.documentationQuarters, values: [45, 47, 49, 51])
/// let sharesOutstanding = TimeSeries(periods: Period.documentationQuarters, values: [1000, 1000, 1000, 1000])
/// let periods = Period.documentationQuarters
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// // For a single period
/// let z = altmanZScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     period: Period.quarter(year: 2025, quarter: 1),
///     marketPrice: 50.0,
///     sharesOutstanding: 1_000_000
/// )
///
/// switch z {
/// case ..<1.81:
///     print("⚠️ Distress Zone (Z = \(z)): High bankruptcy risk")
/// case 1.81..<2.99:
///     print("⚡ Grey Zone (Z = \(z)): Moderate risk")
/// default:
///     print("✓ Safe Zone (Z = \(z)): Low bankruptcy risk")
/// }
///
/// // For multiple periods
/// let zScores = altmanZScore(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
/// // Optional for the same reason: the time-series overload emits only the periods its
/// // operands share, so a period outside them is absent rather than zero.
/// if let zForPeriod = zScores[period] {
///     print("Z = \(zForPeriod)")
/// }
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing EBIT and sales
///   - balanceSheet: Balance sheet with working capital, retained earnings, assets, liabilities
///   - period: Period to calculate Z-Score for
///   - marketPrice: Stock price per share for the period
///   - sharesOutstanding: Number of shares outstanding for the period
/// - Returns: Z-Score for the specified period, or `.nan` if the statements do not cover
///   `period` — a Z-Score is an observation about a period, and there is none to report for a
///   period that was never filed.
public func altmanZScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	period: Period,
	marketPrice: T,
	sharesOutstanding: T
) -> T {
	// Every one of the six figures below used to fall back to `?? T(0)` — a fabricated
	// observation for a period the statements do not cover. Measured on one profitable
	// company with 165,000 of assets and 12,000 of payables: the covered quarter scored 5.92
	// ("Safe Zone"), and the very next quarter — outside the books entirely, so
	// `totalAssets[period]` was nil — scored 0.00, which this file documents above as
	// "Distress Zone (High bankruptcy risk within 2 years)". A solvent company was reported
	// as facing bankruptcy purely because the caller asked about a quarter it had not
	// supplied, and the answer carried no mark of having been invented.
	//
	// The rule cannot be "detect the gap": `TimeSeries` cannot distinguish "before the series
	// starts" from "a hole in the middle", because its `periods` is derived from the value
	// keys and `Period` sorts type-first, so `periods.first`/`.last` do not bound a span. The
	// rule is to narrow the domain instead — a query about a period the data does not cover
	// is not answerable. The multi-period overload below already behaves this way for free,
	// being built from `TimeSeries` arithmetic, which emits only periods present in both
	// operands; this overload returns `T`, so `.nan` is how its signature says the same thing.
	guard let workingCapital = (balanceSheet.currentAssets - balanceSheet.currentLiabilities)[period],
		  let totalAssets = balanceSheet.totalAssets[period],
		  let retainedEarnings = balanceSheet.retainedEarnings[period],
		  let ebit = incomeStatement.operatingIncome[period],
		  let totalLiabilities = balanceSheet.totalLiabilities[period],
		  let sales = incomeStatement.totalRevenue[period]
	else { return T.nan }

	// Component A: Working Capital / Total Assets
	// Four of the five components are scaled by total assets, so a firm with none has no
	// Z-Score to report. Zero is the right answer here rather than a sentinel: a company
	// with no assets is not a going concern, and zero sits in the distress zone where such a
	// company belongs. Contrast the liabilities case below, where zero means the opposite.
	// This is now reached only for a covered period that genuinely reports no assets; the
	// uncovered-period path that also used to arrive here is diverted above.
	guard totalAssets != T(0) else { return T(0) }
	let a = workingCapital / totalAssets

	// Component B: Retained Earnings / Total Assets
	let b = retainedEarnings / totalAssets

	// Component C: EBIT / Total Assets
	let c = ebit / totalAssets

	// Component D: Market Value of Equity / Total Liabilities
	let marketValue = marketPrice * sharesOutstanding
	// This used to `guard totalLiabilities != T(0) else { return T(0) }`, which put the
	// *safest* possible balance sheet in the distress zone. Zero liabilities means debt-free,
	// and `Z < 1.81` is documented above as "High bankruptcy risk within 2 years", so the
	// function returned the strongest bankruptcy warning it has about a company that owes
	// nobody anything. Measured on one profitable company with 165,000 of assets: Z was 0.00
	// with no liabilities and 5.92 after taking on 12,000 of payables, so acquiring debt
	// moved it from "about to fail" to "safe".
	//
	// The ratio genuinely diverges when the denominator is zero, and an unbounded component D
	// carries the whole score above the 2.99 safe-zone threshold, which is where a debt-free
	// company belongs. With no equity value either the component is 0/0 and contributes
	// nothing. A negative liability total is incoherent input and is left to divide as before.
	//
	// The `marketValue > 0` test below is false for a `nan` as well as for zero, so a NaN
	// market capitalisation against zero liabilities would fall to the final `else` and
	// contribute a component of 0 — yielding a finite, confident Z-Score from an input nobody
	// can value. Screen it first: a company whose equity cannot be valued has no Z-Score.
	guard !marketValue.isNaN else { return T.nan }

	let d: T
	if totalLiabilities != T(0) {
		d = marketValue / totalLiabilities
	} else if marketValue > T(0) {
		d = T.infinity
	} else {
		d = T(0)
	}

	// Component E: Sales / Total Assets
	let e = sales / totalAssets

	// Z-Score = 1.2×A + 1.4×B + 3.3×C + 0.6×D + 1.0×E
	let coeffA = T(12) / T(10)  // 1.2
	let coeffB = T(14) / T(10)  // 1.4
	let coeffC = T(33) / T(10)  // 3.3
	let coeffD = T(6) / T(10)   // 0.6

	return coeffA * a + coeffB * b + coeffC * c + coeffD * d + e
}

/// Altman Z-Score for multiple periods - bankruptcy prediction model for manufacturing companies.
///
/// Calculates Z-Scores across all periods in the financial statements.
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

// MARK: - Statement Coverage

/// Reads one aggregated statement figure for one period, refusing rather than fabricating when
/// the statements do not cover that period.
///
/// A `nil` from one of these subscripts has exactly one meaning. Every aggregated accessor on
/// `IncomeStatement`, `BalanceSheet` and `CashFlowStatement` routes through
/// `FinancialStatementHelpers.aggregateAccounts`, which returns a **zero-filled** series over the
/// statement's own periods when no account carries the role being summed. So "this company has no
/// long-term debt" already arrives as a measured `0` at every covered period, and the only way a
/// lookup comes back empty is that the period was never filed. That is not a figure of zero; it
/// is the absence of a statement, and `?? T(0)` reported it as the former.
///
/// - Parameters:
///   - series: The aggregated series to read.
///   - period: The period being asked about.
///   - account: Name of the figure, carried into the thrown diagnostic.
/// - Returns: The figure the statements report for `period`.
/// - Throws: ``BusinessMathError/missingData(account:period:)`` when `period` is not covered.
private func requiredFigure<T: Real & Sendable>(
	_ series: TimeSeries<T>,
	_ period: Period,
	_ account: String
) throws -> T {
	guard let value = series[period] else {
		throw BusinessMathError.missingData(account: account, period: period.label)
	}
	return value
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
/// let cashFlowStatement = try CashFlowStatement<Double>.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let currentPeriod = Period.quarter(year: 2025, quarter: 1)
/// let priorPeriod = Period.quarter(year: 2024, quarter: 4)
///
/// let score = try piotroskiScore(
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
/// // Check individual signals. The nine F-Score signal names are a fixed set that
/// // is always populated, so these literal keys are safe to unwrap.
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
/// - Throws: ``BusinessMathError/missingData(account:period:)`` when either `period` or
///   `priorPeriod` falls outside the periods the statements cover. Six of the nine signals
///   compare the two periods against each other, so a score computed without one of them is not
///   a weaker answer — it is a different company's answer.
public func piotroskiScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	cashFlowStatement: CashFlowStatement<T>,
	period: Period,
	priorPeriod: Period
) throws -> PiotroskiScore {
	// Every one of the nineteen reads below used to end in `?? T(0)`. Six of the nine signals
	// compare this period against the prior one, so an uncovered prior period did not weaken the
	// answer — it scored a *different company*, one whose prior quarter reported nothing at all.
	// Against a baseline of zero, "did the margin improve?", "did the return on assets improve?"
	// and "did asset turnover improve?" are all answered yes, and the points are awarded. The
	// damage is per-signal rather than uniform: `noNewEquity` goes the other way, because the
	// whole of equity then looks newly issued.
	//
	// Measured on the deteriorating company in `CreditMetricsCoverageTests`, whose prior quarter
	// was refiled as literal zeros to reproduce exactly what these fallbacks claimed to read:
	// **4 points against its real prior quarter, 7 against the fabricated one** — across the
	// "F >= 7: strong fundamentals (buy signal for value investors)" threshold this file
	// documents above, for a company worsening on every comparative signal it has.
	//
	// This is the `altmanZScore` defect above, one rung worse. There the fabricated zero produced
	// a single wrong number; here it produces a wrong number that moves in the direction of
	// confidence. Neither can be detected after the fact: `PiotroskiScore.totalScore` is an `Int`
	// with no room for "not answerable", and its `signals` DocC promises all nine keys are always
	// present. So the domain is narrowed instead — contract §3.7 — and the function refuses.
	// Refusing is not the same as inventing a result case, which §3.4 forbids.
	var signals: [String: Bool] = [:]

	// MARK: Profitability Signals (4 points max)

	let netIncomeSeries = incomeStatement.netIncome

	// 1. Positive net income
	let netIncome = try requiredFigure(netIncomeSeries, period, "netIncome")
	signals["positiveNetIncome"] = netIncome > T(0)

	// 2. Positive operating cash flow
	let operatingCashFlow = try requiredFigure(cashFlowStatement.operatingCashFlow, period, "operatingCashFlow")
	signals["positiveOperatingCashFlow"] = operatingCashFlow > T(0)

	// 3. Increasing ROA
	let totalAssetsSeries = balanceSheet.totalAssets
	let totalAssetsCurrent = try requiredFigure(totalAssetsSeries, period, "totalAssets")
	let totalAssetsPrior = try requiredFigure(totalAssetsSeries, priorPeriod, "totalAssets")
	let netIncomePrior = try requiredFigure(netIncomeSeries, priorPeriod, "netIncome")
	// A company with no assets has no return on them, and zero is the right fallback here rather
	// than a sentinel: it sits at the *unfavourable* end of the ROA scale, which is where a firm
	// that owns nothing belongs, and it withholds the improvement point instead of awarding it.
	// This mirrors `altmanZScore`'s `totalAssets == 0` guard above, which is correct for the same
	// reason. Contrast the current-ratio fallback below: textually the same shape, opposite sense.
	let roaCurrent = totalAssetsCurrent != T(0) ? netIncome / totalAssetsCurrent : T(0)
	let roaPrior = totalAssetsPrior != T(0) ? netIncomePrior / totalAssetsPrior : T(0)
	signals["increasingROA"] = roaCurrent > roaPrior

	// 4. Quality of earnings (operating cash flow > net income)
	signals["qualityEarnings"] = operatingCashFlow > netIncome

	// MARK: Leverage/Liquidity Signals (3 points max)

	// 5. Decreasing long-term debt
	let ltDebt = balanceSheet.longTermDebt
	let ltDebtCurrent = try requiredFigure(ltDebt, period, "longTermDebt")
	let ltDebtPrior = try requiredFigure(ltDebt, priorPeriod, "longTermDebt")
	// If no debt in either period, count as positive (no increase). A debt-free company reports a
	// genuine, measured 0 at every covered period — `aggregateAccounts` zero-fills when no account
	// carries the role — so this arm is now reached on real figures rather than on absent ones.
	signals["decreasingDebt"] = ltDebtCurrent <= ltDebtPrior

	// 6. Increasing current ratio
	let currentAssetsSeries = balanceSheet.currentAssets
	let currentLiabilitiesSeries = balanceSheet.currentLiabilities
	let currentAssetsCurrent = try requiredFigure(currentAssetsSeries, period, "currentAssets")
	let currentLiabilitiesCurrent = try requiredFigure(currentLiabilitiesSeries, period, "currentLiabilities")
	let currentAssetsPrior = try requiredFigure(currentAssetsSeries, priorPeriod, "currentAssets")
	let currentLiabilitiesPrior = try requiredFigure(currentLiabilitiesSeries, priorPeriod, "currentLiabilities")

	// This pair used to read `currentLiabilities != 0 ? assets / liabilities : T(0)`, which put the
	// *strongest* liquidity position at the bottom of the scale. Zero current liabilities means
	// every short-term obligation is settled; the ratio it produces is unbounded, not zero. A
	// company that paid off its payables between the two periods went from a finite ratio to 0,
	// so `increasingCurrentRatio` read false and it *lost* the liquidity point for becoming
	// liquid. This is the same wrong-end-of-the-scale error `altmanZScore`'s component D carried
	// for `totalLiabilities == 0`, four lines from a guard that was correct, and it is repaired
	// the same way: diverge to infinity when there is something to divide, and contribute nothing
	// when the numerator is zero too (0/0 says nothing about liquidity either way).
	let currentRatioCurrent: T
	if currentLiabilitiesCurrent != T(0) {
		currentRatioCurrent = currentAssetsCurrent / currentLiabilitiesCurrent
	} else if currentAssetsCurrent > T(0) {
		currentRatioCurrent = T.infinity
	} else {
		currentRatioCurrent = T(0)
	}

	let currentRatioPrior: T
	if currentLiabilitiesPrior != T(0) {
		currentRatioPrior = currentAssetsPrior / currentLiabilitiesPrior
	} else if currentAssetsPrior > T(0) {
		currentRatioPrior = T.infinity
	} else {
		currentRatioPrior = T(0)
	}

	// Two unbounded ratios compare equal, so a company with no current liabilities in either
	// period does not improve and does not earn the point — which is the truth about it.
	signals["increasingCurrentRatio"] = currentRatioCurrent > currentRatioPrior

	// 7. No new equity issuance
	let totalEquitySeries = balanceSheet.totalEquity
	let totalEquityCurrent = try requiredFigure(totalEquitySeries, period, "totalEquity")
	let totalEquityPrior = try requiredFigure(totalEquitySeries, priorPeriod, "totalEquity")

	// Check if common stock increased (proxy for new issuance)
	// More sophisticated: check if equity increased beyond retained earnings
	let retainedEarningsSeries = balanceSheet.retainedEarnings
	let retainedEarningsCurrent = try requiredFigure(retainedEarningsSeries, period, "retainedEarnings")
	let retainedEarningsPrior = try requiredFigure(retainedEarningsSeries, priorPeriod, "retainedEarnings")
	let retainedEarningsChange = retainedEarningsCurrent - retainedEarningsPrior
	let equityChange = totalEquityCurrent - totalEquityPrior

	// If equity increase exceeds retained earnings increase, new shares were issued
	signals["noNewEquity"] = equityChange <= retainedEarningsChange

	// MARK: Operating Efficiency Signals (2 points max)

	// 8. Increasing gross margin
	let grossProfitSeries = incomeStatement.grossProfit
	let revenueSeries = incomeStatement.totalRevenue
	let grossProfitCurrent = try requiredFigure(grossProfitSeries, period, "grossProfit")
	let revenueCurrent = try requiredFigure(revenueSeries, period, "totalRevenue")
	let grossProfitPrior = try requiredFigure(grossProfitSeries, priorPeriod, "grossProfit")
	let revenuePrior = try requiredFigure(revenueSeries, priorPeriod, "totalRevenue")

	// Zero revenue leaves gross margin undefined, and zero is the correct fallback for the same
	// reason as ROA above: it is the bottom of a margin scale, so a company that sold nothing is
	// denied the improvement point rather than handed it.
	let grossMarginCurrent = revenueCurrent != T(0) ? grossProfitCurrent / revenueCurrent : T(0)
	let grossMarginPrior = revenuePrior != T(0) ? grossProfitPrior / revenuePrior : T(0)

	signals["increasingGrossMargin"] = grossMarginCurrent > grossMarginPrior

	// 9. Increasing asset turnover
	// Same reading of a zero asset base as ROA: no assets means no turnover to improve on, and
	// zero is the unfavourable end of this scale.
	let assetTurnoverCurrent = totalAssetsCurrent != T(0) ? revenueCurrent / totalAssetsCurrent : T(0)
	let assetTurnoverPrior = totalAssetsPrior != T(0) ? revenuePrior / totalAssetsPrior : T(0)
	signals["increasingAssetTurnover"] = assetTurnoverCurrent > assetTurnoverPrior

	// MARK: Calculate Scores

	let profitabilitySignals = [
		"positiveNetIncome",
		"positiveOperatingCashFlow",
		"increasingROA",
		"qualityEarnings"
	]
	// The `?? false` fallbacks below are unreachable: each of the nine keys is assigned
	// unconditionally above, and the lists here are literals of those same nine names. They are a
	// dictionary default over a closed key set rather than a substitute for a measurement.
	let profitability = profitabilitySignals.filter { signals[$0] ?? false }.count

	let leverageSignals = [
		"decreasingDebt",
		"increasingCurrentRatio",
		"noNewEquity"
	]
	let leverage = leverageSignals.filter { signals[$0] ?? false }.count

	let efficiencySignals = [
		"increasingGrossMargin",
		"increasingAssetTurnover"
	]
	let efficiency = efficiencySignals.filter { signals[$0] ?? false }.count

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
/// - Throws: ``BusinessMathError/missingData(account:period:)`` when either period falls outside
///   the periods the statements cover, exactly as the function this forwards to.
public func piotroskiFScore<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	cashFlowStatement: CashFlowStatement<T>,
	period: Period,
	priorPeriod: Period
) throws -> PiotroskiScore {
	return try piotroskiScore(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		cashFlowStatement: cashFlowStatement,
		period: period,
		priorPeriod: priorPeriod
	)
}
