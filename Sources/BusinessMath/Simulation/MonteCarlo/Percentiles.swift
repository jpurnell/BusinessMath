//
//  Percentiles.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A structure containing key percentile values from a dataset.
///
/// Percentiles are values below which a given percentage of observations fall.
/// This struct provides standard percentiles commonly used in risk analysis and statistics.
///
/// ## Percentile Calculation
///
/// Uses linear interpolation between data points for accurate percentile estimation:
/// - p025: 2.5th percentile (bottom 2.5%)
/// - p5: 5th percentile (bottom 5%)
/// - p10: 10th percentile
/// - p25: 25th percentile (first quartile, Q1)
/// - p50: 50th percentile (median, Q2)
/// - p75: 75th percentile (third quartile, Q3)
/// - p90: 90th percentile
/// - p95: 95th percentile (top 5% threshold)
/// - p975: 97.5th percentile (top 2.5% threshold)
/// - p99: 99th percentile (top 1% threshold)
///
/// ## Example
///
/// ```swift
/// let simulationValues = [/* 10,000 simulation results */]
/// let percentiles = Percentiles(values: simulationValues)
///
/// print("Median outcome: \(percentiles.p50)")
/// print("95% confidence: value will be above \(percentiles.p5)")
/// print("Interquartile range: \(percentiles.interquartileRange)")
/// ```
///
/// 
public struct Percentiles: Sendable {
	public let values: [Double]
	
	// MARK: - Min/Max

	/// The minimum value in the dataset
	public let min: Double

	/// The maximum value in the dataset
	public let max: Double
	
	// MARK: - Standard Percentiles
	
	/// The 2.5th percentile - value below which 2.5% of observations fall
	public let p025: Double
	
	/// The 5th percentile - value below which 5% of observations fall
	public let p5: Double

	/// The 10th percentile - value below which 10% of observations fall
	public let p10: Double

	/// The 25th percentile (first quartile, Q1) - value below which 25% of observations fall
	public let p25: Double

	/// The 50th percentile (median, Q2) - value below which 50% of observations fall
	public let p50: Double

	/// The 75th percentile (third quartile, Q3) - value below which 75% of observations fall
	public let p75: Double

	/// The 90th percentile - value below which 90% of observations fall
	public let p90: Double

	/// The 95th percentile - value below which 95% of observations fall
	public let p95: Double

	/// The 97.5th percentile - value below which 97.5% of observations fall
	public let p975: Double

	/// The 99th percentile - value below which 99% of observations fall
	public let p99: Double

	

	// MARK: - Sorted Data

	/// The sorted dataset (stored for custom percentile calculations)
	private let sortedValues: [Double]

	// MARK: - Computed Properties

	/// The interquartile range (IQR) = Q3 - Q1 = p75 - p25
	///
	/// IQR measures the spread of the middle 50% of the data and is robust to outliers.
	public let interquartileRange: Double
	
	// R-7 quantile helper (same method your tests already assume)
	private static func quantileR7(_ sorted: [Double], _ p: Double) -> Double {
			let n = sorted.count
			if n == 1 { return sorted[0] }
			// Clamp p to [0, 1] to avoid crashing in edge calls; adjust if you prefer throwing
			let pp = Double.minimum(Double.maximum(p, 0.0), 1.0)
			let pos = pp * Double(n - 1)
			let lo = Int(floor(pos))
			let hi = Int(ceil(pos))
			if lo == hi { return sorted[lo] }
			let w = pos - Double(lo)
			return sorted[lo] + w * (sorted[hi] - sorted[lo])
	}

	// MARK: - Initialization

