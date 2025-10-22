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
/// let totalAssets = balanceSheet.totalAssets
/// // Q1: 100, Q2: 120, Q3: 140, Q4: 160
///
/// let avgAssets = averageTimeSeries(totalAssets)
/// // Q1: 100 (no prior), Q2: 110, Q3: 130, Q4: 150
///
/// let assetTurnover = revenue / avgAssets
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
