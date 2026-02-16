//
//  TimeSeriesAnalytics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Forecast Error Metrics

/// Error metrics for comparing forecasted values against actual values.
///
/// Contains standard forecast accuracy measures used to evaluate and compare
/// different forecasting models.
///
/// ## Metrics Included
/// - **RMSE** (Root Mean Squared Error): Penalizes large errors more heavily
/// - **MAE** (Mean Absolute Error): Average magnitude of errors
/// - **MAPE** (Mean Absolute Percentage Error): Percentage error, scale-independent
///
/// ## Example
/// ```swift
/// let actual = TimeSeries(periods: periods, values: [100, 110, 120])
/// let forecast = TimeSeries(periods: periods, values: [98, 112, 118])
///
/// let metrics = actual.forecastError(against: forecast)
/// print("RMSE: \(metrics.rmse)")
/// print("MAE: \(metrics.mae)")
/// print("MAPE: \(metrics.mape)")
///
/// // Compare models
/// if model1Metrics.rmse < model2Metrics.rmse {
///     print("Model 1 is more accurate")
/// }
/// ```
public struct ForecastErrorMetrics<T: Real & Sendable & Codable>: Sendable where T: BinaryFloatingPoint {
	/// Root Mean Squared Error - sqrt(mean((actual - forecast)²))
	///
	/// RMSE penalizes larger errors more heavily due to squaring.
	/// Lower values indicate better forecast accuracy.
	public let rmse: T

	/// Mean Absolute Error - mean(|actual - forecast|)
	///
	/// MAE represents the average magnitude of errors.
	/// Lower values indicate better forecast accuracy.
	public let mae: T

	/// Mean Absolute Percentage Error - mean(|actual - forecast| / |actual|)
	///
	/// MAPE expresses error as a percentage, making it scale-independent.
	/// Lower values indicate better forecast accuracy.
	/// Note: Excludes periods where actual value is zero to avoid division by zero.
	public let mape: T

	/// Number of periods included in the error calculation
	///
	/// Only periods present in both actual and forecast series are counted.
	public let count: Int

	/// Creates forecast error metrics.
	///
	/// - Parameters:
	///   - rmse: Root mean squared error
	///   - mae: Mean absolute error
	///   - mape: Mean absolute percentage error
	///   - count: Number of periods compared
	public init(rmse: T, mae: T, mape: T, count: Int) {
		self.rmse = rmse
		self.mae = mae
		self.mape = mape
		self.count = count
	}

	/// Human-readable summary of error metrics.
	@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
	public var summary: String {
		"""
		Forecast Error Metrics
		======================
		Periods Compared: \(count)
		RMSE: \(rmse.number(4))
		MAE:  \(mae.number(4))
		MAPE: \(mape.percent(2))
		"""
	}
}

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
	///   - start: The starting period.
	///   - end: The ending period.
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

	// MARK: - Forecast Evaluation

	/// Calculates forecast error metrics by comparing this series (actual) against a forecast.
	///
	/// Computes standard forecast accuracy measures: RMSE, MAE, and MAPE.
	/// Only periods present in both series are included in the calculation.
	///
	/// - Parameter forecast: The forecasted time series to compare against.
	/// - Returns: Forecast error metrics including RMSE, MAE, MAPE, and comparison count.
	///
	/// ## Example
	/// ```swift
	/// let actual = TimeSeries(periods: periods, values: [100, 110, 120, 130])
	/// let forecast = TimeSeries(periods: periods, values: [98, 112, 118, 132])
	///
	/// let metrics = actual.forecastError(against: forecast)
	///
	/// print("RMSE: \(metrics.rmse.number(2))")
	/// print("MAE: \(metrics.mae.number(2))")
	/// print("MAPE: \(metrics.mape.percent(2))")
	///
	/// // Compare two forecast models
	/// let model1Metrics = actual.forecastError(against: linearForecast)
	/// let model2Metrics = actual.forecastError(against: exponentialForecast)
	///
	/// let bestModel = model1Metrics.rmse < model2Metrics.rmse ? "Linear" : "Exponential"
	/// print("Best model: \(bestModel)")
	/// ```
	///
	/// ## Metrics Explanation
	///
	/// **RMSE (Root Mean Squared Error)**
	/// - Calculated as: sqrt(mean((actual - forecast)²))
	/// - Penalizes large errors more heavily due to squaring
	/// - Same units as the original data
	/// - Useful when large errors are particularly undesirable
	///
	/// **MAE (Mean Absolute Error)**
	/// - Calculated as: mean(|actual - forecast|)
	/// - Average magnitude of all errors
	/// - Same units as the original data
	/// - More robust to outliers than RMSE
	///
	/// **MAPE (Mean Absolute Percentage Error)**
	/// - Calculated as: mean(|actual - forecast| / |actual|)
	/// - Expressed as a percentage
	/// - Scale-independent, useful for comparing across different data scales
	/// - Excludes periods where actual value is zero
	///
	/// ## Notes
	/// - If series have no overlapping periods, returns NaN or 0 for all metrics with count = 0
	/// - MAPE calculation skips periods where actual value is zero to avoid division by zero
	/// - RMSE ≥ MAE always (equality only when all errors are identical)
	public func forecastError(against forecast: TimeSeries<T>) -> ForecastErrorMetrics<T> where T: BinaryFloatingPoint {
		var sumSquaredError = T.zero
		var sumAbsoluteError = T.zero
		var sumAbsPercentError = T.zero
		var count = 0
		var mapeCount = 0

		// Iterate through all periods in the actual series
		for period in periods {
			guard let actualValue = self[period],
				  let forecastValue = forecast[period] else {
				continue  // Skip periods not present in both series
			}

			let error = actualValue - forecastValue

			// Accumulate for RMSE and MAE
			sumSquaredError = sumSquaredError + (error * error)
			sumAbsoluteError = sumAbsoluteError + abs(error)
			count += 1

			// Accumulate for MAPE (only for non-zero actuals)
			if actualValue != T.zero {
				let percentError = abs(error / actualValue)
				sumAbsPercentError = sumAbsPercentError + percentError
				mapeCount += 1
			}
		}

		// Calculate final metrics
		guard count > 0 else {
			// No overlapping periods - return zero/NaN metrics
			return ForecastErrorMetrics(rmse: T.zero, mae: T.zero, mape: T.zero, count: 0)
		}

		let mse = sumSquaredError / T(count)
		let rmse = sqrt(mse)
		let mae = sumAbsoluteError / T(count)

		// Calculate MAPE only if we had non-zero actuals
		let mape: T
		if mapeCount > 0 {
			mape = (sumAbsPercentError / T(mapeCount))
		} else {
			mape = T.zero  // All actual values were zero
		}

		return ForecastErrorMetrics(rmse: rmse, mae: mae, mape: mape, count: count)
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
	/// Percent change is calculated as ((current - previous) / previous).
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
		return growth.mapValues { $0 }
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
