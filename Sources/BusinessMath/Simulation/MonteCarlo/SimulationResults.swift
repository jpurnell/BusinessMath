//
//  SimulationResults.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
#if canImport(OSLog)
import OSLog
#endif

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
/// let simulation = try FinancialSimulation.documentationFixture
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
	// LIVE: diagnostics logger for simulation result processing
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.SimulationResults", category: #function)
	// MARK: - Properties

	/// All simulation output values
	public let values: [Double]

	/// Computed statistics for the simulation results
	public let statistics: SimulationStatistics

	/// Computed percentiles for the simulation results
	public let percentiles: Percentiles

	/// Whether the simulation was executed on GPU
	///
	/// - `true`: Simulation used GPU acceleration (Metal)
	/// - `false`: Simulation used CPU execution
	public let usedGPU: Bool

	/// Notes describing any execution anomalies or degraded conditions
	///
	/// When a simulation encounters issues (e.g., GPU failure requiring CPU fallback),
	/// the details are recorded here rather than being silently discarded. This follows
	/// the fail-silent principle: never return plausible-but-wrong results without
	/// annotating the degradation.
	///
	/// An empty array indicates nominal execution with no anomalies.
	///
	/// ## Example
	///
	/// ```swift
	/// let results = SimulationResults(
	///     values: [102.0, 98.0, 105.0, 97.0, 101.0],
	///     usedGPU: false,
	///     executionNotes: ["GPU unavailable — fell back to CPU"]
	/// )
	/// if results.isDegraded {
	///     print("Execution notes:")
	///     for note in results.executionNotes {
	///         print("  - \(note)")
	///     }
	/// }
	/// ```
	public let executionNotes: [String]

	/// Whether the simulation results were produced under degraded conditions
	///
	/// Returns `true` when any execution notes are present, indicating that
	/// the simulation encountered anomalies during execution (e.g., GPU fallback,
	/// precision changes).
	public var isDegraded: Bool { !executionNotes.isEmpty }

	// MARK: - Initialization

	/// Creates a SimulationResults struct from an array of simulation output values.
	///
	/// The initializer automatically computes:
	/// - Complete statistical summary (mean, median, standard deviation, etc.)
	/// - Percentiles (p5, p10, p25, p50, p75, p90, p95, p99)
	///
	/// - Parameters:
	///   - values: An array of simulation output values
	///   - usedGPU: Whether GPU acceleration was used (default: false)
	///   - executionNotes: Notes describing execution anomalies (default: empty)
	///
	/// ## Example
	///
	/// ```swift
	/// let simulation = try FinancialSimulation.documentationFixture
	/// let simulationOutputs = (0..<10_000).map { _ in
	///     // Your simulation model
	///     distributionNormal(mean: 100, stdDev: 15)
	/// }
	///
	/// let results = SimulationResults(values: simulationOutputs, usedGPU: true)
	/// ```
	public init(values: [Double], usedGPU: Bool = false, executionNotes: [String] = []) {
		self.values = values
		self.usedGPU = usedGPU
		self.executionNotes = executionNotes
//		logger.debug("Set values with \(values.count) values")
		let simStats = SimulationStatistics(values: values)
//		logger.debug("simStats set with \(simStats.values.count) values, mean of \(simStats.mean)")
		self.statistics = simStats
		// `Percentiles(values:)` throws for an empty sample and for any non-finite value. The
		// fallback used to rebuild from the literal `[0]`, which reported every percentile,
		// the range and the interquartile range as exactly zero — measured: a run containing
		// one `nan` gave p5 = p95 = iqr = 0.0 while `valueAtRisk` on the same object
		// correctly gave `nan`. One result answering two ways about one sample.
		//
		// The note that used to sit here ("Percentiles([0]) should never fail — non-empty,
		// finite") explains how: it was written against the *empty* case, and the finiteness
		// refusal added later falls into the same catch.
		do {
			self.percentiles = try Percentiles(values: values)
		} catch { // logging: sample is empty or non-finite — percentiles are undefined, not zero
			self.percentiles = .undefined(values: values)
		}
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
	/// let profitValues = [420_000.0, 510_000.0, 485_000.0, -35_000.0, 560_000.0]
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
	/// let profitValues = [420_000.0, 510_000.0, 485_000.0, -35_000.0, 560_000.0]
	/// let results = SimulationResults(values: profitValues)
	///
	/// // What's the probability of a loss (profit < 0)?
	/// let probLoss = results.probabilityBelow(0.0)
	/// print("Risk of loss: \(probLoss * 100)%")
	/// ```
	public func probabilityBelow(_ threshold: Double) -> Double {
		guard !values.isEmpty else { return 0.0 }
		// Direct count avoids floating-point error from subtraction
		let countBelow = values.filter { $0 < threshold }.count
		return Double(countBelow) / Double(values.count)
	}

	/// Generate a formatted risk analysis summary with probability calculations at key thresholds.
	///
	/// Creates a human-readable text summary showing the probability of outcomes relative to important
	/// thresholds. If no thresholds are provided, automatically selects meaningful percentiles including
	/// zero (for loss probability) and quartiles.
	///
	/// This is particularly useful for presenting simulation results to stakeholders who need to
	/// understand downside risks and upside potential without viewing raw statistical tables.
	///
	/// - Parameter thresholds: Array of threshold values to analyze. If empty, uses default thresholds:
	///   `[0, p5, p25, p50, p75, p95]`. Thresholds can be in any order.
	///
	/// - Returns: A formatted string with one line per threshold showing:
	///   - Descriptive label (e.g., "Probability of loss" for threshold 0)
	///   - Whether analyzing above (≥) or below (<) the threshold (based on median)
	///   - Probability as a percentage
	///
	/// ## Usage Example
	///
	/// ```swift
	/// let simulation = try FinancialSimulation.documentationFixture
	/// // Run profit simulation
	/// var profitValues: [Double] = []
	/// for _ in 0..<10_000 {
	///     let revenue = distributionNormal(mean: 1_000_000, stdDev: 150_000)
	///     let costs = distributionNormal(mean: 700_000, stdDev: 80_000)
	///     profitValues.append(revenue - costs)
	/// }
	///
	/// let results = SimulationResults(values: profitValues)
	///
	/// // Default thresholds (0, p5, p25, p50, p75, p95)
	/// print(results.riskAnalysis())
	/// // Output:
	/// //   Probability of loss 2.1%
	/// //   Probability profit < 53.7k 5.0%
	/// //   Probability profit < 230.4k 25.0%
	/// //   Probability profit < 301.2k 50.0%
	/// //   Probability profit >= 372.8k 25.0%
	/// //   Probability profit >= 548.3k 5.0%
	///
	/// // Custom thresholds (e.g., business targets)
	/// let analysis = results.riskAnalysis([
	///     0,           // Break-even
	///     200_000,     // Minimum acceptable profit
	///     400_000,     // Target profit
	///     600_000      // Stretch goal
	/// ])
	/// print(analysis)
	/// // Output:
	/// //   Probability of loss 2.1%
	/// //   Probability profit < 200.0k 18.3%
	/// //   Probability profit >= 400.0k 31.7%
	/// //   Probability profit >= 600.0k 8.9%
	/// ```
	///
	/// ## Automatic Threshold Selection
	///
	/// When `thresholds` is empty, uses these defaults:
	/// - **0**: Shows probability of loss (negative outcome)
	/// - **p5, p95**: 90% confidence interval bounds
	/// - **p25, p75**: Interquartile range (middle 50%)
	/// - **p50**: Median (50th percentile)
	///
	/// ## Output Format Details
	///
	/// - **Threshold labels**: Formatted in thousands (k) with appropriate precision
	/// - **Direction**: Automatically chooses "≥" or "<" based on whether threshold is above/below median
	/// - **Percentages**: Displayed with one decimal place (e.g., "15.7%")
	/// - **Special case**: Threshold 0 always labeled as "Probability of loss"
	///
	/// ## Interpretation Guide
	///
	/// | Threshold | Probability | Interpretation |
	/// |-----------|-------------|----------------|
	/// | 0 | 5.0% | 5% chance of loss (negative profit) |
	/// | p5 | 5.0% | 5% chance of being below this pessimistic scenario |
	/// | p50 | 50.0% | 50% chance of exceeding median outcome |
	/// | p95 | 5.0% | 5% chance of exceeding this optimistic scenario |
	///
	/// - Note: For thresholds below the median, shows probability BELOW threshold (downside risk).
	///   For thresholds above median, shows probability ABOVE threshold (upside potential).
	///
	/// - Important: Probabilities are empirical (based on simulation samples), not parametric.
	///   Accuracy improves with more samples (10,000+ recommended for 1% precision).
	///
	/// - SeeAlso:
	///   - ``probabilityAbove(_:)``
	///   - ``probabilityBelow(_:)``
	///   - ``percentiles``
	///   - ``formattedDescription``
	public func riskAnalysis(_ thresholds: [Double] = []) -> String {
		var returnString = ""
		var comparisonThresholds: [Double] = []
		if thresholds.isEmpty {
			comparisonThresholds = [0, self.percentiles.p5, self.percentiles.p25, self.percentiles.p50, self.percentiles.p75, self.percentiles.p95]
		} else {
			comparisonThresholds = thresholds
		}
		for (_, threshold) in comparisonThresholds.enumerated() {
			let desc: String
			switch threshold {
				case 0: desc = "Probability of loss"
				default: desc = "Probability profit \(threshold >= self.percentiles.p50 ? ">=" : "<") \((threshold / 1000).currency(0))k"
			}
			returnString += "  \(desc) \(threshold > self.percentiles.p50 ? (self.probabilityAbove(threshold)).percent() : (self.probabilityBelow(threshold)).percent())\n"
		}
		return returnString
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
	/// let projectDurationDays = [28.0, 34.0, 41.0, 47.0, 38.0]
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
	/// let simulationOutputs = [102.0, 98.0, 105.0, 97.0, 101.0, 99.0, 103.0]
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
		let binWidth = range / Double(binCount) // fp-safety:disable — binCount is a parameter >= 1

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
		// Unreachable through `histogram(bins:)`, whose `!values.isEmpty` guard runs first and
		// is this function's only caller. Kept so Sturges' conversion is total on its own
		// terms rather than by relying on that ordering — `log2(0)` is `-infinity`,
		// `ceil(-infinity + 1)` is `-infinity`, and `Int(_:)` on a `Double` **traps** there, so
		// a second caller added later would not get a wrong bin count, it would take the
		// process down. One is the floor this function already applies at its last line and
		// already documents ("minimum of 1"), so returning it here changes no answer that was
		// reachable before.
		guard !values.isEmpty else { return 1 }
		let n = Double(values.count)

		// Sturges' Rule: ceil(log2(n) + 1)
		let sturgesBins = Int(ceil(log2(n) + 1.0))

		// Freedman-Diaconis Rule: 2 × IQR / n^(1/3)
		let iqr = percentiles.interquartileRange
		let binWidth = 2.0 * iqr / pow(n, 1.0 / 3.0)

		let fdBins: Int
		if binWidth > 0 {
			let range = statistics.max - statistics.min
			let requestedBins = ceil(range / binWidth)
			// Freedman-Diaconis divides the full range by a width derived from the
			// *interquartile* core, so a heavy tail over a tight core asks for a bin count far
			// beyond `Int` — no infinity and no contamination needed, just a fat-tailed sample.
			// `Int(_:)` on a `Double` traps on anything outside `Int`'s range, so the request
			// has to be bounded in `Double`, before the conversion. Without this the caller
			// would have been told nothing at all: the process dies inside `histogram()`.
			//
			// The ceiling is `maximumBinCount`, which is the bound this function already
			// applies three lines below and already documents ("maximum of 1000"). Bounding
			// early therefore changes no answer that was reachable before — it only stops the
			// arithmetic that produced the same capped answer from being fatal on the way.
			fdBins = requestedBins.isFinite
				? Int(Swift.min(Swift.max(requestedBins, 1), Double(Self.maximumBinCount)))
				: Self.maximumBinCount
		} else {
			// If IQR is 0 (all values in middle 50% are the same), fall back to Sturges
			fdBins = sturgesBins
		}

		// Use maximum of the two methods (like Matplotlib/Seaborn)
		let optimalBins = max(sturgesBins, fdBins)

		// Clamp between reasonable bounds
		return max(1, min(optimalBins, Self.maximumBinCount))
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
	/// let revenueValues = [1_020_000.0, 980_000.0, 1_050_000.0, 995_000.0]
	/// let results = SimulationResults(values: revenueValues)
	///
	/// let ci95 = results.confidenceInterval(level: 0.95)
	/// print("95% confidence interval: [\(ci95.low), \(ci95.high)]")
	/// print("We expect the true mean to be in this range")
	/// ```
	public func confidenceInterval(level: Double) -> (low: Double, high: Double) {
		return statistics.confidenceInterval(level: level)
	}

	// MARK: - Formatting

	/// Formatter used for displaying results (mutable for customization)
	public var formatter: FloatingPointFormatter = .optimization

	/// Formatted statistics summary with clean floating-point display
	public var formattedStatistics: String {
		var stats = statistics
		stats.formatter = formatter
		return stats.formattedDescription
	}

	/// Formatted percentiles summary with clean floating-point display
	public var formattedPercentiles: String {
		let length = Self.percentileColumnWidth(p5: percentiles.p5, p99: percentiles.p99)
		var desc = "Percentiles:\n"
		desc += "   P5: \(percentiles.p5.number(1).paddingLeft(toLength: length))\n"
		desc += "  P10: \(percentiles.p10.number(1).paddingLeft(toLength: length))\n"
		desc += "  P25: \(percentiles.p25.number(1).paddingLeft(toLength: length))\n"
		desc += "  P50: \(percentiles.p50.number(1).paddingLeft(toLength: length)) – (Median)\n"
		desc += "  P75: \(percentiles.p75.number(1).paddingLeft(toLength: length))\n"
		desc += "  P90: \(percentiles.p90.number(1).paddingLeft(toLength: length))\n"
		desc += "  P95: \(percentiles.p95.number(1).paddingLeft(toLength: length))\n"
		desc += "  P99: \(percentiles.p99.number(1).paddingLeft(toLength: length))"
		return desc
	}

	/// Formatted probability above threshold with clean floating-point display
	///
	/// - Parameter threshold: The value to compare against
	/// - Returns: Formatted probability string
	public func formattedProbabilityAbove(_ threshold: Double) -> String {
		let prob = probabilityAbove(threshold)
		return formatter.format(prob).formatted
	}

	/// Formatted probability below threshold with clean floating-point display
	///
	/// - Parameter threshold: The value to compare against
	/// - Returns: Formatted probability string
	public func formattedProbabilityBelow(_ threshold: Double) -> String {
		let prob = probabilityBelow(threshold)
		return formatter.format(prob).formatted
	}

	/// Formatted probability between thresholds with clean floating-point display
	///
	/// - Parameters:
	///   - lower: The lower bound
	///   - upper: The upper bound
	/// - Returns: Formatted probability string
	public func formattedProbabilityBetween(_ lower: Double, _ upper: Double) -> String {
		let prob = probabilityBetween(lower, upper)
		return formatter.format(prob).formatted
	}

	/// Formatted description showing complete simulation results
	public var formattedDescription: String {
		var desc = "Simulation Results (\(values.count) samples):\n\n"
		desc += formattedStatistics
		desc += "\n\n"
		desc += formattedPercentiles
		return desc
	}

	// MARK: - Display scale

	/// The largest automatic histogram bin count.
	///
	/// Declared once so the Freedman-Diaconis bound and the final clamp cannot drift apart;
	/// the value is the one ``histogram(bins:)`` has always documented.
	private static let maximumBinCount: Int = 1000

	/// The characters reserved for the sign, decimal separator and one decimal digit in the
	/// percentile table, on top of the integer digits.
	private static let percentileColumnPadding: Int = 7

	/// The column width used to right-align the percentile table.
	///
	/// ## Why this is not `Int(max(log10(p5), log10(p99)).rounded(.up)) + 7`
	///
	/// That expression was fatal for two entirely legitimate, finite samples, because `log10`
	/// manufactures non-finite values out of ordinary data and `Int(_:)` on a `Double` traps
	/// on them:
	///
	/// - an all-zero sample gives `log10(0) = -infinity`;
	/// - **any loss distribution** gives `log10(negative) = nan` — and negative percentiles are
	///   the *normal* shape for a risk simulation, not an edge case.
	///
	/// A third route needs no arithmetic at all: a sample that `Percentiles(values:)` refuses
	/// leaves ``percentiles`` as `.undefined(values:)`, whose fields are `nan` by design.
	///
	/// In every case the caller would otherwise have been told nothing whatsoever — the
	/// process died while *printing* a result it had already computed correctly. A column
	/// width is a display decision and must never be fatal.
	///
	/// A negative width is fatal one step later, too: `paddingLeft(toLength:)` forwards to
	/// `suffix(_:)`, which traps on a negative count. Flooring at
	/// `percentileColumnPadding` rules that out as well.
	///
	/// Taking magnitudes rather than the raw values also *widens* what can be measured: the
	/// old form compared `log10(p5)` with `log10(p99)` directly, which is only equivalent to
	/// "the wider of the two" while both are positive.
	///
	/// - Parameters:
	///   - p5: The 5th-percentile value.
	///   - p99: The 99th-percentile value.
	/// - Returns: A width wide enough for the larger magnitude, never less than
	///   `percentileColumnPadding`. Positive, finite samples get the same width they
	///   always did.
	private static func percentileColumnWidth(p5: Double, p99: Double) -> Int {
		let scale = Swift.max(p5.magnitude, p99.magnitude)
		// `scale == 0` is the all-zero sample; a non-finite `scale` is a `nan` or infinite
		// percentile. Both degrade to the bare padding rather than to a trap.
		guard scale.isFinite, scale > 0 else { return percentileColumnPadding }
		// `scale` is finite and positive here, so `log10(scale)` lies within about
		// ±324 and the conversion below is total.
		let integerDigits = log10(scale).rounded(.up)
		let digits = Int(Swift.max(integerDigits, 0))
		return digits + percentileColumnPadding
	}
}
