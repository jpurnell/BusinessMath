//
//  DriverProjection.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Projects a driver over multiple time periods, with optional Monte Carlo analysis.
///
/// `DriverProjection` converts a driver into time series projections. It supports both:
/// - **Deterministic projection**: Single expected path
/// - **Probabilistic projection**: Monte Carlo simulation with uncertainty quantification
///
/// ## Basic Projection
///
/// ```swift
/// let sales = ProbabilisticDriver.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
/// let periods = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: sales, periods: periods)
///
/// // Single deterministic path (one sample per period)
/// let expectedPath = projection.project()
/// ```
///
/// ## Monte Carlo Projection
///
/// ```swift
/// // Run 10,000 simulations
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Analyze uncertainty for each period
/// for period in periods {
///     let stats = results.statistics[period]!
///     let pctiles = results.percentiles[period]!
///
///     print("\(period.label):")
///     print("  Expected: \(stats.mean)")
///     print("  Std Dev: \(stats.stdDev)")
///     print("  P5-P95 Range: [\(pctiles.p5), \(pctiles.p95)]")
/// }
///
/// // Extract time series at different confidence levels
/// let expectedSeries = results.expected()  // Mean for each period
/// let medianSeries = results.percentile(0.50)  // Median
/// let p95Series = results.percentile(0.95)  // 95th percentile
/// ```
///
/// ## Revenue Example with Uncertainty
///
/// ```swift
/// // Revenue = Quantity × Price (both uncertain)
/// let quantity = ProbabilisticDriver.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
/// let price = ProbabilisticDriver.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
/// let revenue = quantity * price
///
/// let quarters = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: revenue, periods: quarters)
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Expected revenue around 1000 × 100 = 100,000 per quarter
/// // But with uncertainty from both quantity and price
/// ```
///
/// ## Use Cases
///
/// - **Revenue Forecasting**: Project uncertain sales and pricing
/// - **Cost Modeling**: Model variable and fixed costs with uncertainty
/// - **Profit Analysis**: Understand range of possible profit outcomes
/// - **Risk Assessment**: Quantify downside risk (P5, P10) and upside potential (P90, P95)
/// - **Scenario Planning**: Generate multiple possible future paths
/// - **Budget Planning**: Set realistic targets based on probability distributions
public struct DriverProjection<T: Real & Sendable>: Sendable {
	// MARK: - Properties

	/// The driver to project.
	private let driver: AnyDriver<T>

	/// The periods over which to project.
	public let periods: [Period]

	// MARK: - Initialization

	/// Creates a projection for a driver over specified periods.
	///
	/// - Parameters:
	///   - driver: The driver to project.
	///   - periods: The time periods for the projection.
	///
	/// ## Example
	/// ```swift
	/// let sales = ProbabilisticDriver.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
	/// let periods = Period.year(2025).months()
	/// let projection = DriverProjection(driver: sales, periods: periods)
	/// ```
	public init<D: Driver>(driver: D, periods: [Period]) where D.Value == T {
		self.driver = AnyDriver(driver)
		self.periods = periods
	}

	// MARK: - Deterministic Projection

	/// Projects the driver over the specified periods (single sample per period).
	///
	/// This method generates one sample from the driver for each period, creating
	/// a single time series path. For deterministic drivers, this is the exact value.
	/// For probabilistic drivers, this is one possible realization.
	///
	/// - Returns: A time series containing the projected values.
	///
	/// ## Example
	/// ```swift
	/// let projection = DriverProjection(driver: salesDriver, periods: quarters)
	/// let timeSeries = projection.project()
	/// ```
	public func project() -> TimeSeries<T> {
		var values: [T] = []
		values.reserveCapacity(periods.count)

		for period in periods {
			values.append(driver.sample(for: period))
		}

		let metadata = TimeSeriesMetadata(
			name: driver.name,
			description: "Projected \(driver.name)"
		)

		return TimeSeries(periods: periods, values: values, metadata: metadata)
	}

	// MARK: - Monte Carlo Projection

	/// Projects the driver using Monte Carlo simulation.
	///
	/// This method runs multiple iterations, sampling the driver for each period
	/// in each iteration. It returns comprehensive statistics and percentiles for
	/// each period, enabling uncertainty quantification.
	///
	/// - Parameter iterations: The number of Monte Carlo iterations to run.
	/// - Returns: Projection results containing statistics for each period.
	///
	/// ## Example
	/// ```swift
	/// let results = projection.projectMonteCarlo(iterations: 10_000)
	///
	/// // Access statistics for a specific period
	/// let q1Stats = results.statistics[periods[0]]!
	/// print("Q1 Mean: \(q1Stats.mean)")
	/// print("Q1 StdDev: \(q1Stats.stdDev)")
	///
	/// // Get time series at different confidence levels
	/// let expectedRevenue = results.expected()
	/// let worstCase = results.percentile(0.05)
	/// let bestCase = results.percentile(0.95)
	/// ```
	public func projectMonteCarlo(iterations: Int) -> ProjectionResults<T> where T: BinaryFloatingPoint {
		guard iterations > 0 else {
			fatalError("iterations must be positive")
		}

		// Store all samples: [period index][iteration]
		var allSamples: [[T]] = Array(repeating: [], count: periods.count)
		for i in 0..<periods.count {
			allSamples[i].reserveCapacity(iterations)
		}

		// Run iterations
		for _ in 0..<iterations {
			for (periodIndex, period) in periods.enumerated() {
				let sample = driver.sample(for: period)
				allSamples[periodIndex].append(sample)
			}
		}

		// Compute statistics for each period
		var statistics: [Period: SimulationStatistics] = [:]
		var percentiles: [Period: Percentiles] = [:]

		for (periodIndex, period) in periods.enumerated() {
			let samples = allSamples[periodIndex]
			// Convert to Double for SimulationResults
			let doubleSamples = samples.map { sample in
				Double(sample)
			}
			let results = SimulationResults(values: doubleSamples)
			statistics[period] = results.statistics
			percentiles[period] = results.percentiles
		}

		return ProjectionResults(
			driver: driver,
			periods: periods,
			statistics: statistics,
			percentiles: percentiles
		)
	}
}

