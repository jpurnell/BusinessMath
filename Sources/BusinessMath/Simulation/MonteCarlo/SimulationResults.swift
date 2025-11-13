//
//  SimulationResults.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
import OSLog

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
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.SimulationResults", category: #function)
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
//		logger.debug("Set values with \(values.count) values")
		let simStats = SimulationStatistics(values: values)
//		logger.debug("simStats set with \(simStats.values.count) values, mean of \(simStats.mean)")
		self.statistics = simStats
		
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
		return empiricalComplementaryCDF(threshold, data: values)
	}

	/// Calculates the probability that a randomly sampled outcome is below the threshold.
	///
	/// Returns the proportion of simulation values that are strictly less than the threshold.
	/// Uses the empirical CDF.
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
		// Note: We want strictly less than (<), but empiricalCDF uses ≤
		// So we need to subtract the exact matches
		let cdfValue = empiricalCDF(threshold, data: values)
		let exactMatches = values.filter { $0 == threshold }.count
		let proportionExact = Double(exactMatches) / Double(values.count)
		return cdfValue - proportionExact
	}

	/// Calculates the probability that a randomly sampled outcome falls within the range.
	///
	/// Returns the proportion of simulation values that are strictly between lower and upper bounds.
	/// The method handles reversed arguments (e.g., `probabilityBetween(100, 50)` works the same as `probabilityBetween(50, 100)`).
	/// Uses the empirical probability between function.
	///
	/// - Parameters:
	///   - lower: The lower bound (exclusive)
	///   - upper: The upper bound (exclusive)
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
		return empiricalProbabilityBetween(lower, upper, data: values)
	}

	// MARK: - Histogram Generation

	/// Generates a histogram of simulation results for visualization.
	///
	/// Divides the range of values into equal-width bins and counts how many values fall into each bin.
	/// Useful for creating charts and understanding the distribution shape.
	///
	/// When `bins` is not specified, automatically calculates the optimal number of bins using
	/// the maximum of Sturges' Rule and the Freedman-Diaconis rule (matching Matplotlib/Seaborn behavior).
	///
	/// - Parameter bins: The number of bins to create (must be > 0). If nil, automatically calculates optimal bin count.
	/// - Returns: An array of tuples containing the range and count for each bin
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(values: simulationOutputs)
	///
	/// // Automatic bin calculation (recommended)
	/// let histogram = results.histogram()
	///
	/// // Or specify exact number of bins
	/// let histogram20 = results.histogram(bins: 20)
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
	public func histogram(bins: Int? = nil) -> [(range: Range<Double>, count: Int)] {
		guard !values.isEmpty else { return [] }

		// Calculate optimal bin count if not specified
		let binCount: Int
		if let bins = bins {
			guard bins > 0 else { return [] }
			binCount = bins
		} else {
			binCount = calculateOptimalBins()
		}

		let minValue = statistics.min
		let maxValue = statistics.max

		// Handle case where all values are the same
		if minValue == maxValue {
			return [(range: minValue..<(minValue + 1.0), count: values.count)]
		}

		// Calculate bin width
		let range = maxValue - minValue
		let binWidth = range / Double(binCount)

		// Create bins
		var histogram: [(range: Range<Double>, count: Int)] = []

		for i in 0..<binCount {
			let lowerBound = minValue + Double(i) * binWidth
			let upperBound = (i == binCount - 1) ? maxValue + 0.0001 : minValue + Double(i + 1) * binWidth

			let binRange = lowerBound..<upperBound

			// Count values in this bin
			let count = values.filter { $0 >= binRange.lowerBound && $0 < binRange.upperBound }.count

			histogram.append((range: binRange, count: count))
		}

		return histogram
	}

	/// Calculates the optimal number of bins for histogram generation.
	///
	/// Uses the maximum of two methods (matching Matplotlib/Seaborn behavior):
	/// - **Sturges' Rule**: `ceil(log2(n) + 1)` - Works well for normally distributed data
	/// - **Freedman-Diaconis Rule**: `2 × IQR / n^(1/3)` - Robust to outliers
	///
	/// The maximum is taken to ensure adequate resolution for visualizing the distribution.
	///
	/// - Returns: The optimal number of bins (minimum of 1, maximum of 1000)
	///
	/// ## Algorithm Details
	///
	/// **Sturges' Rule**:
	/// - Based on information theory
	/// - Assumes roughly normal distribution
	/// - Formula: `ceil(log2(n) + 1)`
	///
	/// **Freedman-Diaconis Rule**:
	/// - Uses interquartile range (IQR = Q3 - Q1)
	/// - More robust to outliers than Sturges
	/// - Formula: bin_width = `2 × IQR / n^(1/3)`, bins = `ceil(range / bin_width)`
	private func calculateOptimalBins() -> Int {
		let n = Double(values.count)

		// Sturges' Rule: ceil(log2(n) + 1)
		let sturgesBins = Int(ceil(log2(n) + 1.0))

		// Freedman-Diaconis Rule: 2 × IQR / n^(1/3)
		let iqr = percentiles.interquartileRange
		let binWidth = 2.0 * iqr / pow(n, 1.0 / 3.0)

		let fdBins: Int
		if binWidth > 0 {
			let range = statistics.max - statistics.min
			fdBins = Int(ceil(range / binWidth))
		} else {
			// If IQR is 0 (all values in middle 50% are the same), fall back to Sturges
			fdBins = sturgesBins
		}

		// Use maximum of the two methods (like Matplotlib/Seaborn)
		let optimalBins = max(sturgesBins, fdBins)

		// Clamp between reasonable bounds
		return max(1, min(optimalBins, 1000))
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
	public func confidenceInterval(level: Double) -> (low: Double, high: Double) {
		return statistics.confidenceInterval(level: level)
	}
}
