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
/// let sales = ProbabilisticDriver<Double>(
///     name: "Units Sold",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
///
/// // Triangularly distributed price
/// let price = ProbabilisticDriver<Double>(
///     name: "Unit Price",
///     distribution: DistributionTriangular(low: 95.0, high: 105.0, base: 100.0)
/// )
///
/// // Uniformly distributed costs
/// let cost = ProbabilisticDriver<Double>(
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
/// let quarters = Period.documentationQuarters
/// let salesDriver = ProbabilisticDriver<Double>(
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
/// let values = [100.0, 110.0, 120.0, 130.0]
/// // Revenue with uncertainty in both quantity and price
/// let quantity = ProbabilisticDriver<Double>(
///     name: "Quantity",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
/// let price = ProbabilisticDriver<Double>(
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

	/// The seeded sampling function, when the underlying distribution supports one.
	///
	/// Non-`nil` only when the driver was built from a distribution conforming to
	/// ``SeedableDistribution``; drawing through it sources every uniform from the
	/// caller's generator, so a seeded ``Xoshiro256StarStar`` reproduces the identical
	/// stream. `nil` for distributions that own their randomness, which is what makes
	/// ``supportsSeeding`` a run-time question rather than a type-level one.
	private let seededSampleFunction: (@Sendable (inout Xoshiro256StarStar) -> Double)?

	// MARK: - Initialization

	/// Creates a probabilistic driver that samples from the given distribution.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - distribution: The probability distribution to sample from.
	///
	/// ## Example
	/// ```swift
	/// let driver = ProbabilisticDriver<Double>(
	///     name: "Sales Volume",
	///     distribution: DistributionNormal(1000.0, 100.0)
	/// )
	/// ```
	public init<D: DistributionRandom & Sendable>(name: String, distribution: D) where D.T == Double {
		self.name = name
		self.sampleFunction = { distribution.next() }
		// Only the SeedableDistribution overload can honor a seed
		self.seededSampleFunction = nil
	}

	/// Creates a probabilistic driver over a distribution that supports seeded sampling.
	///
	/// Swift prefers this overload whenever the concrete distribution conforms to
	/// ``SeedableDistribution``, capturing a seeded sampler alongside the ordinary one so
	/// the driver can take part in reproducible runs through ``SeedableDriver``. Callers
	/// write the same call either way — the built-in distributions all conform, so the
	/// convenience initializers ``normal(name:mean:stdDev:)``,
	/// ``triangular(name:low:high:base:)`` and ``uniform(name:min:max:)`` land here.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - distribution: The probability distribution to sample from.
	///
	/// ## Example
	/// ```swift
	/// let driver = ProbabilisticDriver<Double>(
	///     name: "Sales Volume",
	///     distribution: DistributionNormal(1000.0, 100.0)
	/// )
	/// assert(driver.supportsSeeding)
	/// ```
	public init<D: SeedableDistribution & Sendable>(name: String, distribution: D) where D.T == Double {
		self.name = name
		self.sampleFunction = { distribution.next() }
		// Seeded sampling: every draw flows from the caller's generator
		self.seededSampleFunction = { generator in distribution.next(using: &generator) }
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
	/// let driver = ProbabilisticDriver<Double>(
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

// MARK: - Seeded Sampling

extension ProbabilisticDriver: SeedableDriver {
	/// Whether this driver's distribution can source its randomness from a caller's generator.
	///
	/// `true` when the driver was built over a ``SeedableDistribution`` — which every
	/// built-in distribution and every convenience initializer here is. `false` for a
	/// distribution that conforms only to ``DistributionRandom`` and therefore owns its
	/// own randomness.
	public var supportsSeeding: Bool { seededSampleFunction != nil }

	/// Generates a sample drawn entirely from `generator`.
	///
	/// The same seed reproduces the same sequence; a different seed does not. The draw
	/// follows the identical probability law as ``sample(for:)`` — only the randomness
	/// source differs.
	///
	/// - Parameters:
	///   - period: The time period (not used for distribution sampling; a probabilistic
	///     driver is time-invariant).
	///   - generator: The random source.
	/// - Returns: A random sample from the distribution.
	/// - Throws: `SimulationError.seedingUnsupported` when the underlying distribution does
	///   not conform to ``SeedableDistribution``, rather than silently returning a draw the
	///   caller's generator did not produce.
	///
	/// ## Example
	/// ```swift
	/// let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	///
	/// var generator = Xoshiro256StarStar(seed: 42)
	/// let first = try driver.sample(for: q1, using: &generator)
	///
	/// var replay = Xoshiro256StarStar(seed: 42)
	/// let again = try driver.sample(for: q1, using: &replay)  // identical to `first`
	/// ```
	public func sample(for period: Period, using generator: inout Xoshiro256StarStar) throws -> T {
		guard let seededSampleFunction else {
			throw SimulationError.seedingUnsupported(
				inputName: name,
				details: "Driver uses a distribution that does not conform to SeedableDistribution"
			)
		}
		return T(seededSampleFunction(&generator))
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
	/// let sales = ProbabilisticDriver<Double>.normal(
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
	/// let price = ProbabilisticDriver<Double>.triangular(
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
	/// let cost = ProbabilisticDriver<Double>.uniform(
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