// MARK: - ProjectionResults

/// Results from a Monte Carlo driver projection.
///
/// Contains comprehensive statistics and percentiles for each period in the projection.
///
/// ## Accessing Results
///
/// ```swift
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Statistics for specific period
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// let stats = results.statistics[q1]!
/// print("Mean: \(stats.mean), StdDev: \(stats.stdDev)")
///
/// // Extract time series
/// let expectedSeries = results.expected()  // Mean values
/// let medianSeries = results.percentile(0.50)  // Median values
/// let p95Series = results.percentile(0.95)  // 95th percentile
/// ```
public struct ProjectionResults<T: Real & Sendable>: Sendable {
	/// The driver that was projected.
	private let driver: AnyDriver<T>

	/// The periods in the projection.
	public let periods: [Period]

	/// Statistics for each period.
	public let statistics: [Period: SimulationStatistics]

	/// Percentiles for each period.
	public let percentiles: [Period: Percentiles]

	/// Creates projection results.
	///
	/// This initializer is internal - users receive `ProjectionResults` from
	/// `DriverProjection.projectMonteCarlo()`.
	internal init(
		driver: AnyDriver<T>,
		periods: [Period],
		statistics: [Period: SimulationStatistics],
		percentiles: [Period: Percentiles]
	) {
		self.driver = driver
		self.periods = periods
		self.statistics = statistics
		self.percentiles = percentiles
	}

	// MARK: - Time Series Extraction

	/// Returns the expected (mean) time series.
	///
	/// - Returns: A time series containing the mean value for each period.
	///
	/// ## Example
	/// ```swift
	/// let results = projection.projectMonteCarlo(iterations: 10_000)
	/// let expectedRevenue = results.expected()
	/// ```
	public func expected() -> TimeSeries<T> where T: BinaryFloatingPoint {
		let values = periods.map { period in
			let meanValue = statistics[period]!.mean
			return T(meanValue)
		}

		let metadata = TimeSeriesMetadata(
			name: driver.name,
			description: "Expected (Mean) \(driver.name)"
		)

		return TimeSeries(periods: periods, values: values, metadata: metadata)
	}

	/// Returns a time series at the specified percentile.
	///
	/// - Parameter p: The percentile (0.0 to 1.0).
	/// - Returns: A time series containing the percentile value for each period.
	///
	/// ## Example
	/// ```swift
	/// let medianRevenue = results.percentile(0.50)  // Median
	/// let worstCase = results.percentile(0.05)  // 5th percentile (downside risk)
	/// let bestCase = results.percentile(0.95)  // 95th percentile (upside potential)
	/// ```
	public func percentile(_ p: Double) -> TimeSeries<T> where T: BinaryFloatingPoint {
		let values = periods.map { period -> T in
			let pctiles = percentiles[period]!

			// Map percentile to closest standard percentile
			let value: Double
			if p <= 0.15 {
				value = pctiles.p5
			} else if p <= 0.375 {
				value = pctiles.p25
			} else if p <= 0.625 {
				value = pctiles.p50
			} else if p <= 0.85 {
				value = pctiles.p75
			} else {
				value = pctiles.p95
			}
			return T(value)
		}

		let metadata = TimeSeriesMetadata(
			name: driver.name,
			description: "P\(Int(p * 100)) \(driver.name)"
		)

		return TimeSeries(periods: periods, values: values, metadata: metadata)
	}

	/// Returns the median (50th percentile) time series.
	///
	/// - Returns: A time series containing the median value for each period.
	///
	/// ## Example
	/// ```swift
	/// let medianRevenue = results.median()
	/// ```
	public func median() -> TimeSeries<T> where T: BinaryFloatingPoint {
		return percentile(0.50)
	}

	/// Returns the standard deviation time series.
	///
	/// Shows how uncertainty varies across periods.
	///
	/// - Returns: A time series of standard deviations for each period.
	///
	/// ## Example
	/// ```swift
	/// let uncertainty = results.standardDeviation()
	/// // Higher values indicate more uncertain periods
	/// ```
	public func standardDeviation() -> TimeSeries<T> where T: BinaryFloatingPoint {
		let values = periods.map { period in
			let stdDevValue = statistics[period]!.stdDev
			return T(stdDevValue)
		}

		let metadata = TimeSeriesMetadata(
			name: "\(driver.name) StdDev",
			description: "Standard Deviation of \(driver.name)"
		)

		return TimeSeries(periods: periods, values: values, metadata: metadata)
	}
}
