//
//  TimeSeriesOperations.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - AggregationMethod

/// Methods for aggregating time series data to larger periods.
public enum AggregationMethod {
	/// Sum all values in the period.
	case sum

	/// Average all values in the period.
	case average

	/// Take the first value in the period.
	case first

	/// Take the last value in the period.
	case last

	/// Take the minimum value in the period.
	case min

	/// Take the maximum value in the period.
	case max
}

// MARK: - TimeSeries Operations

extension TimeSeries {

	// MARK: - Transformation

	/// Returns a new time series with transformed values.
	///
	/// - Parameter transform: A closure that transforms each value.
	/// - Returns: A new time series with transformed values.
	///
	/// ## Example
	/// ```swift
	/// let doubled = timeSeries.mapValues { $0 * 2.0 }
	/// ```
	public func mapValues(_ transform: (T) -> T) -> TimeSeries<T> {
		let newValues = valuesArray.map(transform)
		return TimeSeries(periods: periods, values: newValues, metadata: metadata)
	}

	/// Returns a new time series containing only values that satisfy the predicate.
	///
	/// - Parameter predicate: A closure that tests each value.
	/// - Returns: A new time series with filtered values.
	///
	/// ## Example
	/// ```swift
	/// let highValues = timeSeries.filterValues { $0 > 100.0 }
	/// ```
	public func filterValues(_ predicate: (T) -> Bool) -> TimeSeries<T> {
		var filteredPeriods: [Period] = []
		var filteredValues: [T] = []

		for period in periods {
			if let value = self[period], predicate(value) {
				filteredPeriods.append(period)
				filteredValues.append(value)
			}
		}

		return TimeSeries(periods: filteredPeriods, values: filteredValues, metadata: metadata)
	}

	// MARK: - Binary Operations

	/// Combines two time series using a binary operation.
	///
	/// Only periods present in both time series are included in the result.
	///
	/// - Parameters:
	///   - other: The other time series to combine with.
	///   - operation: A closure that combines values from both series.
	/// - Returns: A new time series with combined values.
	///
	/// ## Example
	/// ```swift
	/// let sum = ts1.zip(with: ts2) { $0 + $1 }
	/// let product = ts1.zip(with: ts2) { $0 * $1 }
	/// ```
	public func zip(with other: TimeSeries<T>, _ operation: (T, T) -> T) -> TimeSeries<T> {
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in periods {
			if let value1 = self[period], let value2 = other[period] {
				resultPeriods.append(period)
				resultValues.append(operation(value1, value2))
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Missing Value Handling

	/// Fills missing values by propagating the last known value forward.
	///
	/// - Parameter targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with forward-filled values.
	///
	/// ## Example
	/// ```swift
	/// let allMonths = (1...12).map { Period.month(year: 2025, month: $0) }
	/// let filled = sparseSeries.fillForward(over: allMonths)
	/// ```
	public func fillForward(over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T?] = []
		var lastKnownValue: T? = nil

		for period in targetPeriods {
			if let value = self[period] {
				lastKnownValue = value
				resultValues.append(value)
			} else {
				resultValues.append(lastKnownValue)
			}
		}

		let nonNilValues = resultValues.compactMap { $0 }
		let nonNilPeriods = Swift.zip(targetPeriods, resultValues).compactMap { period, value in
			value != nil ? period : nil
		}

		return TimeSeries(periods: nonNilPeriods, values: nonNilValues, metadata: metadata)
	}

	/// Fills missing values by propagating the next known value backward.
	///
	/// - Parameter targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with backward-filled values.
	///
	/// ## Example
	/// ```swift
	/// let allMonths = (1...12).map { Period.month(year: 2025, month: $0) }
	/// let filled = sparseSeries.fillBackward(over: allMonths)
	/// ```
	public func fillBackward(over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T?] = Array(repeating: nil, count: targetPeriods.count)
		var nextKnownValue: T? = nil

		// Iterate backward
		for i in stride(from: targetPeriods.count - 1, through: 0, by: -1) {
			let period = targetPeriods[i]

			if let value = self[period] {
				nextKnownValue = value
				resultValues[i] = value
			} else {
				resultValues[i] = nextKnownValue
			}
		}

		let nonNilValues = resultValues.compactMap { $0 }
		let nonNilPeriods = Swift.zip(targetPeriods, resultValues).compactMap { period, value in
			value != nil ? period : nil
		}

		return TimeSeries(periods: nonNilPeriods, values: nonNilValues, metadata: metadata)
	}

	/// Fills missing values with a constant value.
	///
	/// - Parameters:
	///   - value: The constant value to use for missing periods.
	///   - targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with missing values filled.
	///
	/// ## Example
	/// ```swift
	/// let filled = sparseSeries.fillMissing(with: 0.0, over: allMonths)
	/// ```
	public func fillMissing(with value: T, over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T] = []

		for period in targetPeriods {
			if let existingValue = self[period] {
				resultValues.append(existingValue)
			} else {
				resultValues.append(value)
			}
		}

		return TimeSeries(periods: targetPeriods, values: resultValues, metadata: metadata)
	}

