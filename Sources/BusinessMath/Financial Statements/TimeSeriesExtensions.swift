//
//  TimeSeriesExtensions.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Numerics

/// Shared utility extensions for TimeSeries operations used across financial statement analysis.

/// Calculates period-to-period average for balance sheet items.
///
/// For balance sheet accounts (assets, liabilities, equity), ratios often require
/// the average of beginning and ending balances to match with period flows
/// (like income or cash flow).
///
/// ## Formula
///
/// ```
/// Average Value[period] = (Value[prior period] + Value[current period]) / 2
/// ```
///
/// For the first period, uses the current value (no prior period available).
///
/// ## Use Cases
///
/// - **Asset Turnover**: Sales / Average Total Assets
/// - **ROA**: Net Income / Average Total Assets
/// - **Inventory Turnover**: COGS / Average Inventory
/// - **ROE**: Net Income / Average Equity
///
/// ## Example
///
/// ```swift
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let totalAssets = balanceSheet.totalAssets
/// // Q1: 100, Q2: 120, Q3: 140, Q4: 160
///
/// // averageTimeSeries is internal; the ratios that need a period-average
/// // balance call it for you.
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let turnover = assetTurnover(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet
/// )
/// ```
///
/// - Parameter timeSeries: Balance sheet time series to average
/// - Returns: Time series with period-to-period averages
internal func averageTimeSeries<T: Real>(_ timeSeries: TimeSeries<T>) -> TimeSeries<T> {
	let periods = timeSeries.periods
	guard !periods.isEmpty else {
		return timeSeries
	}

	var averagedValues: [Period: T] = [:]
	let two = T(2)

	// NON-DEFECT under contract §3.7, verified rather than assumed — both `?? T(0)` reads in
	// this loop are unreachable, so neither can fabricate a zero balance for an uncovered
	// period. `TimeSeries` stores `periods` and `values` from one dictionary and derives the
	// former from the latter: `self.periods = valueDict.keys.sorted()` at `TimeSeries.swift:185`
	// and `self.periods = data.keys.sorted()` at `:292` — the only two initializers that assign
	// the property, with the `Codable` init delegating to the first — while `subscript(_:)` is a
	// plain `values[period]` at `:324`. A series' period list and its key set are therefore the
	// same set. This loop indexes only `timeSeries.periods` (`i` and `i - 1` are both in
	// `0..<periods.count`), so every subscript hits. Left as written; do not re-audit.
	for i in 0..<periods.count {
		let currentPeriod = periods[i]
		let currentValue = timeSeries[currentPeriod] ?? T(0)  // unreachable fallback — see above

		if i == 0 {
			// First period: no prior period, use current value
			averagedValues[currentPeriod] = currentValue
		} else {
			// Subsequent periods: average of prior and current
			let priorPeriod = periods[i - 1]
			let priorValue = timeSeries[priorPeriod] ?? T(0)  // unreachable fallback — see above
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

extension TimeSeries where T: Real {
	/// Calculates period-over-period growth rates.
	///
	/// Growth rate is calculated as: (Current Value - Prior Value) / Prior Value
	///
	/// ## Example
	///
	/// ```swift
	/// let periods = Period.documentationQuarters
	/// let quarters = Period.documentationQuarters
	/// let revenue = TimeSeries(periods: quarters, values: [100, 110, 121, 133.1])
	/// let growth = revenue.periodOverPeriodGrowth()
	/// // Q2: 0.10 (10%), Q3: 0.10 (10%), Q4: 0.10 (10%)
	/// ```
	///
	/// - Returns: TimeSeries of growth rates (as decimals). First period is excluded.
	public func periodOverPeriodGrowth() -> TimeSeries<T> {
		let periods = self.periods
		guard periods.count > 1 else {
			return TimeSeries(periods: [], values: [])
		}

		var growthValues: [Period: T] = [:]

		// NON-DEFECT under contract §3.7, on the same verified invariant as `averageTimeSeries`
		// above: `TimeSeries.periods` is `values.keys.sorted()` (`TimeSeries.swift:185`, `:292`)
		// and `subscript(_:)` is `values[period]` (`:324`), so every period in `self.periods`
		// has a value. This loop indexes only `self.periods`, so neither `?? T(0)` can fire and
		// neither can report a fabricated zero balance as the basis of a growth rate. Left as
		// written; do not re-audit.
		for i in 1..<periods.count {
			let currentPeriod = periods[i]
			let priorPeriod = periods[i - 1]

			let currentValue = self[currentPeriod] ?? T(0)  // unreachable fallback — see above
			let priorValue = self[priorPeriod] ?? T(0)      // unreachable fallback — see above

			if priorValue != T(0) {
				let growth = (currentValue - priorValue) / priorValue
				growthValues[currentPeriod] = growth
			}
		}

		return TimeSeries(
			data: growthValues,
			metadata: TimeSeriesMetadata(
				name: "\(self.metadata.name) Growth",
				description: "Period-over-period growth rate",
				unit: nil
			)
		)
	}
}
