//
//  SimulationStatistics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
import OSLog
// Private aliases to global statistics functions to avoid namespace conflicts
// These are explicitly typed for Double to resolve generic parameters
// Marked nonisolated(unsafe) since these are pure functions with no mutable state
private nonisolated(unsafe) let globalMean: ([Double]) -> Double = mean
private nonisolated(unsafe) let globalMedian: ([Double]) -> Double = median
private nonisolated(unsafe) let globalVariance: ([Double], Population) -> Double = variance
private nonisolated(unsafe) let globalStdDev: ([Double], Population) -> Double = stdDev
private nonisolated(unsafe) let globalSkew: ([Double], Population) -> Double = skew
private nonisolated(unsafe) let globalConfidenceInterval: (Double, [Double]) -> (low: Double, high: Double) = confidenceInterval(ci:values:)

/// A structure containing comprehensive statistical measures for simulation results.
///
/// SimulationStatistics provides a complete statistical summary including measures of
/// central tendency, dispersion, shape, and confidence intervals. This is essential
/// for interpreting Monte Carlo simulation outcomes.
///
/// ## Statistical Measures
///
/// - **Central Tendency**: mean, median
/// - **Dispersion**: standard deviation, variance, min, max
/// - **Shape**: skewness (measure of asymmetry)
/// - **Confidence Intervals**: 90%, 95%, 99% confidence bounds
///
/// ## Skewness Interpretation
///
/// - Skewness > 0: Right-skewed (long tail on right, most values on left)
/// - Skewness = 0: Symmetric (normal distribution)
/// - Skewness < 0: Left-skewed (long tail on left, most values on right)
///
/// ## Example
///
/// ```swift
/// // Generate 10,000 simulation results
/// let simulationResults = (0..<10_000).map { _ in
///     distributionNormal(mean: 100.0, stdDev: 15.0)
/// }
///
/// let stats = SimulationStatistics(values: simulationResults)
///
/// print("Mean: \(stats.mean)")
/// print("StdDev: \(stats.stdDev)")
/// print("Skewness: \(stats.skewness)")
/// print("95% CI: [\(stats.ci95.lower), \(stats.ci95.upper)]")
/// ```
public struct SimulationStatistics: Sendable {

	// MARK: - Raw Data

	/// The original values used to calculate these statistics
	///
	/// Stored for potential additional calculations or analysis
	public let values: [Double]

	// MARK: - Central Tendency

	/// The arithmetic mean (average) of all values
	public let mean: Double

	/// The median (50th percentile) - the middle value when sorted
	public let median: Double

	// MARK: - Dispersion

	/// The sample standard deviation - measure of spread around the mean
	public let stdDev: Double

	/// The sample variance - squared standard deviation
	public let variance: Double

	/// The minimum value in the dataset
	public let min: Double

	/// The maximum value in the dataset
	public let max: Double

	// MARK: - Shape

	/// The skewness - measure of distribution asymmetry
	///
	/// - Positive: Right-skewed (tail extends right)
	/// - Zero: Symmetric
	/// - Negative: Left-skewed (tail extends left)
	public let skewness: Double

	// MARK: - Convenience Properties

	/// 90% confidence interval (mean ± 1.645 × stdDev)
	public var ci90: (low: Double, high: Double) { return globalConfidenceInterval(0.90, values) }

	/// 95% confidence interval (mean ± 1.96 × stdDev)
	public var ci95: (low: Double, high: Double) { return globalConfidenceInterval(0.95, values) }

	/// 99% confidence interval (mean ± 2.576 × stdDev)
	public var ci99: (low: Double, high: Double) { return globalConfidenceInterval(0.99, values) }

	// MARK: - Initialization

	/// Creates a SimulationStatistics struct from an array of values.
	///
	/// Calculates all statistical measures from the provided dataset.
	///
	/// - Parameter values: An array of simulation results
	///
	/// ## Example
	///
	/// ```swift
	/// let results = [10.0, 20.0, 30.0, 40.0, 50.0]
	/// let stats = SimulationStatistics(values: results)
	/// print("Mean: \(stats.mean)")  // 30.0
	/// ```
	public init(values: [Double]) {
		// Handle empty array
		guard !values.isEmpty else {
			self.values = []
			self.mean = 0.0
			self.median = 0.0
			self.stdDev = 0.0
			self.variance = 0.0
			self.min = 0.0
			self.max = 0.0
			self.skewness = 0.0
			return
		}

		// Store the original values for future calculations
		self.values = values

		// Calculate all statistics using helper method to avoid namespace conflicts
		let stats = Self.calculateStatistics(from: values)

		// Assign all properties
		self.mean = stats.mean
		self.median = stats.median
		self.min = stats.min
		self.max = stats.max
		self.variance = stats.variance
		self.stdDev = stats.stdDev
		self.skewness = stats.skewness
	}

	/// Helper method to calculate statistics using library functions
	/// - Parameter values: Array of Double values
	/// - Returns: Tuple containing all calculated statistics
	private static func calculateStatistics(from values: [Double]) -> (mean: Double, median: Double, min: Double, max: Double, variance: Double, stdDev: Double, skewness: Double) {
		// Calculate min and max
		let minValue = values.min() ?? 0.0
		let maxValue = values.max() ?? 0.0

		// Calculate mean using library function (via file-level alias)
		let meanValue = globalMean(values)

		// Calculate median using library function (requires sorted data)
		let sortedValues = values.sorted()
		let medianValue = globalMedian(sortedValues)

		// Calculate variance and standard deviation using library functions
		let varianceValue: Double
		let stdDevValue: Double
		if values.count > 1 {
			varianceValue = globalVariance(values, .sample)
			stdDevValue = globalStdDev(values, .sample)
		} else {
			varianceValue = 0.0
			stdDevValue = 0.0
		}

		// Calculate skewness using library function
		let skewnessValue = globalSkew(values, .sample)

		return (meanValue, medianValue, minValue, maxValue, varianceValue, stdDevValue, skewnessValue)
	}

	// MARK: - Confidence Intervals

	/// Calculates a confidence interval at the specified level.
	///
	/// Uses the library's global confidenceInterval function which employs
	/// inverse normal CDF for more accurate confidence interval calculation.
	///
	/// - Parameter level: The confidence level (0.0 to 1.0, e.g., 0.95 for 95%)
	/// - Returns: A tuple containing the lower and upper bounds of the confidence interval
	///
	/// ## Common Levels
	///
	/// - 0.90 (90%): z = 1.645
	/// - 0.95 (95%): z = 1.96
	/// - 0.99 (99%): z = 2.576
	///
	/// ## Example
	///
	/// ```swift
	/// let ci = stats.confidenceInterval(level: 0.95)
	/// print("95% CI: [\(ci.lower), \(ci.upper)]")
	/// ```


	public func confidenceInterval(level: Double) -> (low: Double, high: Double) { return globalConfidenceInterval(level, values) }

}
