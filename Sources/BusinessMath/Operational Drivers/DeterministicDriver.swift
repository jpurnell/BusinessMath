//
//  DeterministicDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver that produces a fixed, deterministic value.
///
/// `DeterministicDriver` represents business variables with known, constant values
/// across all periods. These are useful for modeling fixed costs, known prices,
/// guaranteed volumes, or any metric without uncertainty.
///
/// ## Creating Deterministic Drivers
///
/// ```swift
/// // Fixed annual rent
/// let rent = DeterministicDriver(name: "Annual Rent", value: 120_000.0)
///
/// // Known tax rate
/// let taxRate = DeterministicDriver(name: "Tax Rate", value: 0.21)
///
/// // Fixed headcount
/// let employees = DeterministicDriver(name: "Employees", value: 50.0)
/// ```
///
/// ## Use Cases
///
/// - **Fixed Costs**: Rent, insurance, salaries
/// - **Known Rates**: Tax rates, commission rates
/// - **Contractual Terms**: Fixed prices, guaranteed volumes
/// - **Baseline Scenarios**: Starting point before adding uncertainty
///
/// ## Projection Behavior
///
/// Deterministic drivers always return the same value for all periods and all samples:
///
/// ```swift
/// let driver = DeterministicDriver(name: "Rent", value: 10_000.0)
/// let periods = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: driver, periods: periods)
///
/// // All periods have the same value
/// let timeSeries = projection.project()
/// // Q1: 10,000, Q2: 10,000, Q3: 10,000, Q4: 10,000
///
/// // Monte Carlo shows no uncertainty (all iterations identical)
/// let results = projection.projectMonteCarlo(iterations: 1000)
/// print(results.statistics[periods[0]]?.stdDev)  // 0.0 (no variance)
/// ```
///
/// ## Combining with Other Drivers
///
/// Deterministic drivers are often combined with probabilistic ones:
///
/// ```swift
/// // Fixed price × uncertain volume
/// let price = DeterministicDriver(name: "Price", value: 100.0)
/// let volume = ProbabilisticDriver(name: "Volume", distribution: DistributionNormal(1000.0, 100.0))
/// let revenue = ProductDriver(name: "Revenue", lhs: price, rhs: volume)
/// ```
public struct DeterministicDriver<T: Real & Sendable>: Driver, Sendable {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The fixed value returned by this driver.
	private let value: T

	// MARK: - Initialization

	/// Creates a deterministic driver with a fixed value.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - value: The fixed value to return for all periods.
	///
	/// ## Example
	/// ```swift
	/// let rent = DeterministicDriver(name: "Monthly Rent", value: 10_000.0)
	/// ```
	public init(name: String, value: T) {
		self.name = name
		self.value = value
	}

	// MARK: - Driver Protocol

	/// Returns the fixed value for any period.
	///
	/// This method always returns the same value regardless of the period.
	///
	/// - Parameter period: The time period (ignored for deterministic drivers).
	/// - Returns: The fixed value.
	public func sample(for period: Period) -> T {
		return value
	}
}

// MARK: - Convenience Extensions

extension DeterministicDriver {
	/// The fixed value of this driver.
	///
	/// Provides read-only access to the underlying value.
	public var fixedValue: T {
		return value
	}
}
