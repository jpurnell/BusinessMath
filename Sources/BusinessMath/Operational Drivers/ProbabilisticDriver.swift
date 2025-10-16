//
//  ProbabilisticDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver that produces values sampled from a probability distribution.
///
/// `ProbabilisticDriver` represents business variables with inherent uncertainty.
/// Each time the driver is sampled, it generates a new random value from the
/// underlying distribution, enabling Monte Carlo simulation of financial projections.
///
/// ## Creating Probabilistic Drivers
///
/// ```swift
/// // Normally distributed sales volume
/// let sales = ProbabilisticDriver(
///     name: "Units Sold",
///     distribution: DistributionNormal(mean: 1000.0, stdDev: 100.0)
/// )
///
/// // Triangularly distributed price
/// let price = ProbabilisticDriver(
///     name: "Unit Price",
///     distribution: DistributionTriangular(low: 95.0, high: 105.0, base: 100.0)
/// )
///
/// // Uniformly distributed costs
/// let cost = ProbabilisticDriver(
///     name: "Unit Cost",
///     distribution: DistributionUniform(45.0, 55.0)
/// )
/// ```
///
/// ## Supported Distributions
///
/// Any distribution conforming to the `Distribution` protocol:
/// - **Normal**: `DistributionNormal(mean, stdDev)`
/// - **Triangular**: `DistributionTriangular(low, high, base)`
/// - **Uniform**: `DistributionUniform(min, max)`
/// - **Beta**: `DistributionBeta(alpha, beta)`
/// - **Weibull**: `DistributionWeibull(shape, scale)`
/// - **Exponential**: `DistributionExponential(lambda)`
/// - **Gamma**: `DistributionGamma(shape, scale)`
/// - And more...
///
/// ## Monte Carlo Projection
///
/// ```swift
/// let salesDriver = ProbabilisticDriver(
///     name: "Sales",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
///
/// let periods = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: salesDriver, periods: periods)
///
/// // Run 10,000 iterations
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Analyze uncertainty
/// let q1Stats = results.statistics[periods[0]]!
/// print("Q1 Expected: \(q1Stats.mean)")
/// print("Q1 Std Dev: \(q1Stats.stdDev)")
/// print("Q1 Range: [\(results.percentiles[periods[0]]!.p5), \(results.percentiles[periods[0]]!.p95)]")
/// ```
///
/// ## Combining Probabilistic Drivers
///
/// ```swift
/// // Revenue with uncertainty in both quantity and price
/// let quantity = ProbabilisticDriver(
///     name: "Quantity",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
/// let price = ProbabilisticDriver(
///     name: "Price",
///     distribution: DistributionTriangular(low: 95.0, high: 105.0, base: 100.0)
/// )
/// let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
///
/// // Each Monte Carlo iteration samples new quantity AND price values
/// ```
///
/// ## Use Cases
///
/// - **Sales Forecasting**: Uncertain demand, market conditions
/// - **Pricing**: Market volatility, competitive pressure
/// - **Costs**: Variable input costs, efficiency variations
/// - **Capacity**: Production variability, downtime
/// - **Customer Metrics**: Churn rates, conversion rates
/// - **Risk Analysis**: Range of possible outcomes
///
/// ## Important Notes
///
/// - Each call to `sample(for:)` generates a **new random value**
/// - The same period can produce different values on different samples
/// - This enables Monte Carlo simulation with proper uncertainty propagation
/// - For correlated variables across periods, see time series modeling approaches
public struct ProbabilisticDriver<T>: Driver, Sendable where T: Real, T: BinaryFloatingPoint, T: Sendable {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The underlying distribution from which values are sampled.
	private let sampleFunction: @Sendable () -> Double

	// MARK: - Initialization

	/// Creates a probabilistic driver that samples from the given distribution.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - distribution: The probability distribution to sample from.
	///
	/// ## Example
	/// ```swift
	/// let driver = ProbabilisticDriver(
	///     name: "Sales Volume",
	///     distribution: DistributionNormal(mean: 1000.0, stdDev: 100.0)
	/// )
	/// ```
	public init<D: DistributionRandom & Sendable>(name: String, distribution: D) where D.T == Double {
		self.name = name
		self.sampleFunction = { distribution.next() }
	}

	// MARK: - Driver Protocol

	/// Generates a random sample from the underlying distribution.
	///
	/// Each call produces a new random value, even for the same period.
	/// This behavior is essential for Monte Carlo simulation.
	///
	/// - Parameter period: The time period (currently not used for distribution sampling).
	/// - Returns: A random sample from the distribution.
	///
	/// ## Example
	/// ```swift
	/// let driver = ProbabilisticDriver(
	///     name: "Sales",
	///     distribution: DistributionNormal(1000.0, 100.0)
	/// )
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// let sample1 = driver.sample(for: q1)  // e.g., 1023.5
	/// let sample2 = driver.sample(for: q1)  // e.g., 987.3 (different!)
	/// ```
	public func sample(for period: Period) -> T {
		let doubleValue = sampleFunction()
		return T(doubleValue)
	}
}

// MARK: - Convenience Initializers

extension ProbabilisticDriver {
	/// Creates a probabilistic driver with a normal distribution.
	///
	/// This is a convenience initializer for the most common case.
	///
	/// - Parameters:
	///   - name: The name of this driver.
	///   - mean: The mean (expected value) of the distribution.
	///   - stdDev: The standard deviation (measure of uncertainty).
	///
	/// ## Example
	/// ```swift
	/// let sales = ProbabilisticDriver.normal(
	///     name: "Sales Volume",
	///     mean: 1000.0,
	///     stdDev: 100.0
	/// )
	/// ```
	public static func normal(name: String, mean: Double, stdDev: Double) -> ProbabilisticDriver<T> {
		return ProbabilisticDriver(
			name: name,
			distribution: DistributionNormal(mean, stdDev)
		)
	}

	/// Creates a probabilistic driver with a triangular distribution.
	///
	/// Triangular distributions are useful when you know the minimum, maximum,
	/// and most likely value.
	///
	/// - Parameters:
	///   - name: The name of this driver.
	///   - low: The minimum possible value.
	///   - high: The maximum possible value.
	///   - base: The most likely value (mode).
	///
	/// ## Example
	/// ```swift
	/// let price = ProbabilisticDriver.triangular(
	///     name: "Unit Price",
	///     low: 95.0,
	///     high: 105.0,
	///     base: 100.0
	/// )
	/// ```
	public static func triangular(name: String, low: Double, high: Double, base: Double) -> ProbabilisticDriver<T> {
		return ProbabilisticDriver(
			name: name,
			distribution: DistributionTriangular(low: low, high: high, base: base)
		)
	}

	/// Creates a probabilistic driver with a uniform distribution.
	///
	/// Uniform distributions assign equal probability to all values in a range.
	///
	/// - Parameters:
	///   - name: The name of this driver.
	///   - min: The minimum value.
	///   - max: The maximum value.
	///
	/// ## Example
	/// ```swift
	/// let cost = ProbabilisticDriver.uniform(
	///     name: "Unit Cost",
	///     min: 45.0,
	///     max: 55.0
	/// )
	/// ```
	public static func uniform(name: String, min: Double, max: Double) -> ProbabilisticDriver<T> {
		return ProbabilisticDriver(
			name: name,
			distribution: DistributionUniform(min, max)
		)
	}
}
