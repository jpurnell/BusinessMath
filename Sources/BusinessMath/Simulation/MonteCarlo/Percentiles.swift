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
/// Every value here comes from ``quantile(sorted:p:)``, the library's single
/// empirical quantile: linear interpolation between order statistics (type 7,
/// the default in R and NumPy).
///
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
	/// The sample from which the percentile statistics are derived, in the order it was supplied.
	///
	/// - Important: This array is **not** sorted, despite what earlier
	///   documentation claimed. Do not hand it to ``quantile(sorted:p:)``,
	///   which assumes ascending order and does not check. Use
	///   ``percentile(_:)`` instead, or sort first.
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
	/// let percentiles = try Percentiles(values: data)
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
					// Safe: guard above ensures at least one element
					self.min = sorted[0]
					self.max = sorted[sorted.count - 1]

					// Precompute commonly used percentiles
					self.p025 = quantile(sorted: sorted, p: 0.025)
					self.p5  = quantile(sorted: sorted, p: 0.05)
					self.p10 = quantile(sorted: sorted, p: 0.10)
					self.p25 = quantile(sorted: sorted, p: 0.25)
					self.p50 = quantile(sorted: sorted, p: 0.50)
					self.p75 = quantile(sorted: sorted, p: 0.75)
					self.p90 = quantile(sorted: sorted, p: 0.90)
					self.p95 = quantile(sorted: sorted, p: 0.95)
					self.p975 = quantile(sorted: sorted, p: 0.975)
					self.p99 = quantile(sorted: sorted, p: 0.99)

					self.interquartileRange = self.p75 - self.p25
			}

	// MARK: - Custom Percentile Calculation

	/// Calculates a custom percentile from the dataset.
	///
	/// Delegates to ``quantile(sorted:p:)``; see there for the interpolation
	/// rule and the behaviour of `p` outside `[0, 1]`.
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
		return quantile(sorted: sortedValues, p: p)
	}

}
