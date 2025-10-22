//
//  SimulationResults.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A structure containing the complete results of a Monte Carlo simulation.
///
/// SimulationResults provides comprehensive access to simulation outcomes including:
/// - Raw simulation values
/// - Computed statistics (mean, median, standard deviation, etc.)
/// - Percentiles (p5, p10, p25, p50, p75, p90, p95, p99)
/// - Probability calculations (probability above/below/between thresholds)
/// - Histogram generation for visualization
/// - Confidence intervals
///
/// ## Use Cases
///
/// - Financial modeling: Analyzing profit/loss distributions
/// - Risk analysis: Calculating probability of adverse outcomes
/// - Project management: Estimating completion time ranges
/// - Operations: Understanding throughput variability
///
/// ## Example
///
/// ```swift
/// // Run a simple revenue simulation
/// var revenueValues: [Double] = []
/// for _ in 0..<10_000 {
///     let revenue = distributionNormal(mean: 1_000_000, stdDev: 100_000)
///     revenueValues.append(revenue)
/// }
///
/// let results = SimulationResults(values: revenueValues)
///
/// // Analyze results
/// print("Mean revenue: \(results.statistics.mean)")
/// print("95% confidence: [\(results.percentiles.p5), \(results.percentiles.p95)]")
/// print("Probability of revenue > $1.2M: \(results.probabilityAbove(1_200_000))")
///
/// // Generate and plot histogram for visualization
/// let histogram = results.histogram(bins: 20)
/// let plot = plotHistogram(histogram)
/// print(plot)
/// ```
public struct SimulationResults: Sendable {

	// MARK: - Properties

	/// All simulation output values
	public let values: [Double]

	/// Computed statistics for the simulation results
	public let statistics: SimulationStatistics

	/// Computed percentiles for the simulation results
	public let percentiles: Percentiles

	// MARK: - Initialization

	/// Creates a SimulationResults struct from an array of simulation output values.
	///
	/// The initializer automatically computes:
	/// - Complete statistical summary (mean, median, standard deviation, etc.)
	/// - Percentiles (p5, p10, p25, p50, p75, p90, p95, p99)
	///
	/// - Parameter values: An array of simulation output values
	///
	/// ## Example
	///
	/// ```swift
	/// let simulationOutputs = (0..<10_000).map { _ in
	///     // Your simulation model
	///     distributionNormal(mean: 100, stdDev: 15)
	/// }
	///
	/// let results = SimulationResults(values: simulationOutputs)
	/// ```
	public init(values: [Double]) {
		self.values = values
		self.statistics = SimulationStatistics(values: values)
		self.percentiles = Percentiles(values: values)
	}

	// MARK: - Probability Calculations