	/// Fills missing values using linear interpolation.
	///
	/// Values between known points are estimated using linear interpolation.
	/// Periods outside the range of known values remain nil.
	///
	/// - Parameter targetPeriods: The complete set of periods to interpolate.
	/// - Returns: A new time series with interpolated values.
	///
	/// ## Example
	/// ```swift
	/// let interpolated = sparseSeries.interpolate(over: allMonths)
	/// ```
	public func interpolate(over targetPeriods: [Period]) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Find first and last known values
		var firstKnownIndex: Int? = nil
		var lastKnownIndex: Int? = nil

		for (i, period) in targetPeriods.enumerated() {
			if self[period] != nil {
				if firstKnownIndex == nil {
					firstKnownIndex = i
				}
				lastKnownIndex = i
			}
		}

		guard let firstIndex = firstKnownIndex, let lastIndex = lastKnownIndex else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		// Interpolate between first and last known values
		for i in firstIndex...lastIndex {
			let period = targetPeriods[i]

			if let knownValue = self[period] {
				resultPeriods.append(period)
				resultValues.append(knownValue)
			} else {
				// Find surrounding known values
				var prevIndex = i - 1
				while prevIndex >= firstIndex && self[targetPeriods[prevIndex]] == nil {
					prevIndex -= 1
				}

				var nextIndex = i + 1
				while nextIndex <= lastIndex && self[targetPeriods[nextIndex]] == nil {
					nextIndex += 1
				}

				if prevIndex >= firstIndex && nextIndex <= lastIndex {
					let prevValue = self[targetPeriods[prevIndex]]!
					let nextValue = self[targetPeriods[nextIndex]]!
					let steps = T(nextIndex - prevIndex)
					let position = T(i - prevIndex)
					let fraction = position / steps

					// Linear interpolation
					let interpolated = prevValue + (nextValue - prevValue) * fraction
					resultPeriods.append(period)
					resultValues.append(interpolated)
				}
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Aggregation

	/// Aggregates the time series to a larger period type.
	///
	/// - Parameters:
	///   - targetType: The target period type (must be larger than current).
	///   - method: The aggregation method to use.
	/// - Returns: A new time series with aggregated values.
	///
	/// ## Example
	/// ```swift
	/// // Aggregate monthly to quarterly
	/// let quarterly = monthly.aggregate(to: .quarterly, method: .sum)
	///
	/// // Aggregate monthly to annual
	/// let annual = monthly.aggregate(to: .annual, method: .average)
	/// ```
	public func aggregate(to targetType: PeriodType, method: AggregationMethod) -> TimeSeries<T> {
		// Group periods by their target period
		var groups: [Period: [T]] = [:]

		for period in periods {
			guard let value = self[period] else { continue }

			// Determine which target period this belongs to
			let targetPeriod: Period

			switch targetType {
			case .quarterly:
				// Map month to quarter
				let calendar = Calendar.current
				let components = calendar.dateComponents([.year, .month], from: period.startDate)
				let quarter = (components.month! - 1) / 3 + 1
				targetPeriod = Period.quarter(year: components.year!, quarter: quarter)

			case .annual:
				// Map any period to year
				let calendar = Calendar.current
				let year = calendar.component(.year, from: period.startDate)
				targetPeriod = Period.year(year)

			default:
				// Can't aggregate to smaller or same period type
				continue
			}

			groups[targetPeriod, default: []].append(value)
		}

		// Apply aggregation method to each group
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for (targetPeriod, values) in groups.sorted(by: { $0.key < $1.key }) {
			guard !values.isEmpty else { continue }

			let aggregated: T

			switch method {
			case .sum:
				aggregated = values.reduce(T.zero, +)

			case .average:
				let sum = values.reduce(T.zero, +)
				aggregated = sum / T(values.count)

			case .first:
				aggregated = values.first!

			case .last:
				aggregated = values.last!

			case .min:
				aggregated = values.min()!

			case .max:
				aggregated = values.max()!
			}

			resultPeriods.append(targetPeriod)
			resultValues.append(aggregated)
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}
}
