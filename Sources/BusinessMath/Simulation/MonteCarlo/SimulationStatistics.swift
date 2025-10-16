//
//  SimulationStatistics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

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
	public var ci90: (lower: Double, upper: Double) {
		return confidenceInterval(level: 0.90)
	}

	/// 95% confidence interval (mean ± 1.96 × stdDev)
	public var ci95: (lower: Double, upper: Double) {
		return confidenceInterval(level: 0.95)
	}

	/// 99% confidence interval (mean ± 2.576 × stdDev)
	public var ci99: (lower: Double, upper: Double) {
		return confidenceInterval(level: 0.99)
	}

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
			self.mean = 0.0
			self.median = 0.0
			self.stdDev = 0.0
			self.variance = 0.0
			self.min = 0.0
			self.max = 0.0
			self.skewness = 0.0
			return
		}

		// Calculate min and max
		let minValue = values.min() ?? 0.0
		let maxValue = values.max() ?? 0.0

		// Calculate mean
		let sum = values.reduce(0.0, +)
		let meanValue = sum / Double(values.count)

		// Calculate median (requires sorted data)
		let sortedValues = values.sorted()
		let medianValue: Double
		if sortedValues.count % 2 == 0 {
			let midIndex1 = sortedValues.count / 2 - 1
			let midIndex2 = sortedValues.count / 2
			medianValue = (sortedValues[midIndex1] + sortedValues[midIndex2]) / 2.0
		} else {
			let midIndex = sortedValues.count / 2
			medianValue = sortedValues[midIndex]
		}

		// Calculate variance and standard deviation
		let (varianceValue, stdDevValue): (Double, Double)
		if values.count > 1 {
			// Sample variance: sum((x - mean)^2) / (n - 1)
			let squaredDeviations = values.map { pow($0 - meanValue, 2) }
			varianceValue = squaredDeviations.reduce(0.0, +) / Double(values.count - 1)
			stdDevValue = sqrt(varianceValue)
		} else {
			varianceValue = 0.0
			stdDevValue = 0.0
		}

		// Calculate skewness
		let skewnessValue = Self.calculateSkewness(values: values, mean: meanValue, stdDev: stdDevValue)

		// Assign all properties
		self.mean = meanValue
		self.median = medianValue
		self.min = minValue
		self.max = maxValue
		self.variance = varianceValue
		self.stdDev = stdDevValue
		self.skewness = skewnessValue
	}

	// MARK: - Confidence Intervals

	/// Calculates a confidence interval at the specified level.
	///
	/// Uses the normal approximation: CI = mean ± z × stdDev
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
	public func confidenceInterval(level: Double) -> (lower: Double, upper: Double) {
		// Get z-score for confidence level
		let zScore = Self.zScoreForConfidenceLevel(level)

		// Calculate margin of error
		let marginOfError = zScore * stdDev

		return (lower: mean - marginOfError, upper: mean + marginOfError)
	}

	// MARK: - Internal Calculations

	/// Returns the z-score for a given confidence level.
	///
	/// - Parameter level: The confidence level (e.g., 0.95 for 95%)
	/// - Returns: The corresponding z-score
	private static func zScoreForConfidenceLevel(_ level: Double) -> Double {
		// Common z-scores for confidence intervals
		switch level {
		case 0.90:
			return 1.645
		case 0.95:
			return 1.96
		case 0.99:
			return 2.576
		case 0.999:
			return 3.291
		default:
			// For other levels, use approximation
			// This is a simplified approach; could use inverse normal CDF for precision
			if level >= 0.90 && level < 0.95 {
				// Linear interpolation between 90% and 95%
				let fraction = (level - 0.90) / (0.95 - 0.90)
				return 1.645 + fraction * (1.96 - 1.645)
			} else if level >= 0.95 && level < 0.99 {
				// Linear interpolation between 95% and 99%
				let fraction = (level - 0.95) / (0.99 - 0.95)
				return 1.96 + fraction * (2.576 - 1.96)
			} else if level >= 0.99 && level <= 1.0 {
				// Linear interpolation between 99% and 99.9%
				let fraction = (level - 0.99) / (0.999 - 0.99)
				return 2.576 + fraction * (3.291 - 2.576)
			} else {
				// Default to 95%
				return 1.96
			}
		}
	}

	/// Calculates the skewness of a dataset.
	///
	/// Skewness measures the asymmetry of the probability distribution.
	/// Uses the sample skewness formula (adjusted Fisher-Pearson coefficient).
	///
	/// Formula: skewness = (n / ((n-1)(n-2))) × Σ((x - mean) / stdDev)³
	///
	/// - Parameters:
	///   - values: The dataset
	///   - mean: The mean of the dataset
	///   - stdDev: The standard deviation of the dataset
	/// - Returns: The skewness value
	private static func calculateSkewness(values: [Double], mean: Double, stdDev: Double) -> Double {
		guard values.count > 2 else { return 0.0 }
		guard stdDev > 0.0 else { return 0.0 }

		let n = Double(values.count)

		// Calculate the sum of cubed standardized deviations
		let sumCubedDeviations = values.reduce(0.0) { sum, value in
			let standardizedDeviation = (value - mean) / stdDev
			return sum + pow(standardizedDeviation, 3)
		}

		// Apply bias correction factor for sample skewness
		let biasCorrectionFactor = n / ((n - 1.0) * (n - 2.0))

		return biasCorrectionFactor * sumCubedDeviations
	}
}
