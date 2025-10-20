//
//  TimeSeriesAnalytics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - TimeSeries Analytics

extension TimeSeries {

	// MARK: - Growth Metrics

	/// Calculates period-over-period growth rates.
	///
	/// Growth rate is calculated as (current - previous) / previous.
	///
	/// - Parameter lag: The number of periods to look back (default: 1).
	/// - Returns: A time series of growth rates.
	///
	/// ## Example
	/// ```swift
	/// let revenue = TimeSeries(periods: months, values: [100, 110, 121])
	/// let growth = revenue.growthRate(lag: 1)  // [nil, 0.10, 0.10]
	/// ```
	public func growthRate(lag: Int = 1) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for i in lag..<periods.count {
			let currentPeriod = periods[i]
			let previousPeriod = periods[i - lag]

			if let currentValue = self[currentPeriod],
			   let previousValue = self[previousPeriod],
			   previousValue != T.zero {
				let rate = (currentValue - previousValue) / previousValue
				resultPeriods.append(currentPeriod)
				resultValues.append(rate)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates the Compound Annual Growth Rate (CAGR).
	///
	/// CAGR = (endingValue / beginningValue)^(1/years) - 1
	///
	/// The number of years is calculated precisely from the period dates,
	/// accounting for the exact number of days between the start of the
	/// starting period and the end of the ending period.
	///
	/// - Parameters:
	///   - from: The starting period.
	///   - to: The ending period.
	/// - Returns: The CAGR as a decimal (e.g., 0.10 for 10%).
	///
	/// ## Example
	/// ```swift
	/// let jan2020 = Period.month(year: 2020, month: 1)
	/// let jan2025 = Period.month(year: 2025, month: 1)
	/// let cagr = revenue.cagr(from: jan2020, to: jan2025)
	/// // Calculates CAGR over exactly 5.0 years
	/// ```
	public func cagr(from start: Period, to end: Period) -> T {
		guard let startValue = self[start],
			  let endValue = self[end],
			  startValue > T.zero else {
			return T.zero
		}

		// Calculate exact fractional years from period start dates
		// Using startDate for both provides intuitive period-to-period calculations
		// (e.g., "Jan 2020 to Jan 2025" = exactly 5 years)
		let calendar = Calendar.current
		let components = calendar.dateComponents([.day],
												 from: start.startDate,
												 to: end.startDate)
		let days = T(components.day ?? 0)
		// Use 365.25 to account for leap years over long periods
		let daysPerYear = T(365) + T(1) / T(4)
		let years = days / daysPerYear

		guard years > T.zero else { return T.zero }

		let ratio = endValue / startValue
		let exponent = T(1) / years
		let growth = T.pow(ratio, exponent) - T(1)

		return growth
	}

	// MARK: - Moving Averages

	/// Calculates a simple moving average.
	///
	/// - Parameter window: The number of periods in the moving window.
	/// - Returns: A time series of moving averages.
	///
	/// ## Example
	/// ```swift
	/// let smoothed = revenue.movingAverage(window: 3)
	/// ```
	public func movingAverage(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Optimized sliding window approach: maintain running sum
		var windowSum = T.zero
		var windowCount = 0

		// Initialize the first window
		for i in 0..<window {
			if i < periods.count, let value = self[periods[i]] {
				windowSum = windowSum + value
				windowCount += 1
			}
		}

		// First window result
		if windowCount == window {
			let average = windowSum / T(window)
			resultPeriods.append(periods[window - 1])
			resultValues.append(average)
		}

		// Slide the window for remaining positions
		for i in window..<periods.count {
			// Remove the leftmost value from the window
			if let oldValue = self[periods[i - window]] {
				windowSum = windowSum - oldValue
				windowCount -= 1
			}

			// Add the new rightmost value to the window
			if let newValue = self[periods[i]] {
				windowSum = windowSum + newValue
				windowCount += 1
			}

			// Only add result if we have a full window
			if windowCount == window {
				let average = windowSum / T(window)
				resultPeriods.append(periods[i])
				resultValues.append(average)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates an exponential moving average.
	///
	/// EMA = alpha * current + (1 - alpha) * previous_EMA
	///
	/// - Parameter alpha: The smoothing factor (0 < alpha <= 1).
	/// - Returns: A time series of exponential moving averages.
	///
	/// ## Example
	/// ```swift
	/// let ema = revenue.exponentialMovingAverage(alpha: 0.3)
	/// ```
	public func exponentialMovingAverage(alpha: T) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		var ema: T = T.zero

		for (index, period) in periods.enumerated() {
			guard let value = self[period] else { continue }

			if index == 0 {
				ema = value  // Initialize with first value
			} else {
				ema = alpha * value + (T(1) - alpha) * ema
			}

			resultPeriods.append(period)
			resultValues.append(ema)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Cumulative Operations

	/// Calculates the cumulative sum.
	///
	/// - Returns: A time series of cumulative sums.
	///
	/// ## Example
	/// ```swift
	/// let ytd = monthlyRevenue.cumulative()  // Year-to-date
	/// ```
	public func cumulative() -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []
		var sum = T.zero

		for period in periods {
			guard let value = self[period] else { continue }
			sum = sum + value
			resultPeriods.append(period)
			resultValues.append(sum)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Differences

	/// Calculates period-over-period differences.
	///
	/// - Parameter lag: The number of periods to look back (default: 1).
	/// - Returns: A time series of differences.
	///
	/// ## Example
	/// ```swift
	/// let change = revenue.diff(lag: 1)  // Period-over-period change
	/// ```
	public func diff(lag: Int = 1) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for i in lag..<periods.count {
			let currentPeriod = periods[i]
			let previousPeriod = periods[i - lag]

			if let currentValue = self[currentPeriod],
			   let previousValue = self[previousPeriod] {
				let difference = currentValue - previousValue
				resultPeriods.append(currentPeriod)
				resultValues.append(difference)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates period-over-period percent changes.
	///
	/// Percent change is calculated as ((current - previous) / previous) * 100.
	///
	/// - Parameter lag: The number of periods to look back (default: 1).
	/// - Returns: A time series of percent changes.
	///
	/// ## Example
	/// ```swift
	/// let pctChange = revenue.percentChange(lag: 1)
	/// ```
	public func percentChange(lag: Int = 1) -> TimeSeries<T> {
		let growth = self.growthRate(lag: lag)
		return growth.mapValues { $0 * T(100) }
	}

	// MARK: - Rolling Window Operations

	/// Calculates a rolling sum over a fixed window.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling sums.
	///
	/// ## Example
	/// ```swift
	/// let rolling3Month = revenue.rollingSum(window: 3)
	/// ```
	public func rollingSum(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Optimized sliding window approach: maintain running sum
		var windowSum = T.zero
		var windowCount = 0

		// Initialize the first window
		for i in 0..<window {
			if i < periods.count, let value = self[periods[i]] {
				windowSum = windowSum + value
				windowCount += 1
			}
		}

		// First window result
		if windowCount == window {
			resultPeriods.append(periods[window - 1])
			resultValues.append(windowSum)
		}

		// Slide the window for remaining positions
		for i in window..<periods.count {
			// Remove the leftmost value from the window
			if let oldValue = self[periods[i - window]] {
				windowSum = windowSum - oldValue
				windowCount -= 1
			}

			// Add the new rightmost value to the window
			if let newValue = self[periods[i]] {
				windowSum = windowSum + newValue
				windowCount += 1
			}

			// Only add result if we have a full window
			if windowCount == window {
				resultPeriods.append(periods[i])
				resultValues.append(windowSum)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates a rolling minimum over a fixed window.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling minimums.
	///
	/// ## Example
	/// ```swift
	/// let rollingMin = revenue.rollingMin(window: 3)
	/// ```
	public func rollingMin(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Optimized: iterate over indices directly without creating arrays
		for i in (window - 1)..<periods.count {
			var minValue: T? = nil
			var validCount = 0

			// Find minimum in current window
			for j in (i - window + 1)...i {
				if let value = self[periods[j]] {
					if let currentMin = minValue {
						minValue = Swift.min(currentMin, value)
					} else {
						minValue = value
					}
					validCount += 1
				}
			}

			// Only add result if we have a full window
			if validCount == window, let min = minValue {
				resultPeriods.append(periods[i])
				resultValues.append(min)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	/// Calculates a rolling maximum over a fixed window.
	///
	/// - Parameter window: The number of periods in the rolling window.
	/// - Returns: A time series of rolling maximums.
	///
	/// ## Example
	/// ```swift
	/// let rollingMax = revenue.rollingMax(window: 3)
	/// ```
	public func rollingMax(window: Int) -> TimeSeries<T> {
		guard window > 0 && window <= count else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Optimized: iterate over indices directly without creating arrays
		for i in (window - 1)..<periods.count {
			var maxValue: T? = nil
			var validCount = 0

			// Find maximum in current window
			for j in (i - window + 1)...i {
				if let value = self[periods[j]] {
					if let currentMax = maxValue {
						maxValue = Swift.max(currentMax, value)
					} else {
						maxValue = value
					}
					validCount += 1
				}
			}

			// Only add result if we have a full window
			if validCount == window, let max = maxValue {
				resultPeriods.append(periods[i])
				resultValues.append(max)
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}
}