	/// Creates a Percentiles struct from an array of values.
	///
	/// The values are sorted internally, and all standard percentiles are calculated.
	///
	/// - Parameter values: An array of values to compute percentiles from
	///
	/// ## Example
	///
	/// ```swift
	/// let data = [10.0, 20.0, 30.0, 40.0, 50.0]
	/// let percentiles = Percentiles(values: data)
	/// print("Median: \(percentiles.p50)")  // 30.0
	/// ```
	public init(values: [Double]) throws {
					guard !values.isEmpty else {
						throw BusinessMathError.insufficientData(
							required: 1,
							actual: 0,
							context: "Percentiles calculation requires at least one value"
						)
					}
					guard values.allSatisfy({ $0.isFinite }) else {
						throw BusinessMathError.dataQuality(
							message: "All values must be finite (not NaN or infinite)",
							context: ["invalid_count": "\(values.filter { !$0.isFinite }.count)"]
						)
					}

					self.values = values
					let sorted = values.sorted()
					self.sortedValues = sorted
					self.min = sorted.first!
					self.max = sorted.last!

					// Precompute commonly used percentiles
					self.p025 = Self.quantileR7(sorted, 0.025)
					self.p5  = Self.quantileR7(sorted, 0.05)
					self.p10 = Self.quantileR7(sorted, 0.10)
					self.p25 = Self.quantileR7(sorted, 0.25)
					self.p50 = Self.quantileR7(sorted, 0.50)
					self.p75 = Self.quantileR7(sorted, 0.75)
					self.p90 = Self.quantileR7(sorted, 0.90)
					self.p95 = Self.quantileR7(sorted, 0.95)
					self.p975 = Self.quantileR7(sorted, 0.975)
					self.p99 = Self.quantileR7(sorted, 0.99)

					self.interquartileRange = self.p75 - self.p25
			}

	// MARK: - Custom Percentile Calculation

	/// Calculates a custom percentile from the dataset.
	///
	/// - Parameter p: The percentile to calculate (0.0 to 1.0, e.g., 0.95 for 95th percentile)
	/// - Returns: The value at the specified percentile
	///
	/// ## Example
	///
	/// ```swift
	/// let percentiles = Percentiles(values: data)
	/// let p85 = percentiles.percentile(0.85)  // 85th percentile
	/// ```
	public func percentile(_ p: Double) -> Double {
		return Self.calculatePercentile(sortedValues: sortedValues, percentile: p)
	}

	// MARK: - Internal Percentile Calculation

	/// Calculates a percentile using linear interpolation.
	///
	/// Uses the linear interpolation method (R-7 in R, Type 7 in NumPy),
	/// which is the default in many statistical packages.
	///
	/// - Parameters:
	///   - sortedValues: A sorted array of values
	///   - percentile: The percentile to calculate (0.0 to 1.0)
	/// - Returns: The interpolated percentile value
	private static func calculatePercentile(sortedValues: [Double], percentile: Double) -> Double {
		guard !sortedValues.isEmpty else { return 0.0 }

		// Handle edge cases
		if sortedValues.count == 1 {
			return sortedValues[0]
		}

		if percentile <= 0.0 {
			return sortedValues.first!
		}

		if percentile >= 1.0 {
			return sortedValues.last!
		}

		// Linear interpolation (R-7 / Type 7 method)
		// Position = (n - 1) * percentile
		let n = Double(sortedValues.count)
		let position = (n - 1.0) * percentile

		let lowerIndex = Int(Foundation.floor(position))
		let upperIndex = Int(Foundation.ceil(position))

		// Ensure indices are within bounds
		let safeLowerIndex = Swift.max(0, Swift.min(lowerIndex, sortedValues.count - 1))
		let safeUpperIndex = Swift.max(0, Swift.min(upperIndex, sortedValues.count - 1))

		// If position is exactly on an index, return that value
		if safeLowerIndex == safeUpperIndex {
			return sortedValues[safeLowerIndex]
		}

		// Linear interpolation between two values
		let lowerValue = sortedValues[safeLowerIndex]
		let upperValue = sortedValues[safeUpperIndex]
		let fraction = position - Double(lowerIndex)

		return lowerValue + fraction * (upperValue - lowerValue)
	}
}