	/// Calculates the probability that a randomly sampled outcome exceeds the threshold.
	///
	/// Returns the proportion of simulation values that are strictly greater than the threshold.
	///
	/// - Parameter threshold: The value to compare against
	/// - Returns: Probability (0.0 to 1.0) that outcome > threshold
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: profitValues)
	///
	/// // What's the probability of profit exceeding $500k?
	/// let probHighProfit = results.probabilityAbove(500_000)
	/// print("Probability of profit > $500k: \(probHighProfit * 100)%")
	/// ```
	public func probabilityAbove(_ threshold: Double) -> Double {
		let countAbove = values.filter { $0 > threshold }.count
		return Double(countAbove) / Double(values.count)
	}

	/// Calculates the probability that a randomly sampled outcome is below the threshold.
	///
	/// Returns the proportion of simulation values that are strictly less than the threshold.
	///
	/// - Parameter threshold: The value to compare against
	/// - Returns: Probability (0.0 to 1.0) that outcome < threshold
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: profitValues)
	///
	/// // What's the probability of a loss (profit < 0)?
	/// let probLoss = results.probabilityBelow(0.0)
	/// print("Risk of loss: \(probLoss * 100)%")
	/// ```
	public func probabilityBelow(_ threshold: Double) -> Double {
		let countBelow = values.filter { $0 < threshold }.count
		return Double(countBelow) / Double(values.count)
	}

	/// Calculates the probability that a randomly sampled outcome falls within the range.
	///
	/// Returns the proportion of simulation values that are strictly between lower and upper bounds.
	/// The method handles reversed arguments (e.g., `probabilityBetween(100, 50)` works the same as `probabilityBetween(50, 100)`).
	///
	/// - Parameters:
	///   - lower: The lower bound (inclusive)
	///   - upper: The upper bound (inclusive)
	/// - Returns: Probability (0.0 to 1.0) that lower < outcome < upper
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: projectDurationDays)
	///
	/// // What's the probability of completing between 30-45 days?
	/// let probOnTime = results.probabilityBetween(30.0, 45.0)
	/// print("Probability of on-time completion: \(probOnTime * 100)%")
	/// ```
	public func probabilityBetween(_ lower: Double, _ upper: Double) -> Double {
		// Ensure lower <= upper
		let minBound = min(lower, upper)
		let maxBound = max(lower, upper)

		let countInRange = values.filter { $0 > minBound && $0 < maxBound }.count
		return Double(countInRange) / Double(values.count)
	}

	// MARK: - Histogram Generation

	/// Generates a histogram of simulation results for visualization.
	///
	/// Divides the range of values into equal-width bins and counts how many values fall into each bin.
	/// Useful for creating charts and understanding the distribution shape.
	///
	/// - Parameter bins: The number of bins to create (must be > 0)
	/// - Returns: An array of tuples containing the range and count for each bin
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: simulationOutputs)
	/// let histogram = results.histogram(bins: 20)
	///
	/// for (index, bin) in histogram.enumerated() {
	///     print("Bin \(index): [\(bin.range.lowerBound), \(bin.range.upperBound)): \(bin.count) values")
	/// }
	///
	/// // Visualize with command-line plot
	/// let plot = plotHistogram(histogram)
	/// print(plot)
	///
	/// // Output:
	/// // Histogram (20 bins, 10,000 samples):
	/// //
	/// // [   85.00 -    90.00):  ████████ 234 (  2.3%)
	/// // [   90.00 -    95.00):  ████████████ 456 (  4.6%)
	/// // ...
	/// ```
	public func histogram(bins: Int) -> [(range: Range<Double>, count: Int)] {
		guard bins > 0 else { return [] }
		guard !values.isEmpty else { return [] }

		let minValue = statistics.min
		let maxValue = statistics.max

		// Handle case where all values are the same
		if minValue == maxValue {
			return [(range: minValue..<(minValue + 1.0), count: values.count)]
		}

		// Calculate bin width
		let range = maxValue - minValue
		let binWidth = range / Double(bins)

		// Create bins
		var histogram: [(range: Range<Double>, count: Int)] = []

		for i in 0..<bins {
			let lowerBound = minValue + Double(i) * binWidth
			let upperBound = (i == bins - 1) ? maxValue + 0.0001 : minValue + Double(i + 1) * binWidth

			let binRange = lowerBound..<upperBound

			// Count values in this bin
			let count = values.filter { $0 >= binRange.lowerBound && $0 < binRange.upperBound }.count

			histogram.append((range: binRange, count: count))
		}

		return histogram
	}

	// MARK: - Confidence Intervals

	/// Calculates a confidence interval for the simulation results.
	///
	/// Uses the normal approximation based on the mean and standard deviation.
	/// This is equivalent to `statistics.confidenceInterval(level:)` but provided
	/// here for convenience.
	///
	/// - Parameter level: The confidence level (0.0 to 1.0, e.g., 0.95 for 95%)
	/// - Returns: A tuple containing the lower and upper bounds of the confidence interval
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: revenueValues)
	///
	/// let ci95 = results.confidenceInterval(level: 0.95)
	/// print("95% confidence interval: [\(ci95.lower), \(ci95.upper)]")
	/// print("We expect the true mean to be in this range")
	/// ```
	public func confidenceInterval(level: Double) -> (lower: Double, upper: Double) {
		return statistics.confidenceInterval(level: level)
	}
}
