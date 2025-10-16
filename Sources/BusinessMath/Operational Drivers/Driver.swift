//
//  Driver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver represents a business variable that produces values over time.
///
/// Drivers are the building blocks of financial projection models. They represent
/// operational variables like sales volume, pricing, costs, or any metric that
/// drives financial outcomes. Drivers can be deterministic (fixed values) or
/// probabilistic (uncertainty modeled via distributions).
///
/// ## Types of Drivers
///
/// - **Deterministic**: Fixed values (e.g., annual rent = $120,000)
/// - **Probabilistic**: Values sampled from distributions (e.g., sales ~ Normal(1000, 100))
/// - **Composite**: Combinations of other drivers (e.g., revenue = quantity × price)
///
/// ## Creating Drivers
///
/// ```swift
/// // Fixed value
/// let rent = DeterministicDriver(name: "Rent", value: 120_000.0)
///
/// // Uncertain value
/// let sales = ProbabilisticDriver(
///     name: "Units Sold",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
///
/// // Composite driver
/// let revenue = ProductDriver(name: "Revenue", lhs: sales, rhs: price)
/// ```
///
/// ## Projecting Over Time
///
/// ```swift
/// let periods = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: revenue, periods: periods)
///
/// // Deterministic projection (single path)
/// let expectedRevenue = projection.project()
///
/// // Probabilistic projection (Monte Carlo)
/// let results = projection.projectMonteCarlo(iterations: 10_000)
/// let meanRevenue = results.expected()
/// let p95Revenue = results.percentile(0.95)
/// ```
///
/// ## Implementation Notes
///
/// The `Driver` protocol is the foundation for all operational drivers. Each concrete
/// driver type implements the `sample(for:)` method, which generates a value for a
/// specific period. This allows drivers to be:
/// - Time-invariant (same value every period)
/// - Time-varying (different values per period)
/// - Stochastic (different values on each sample)
///
/// ## Topics
///
/// ### Core Drivers
/// - ``DeterministicDriver``
/// - ``ProbabilisticDriver``
///
/// ### Composite Drivers
/// - ``ProductDriver``
/// - ``SumDriver``
///
/// ### Projection
/// - ``DriverProjection``
/// - ``ProjectionResults``
public protocol Driver: Sendable {
	/// The numeric type produced by this driver.
	associatedtype Value: Real & Sendable

	/// The name of this driver for reporting and debugging.
	var name: String { get }

	/// Generates a single sample value for the specified period.
	///
	/// This method is called during projection to generate values for each period.
	/// For deterministic drivers, this returns the same value every time for a given period.
	/// For probabilistic drivers, this samples from the underlying distribution.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: A sampled value for the specified period.
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
	/// let sample2 = driver.sample(for: q1)  // e.g., 987.3 (different sample)
	/// ```
	func sample(for period: Period) -> Value
}

/// Type-erased wrapper for any driver.
///
/// This allows mixing different concrete driver types in collections while
/// maintaining the same value type.
///
/// ## Example
/// ```swift
/// let drivers: [AnyDriver<Double>] = [
///     AnyDriver(DeterministicDriver(name: "Fixed", value: 100.0)),
///     AnyDriver(ProbabilisticDriver(name: "Random", distribution: DistributionNormal(100.0, 10.0)))
/// ]
/// ```
public struct AnyDriver<T: Real & Sendable>: Driver, Sendable {
	public let name: String
	private let _sample: @Sendable (Period) -> T

	/// Creates a type-erased driver wrapping the given driver.
	///
	/// - Parameter driver: The driver to wrap.
	public init<D: Driver>(_ driver: D) where D.Value == T {
		self.name = driver.name
		self._sample = { period in
			driver.sample(for: period)
		}
	}

	public func sample(for period: Period) -> T {
		return _sample(period)
	}
}
