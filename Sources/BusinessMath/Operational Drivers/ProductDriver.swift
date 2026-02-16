//
//  ProductDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver that multiplies two other drivers.
///
/// `ProductDriver` represents the product of two drivers, enabling modeling of
/// business metrics that result from multiplication, such as:
/// - **Revenue** = Quantity × Price
/// - **Total Cost** = Units × Unit Cost
/// - **Labor Cost** = Headcount × Salary
/// - **Capacity** = Hours × Efficiency Rate
///
/// ## Creating Product Drivers
///
/// ```swift
/// // Revenue = Quantity × Price
/// let quantity = ProbabilisticDriver(
///     name: "Units Sold",
///     distribution: DistributionNormal(1000.0, 100.0)
/// )
/// let price = ProbabilisticDriver(
///     name: "Price per Unit",
///     distribution: DistributionTriangular(low: 95.0, high: 105.0, base: 100.0)
/// )
/// let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
/// ```
///
/// ## Uncertainty Propagation
///
/// When both drivers are probabilistic, their uncertainties combine:
///
/// ```swift
/// // Both drivers have uncertainty
/// let quantity = ProbabilisticDriver.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
/// let price = ProbabilisticDriver.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
/// let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
///
/// // Expected value ≈ E[Quantity] × E[Price] = 1000 × 100 = 100,000
/// // But variance is higher than if either were fixed
/// ```
///
/// ## Mixed Deterministic and Probabilistic
///
/// ```swift
/// // Fixed price × uncertain volume
/// let price = DeterministicDriver(name: "Price", value: 100.0)
/// let volume = ProbabilisticDriver.normal(name: "Volume", mean: 1000.0, stdDev: 100.0)
/// let revenue = ProductDriver(name: "Revenue", lhs: price, rhs: volume)
///
/// // Uncertainty comes only from volume
/// // E[Revenue] = 100 × 1000 = 100,000
/// // StdDev[Revenue] = 100 × 100 = 10,000 (scales linearly with fixed multiplier)
/// ```
///
/// ## Chaining Operations
///
/// ```swift
/// // Total Cost = (Variable Cost per Unit × Units) + Fixed Costs
/// let variableCostPerUnit = DeterministicDriver(name: "Variable Cost/Unit", value: 50.0)
/// let units = ProbabilisticDriver.normal(name: "Units", mean: 1000.0, stdDev: 100.0)
/// let variableCost = ProductDriver(name: "Variable Cost", lhs: variableCostPerUnit, rhs: units)
///
/// let fixedCost = DeterministicDriver(name: "Fixed Cost", value: 10_000.0)
/// let totalCost = SumDriver(name: "Total Cost", lhs: variableCost, rhs: fixedCost)
/// ```
///
/// ## Use Cases
///
/// - **Revenue Models**: Volume × Price, Customers × ARPU
/// - **Cost Models**: Units × Unit Cost, Headcount × Salary
/// - **Capacity Models**: Hours × Utilization Rate
/// - **Compound Growth**: Principal × (1 + Rate)
/// - **Market Share**: Total Market × Share Percentage
public struct ProductDriver<T: Real & Sendable>: Driver, Sendable {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The left-hand side driver.
	private let lhs: AnyDriver<T>

	/// The right-hand side driver.
	private let rhs: AnyDriver<T>

	// MARK: - Initialization

	/// Creates a product driver that multiplies two drivers.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - lhs: The left-hand side driver.
	///   - rhs: The right-hand side driver.
	///
	/// ## Example
	/// ```swift
	/// let quantity = ProbabilisticDriver.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
	/// let price = DeterministicDriver(name: "Price", value: 100.0)
	/// let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
	/// ```
	public init<L: Driver, R: Driver>(name: String, lhs: L, rhs: R) where L.Value == T, R.Value == T {
		self.name = name
		self.lhs = AnyDriver(lhs)
		self.rhs = AnyDriver(rhs)
	}

	// MARK: - Driver Protocol

	/// Generates a sample by multiplying samples from both drivers.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: The product of the two driver samples.
	///
	/// ## Example
	/// ```swift
	/// let quantity = DeterministicDriver(name: "Qty", value: 100.0)
	/// let price = DeterministicDriver(name: "Price", value: 10.0)
	/// let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// let sample = revenue.sample(for: q1)  // 100.0 × 10.0 = 1000.0
	/// ```
	public func sample(for period: Period) -> T {
		return lhs.sample(for: period) * rhs.sample(for: period)
	}
}

// MARK: - Convenience Operators

extension Driver {
	/// Multiplies this driver by another driver.
	///
	/// Creates a `ProductDriver` that computes the product of both drivers.
	///
	/// - Parameters:
	///   - lhs: The driver to multiply.
	///   - rhs: The driver to multiply with.
	/// - Returns: A new product driver.
	///
	/// ## Example
	/// ```swift
	/// let quantity = ProbabilisticDriver.normal(name: "Qty", mean: 1000.0, stdDev: 100.0)
	/// let price = DeterministicDriver(name: "Price", value: 100.0)
	/// let revenue = quantity * price  // Creates ProductDriver
	/// ```
	public static func * <R: Driver>(lhs: Self, rhs: R) -> ProductDriver<Value> where R.Value == Value {
		return ProductDriver(name: "\(lhs.name) × \(rhs.name)", lhs: lhs, rhs: rhs)
	}
}
