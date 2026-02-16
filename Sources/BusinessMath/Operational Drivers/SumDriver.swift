//
//  SumDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver that adds two other drivers.
///
/// `SumDriver` represents the sum of two drivers, enabling modeling of
/// business metrics that result from addition, such as:
/// - **Total Revenue** = Product A Revenue + Product B Revenue
/// - **Total Cost** = Fixed Costs + Variable Costs
/// - **Profit** = Revenue - Cost (using subtraction operator)
/// - **Cash Flow** = Operating Cash + Investing Cash + Financing Cash
///
/// ## Creating Sum Drivers
///
/// ```swift
/// // Total Cost = Fixed Costs + Variable Costs
/// let fixedCosts = DeterministicDriver(name: "Fixed Costs", value: 10_000.0)
/// let variableCosts = ProbabilisticDriver.normal(
///     name: "Variable Costs",
///     mean: 50_000.0,
///     stdDev: 5_000.0
/// )
/// let totalCost = SumDriver(name: "Total Cost", lhs: fixedCosts, rhs: variableCosts)
/// ```
///
/// ## Uncertainty Propagation
///
/// When both drivers are probabilistic, their uncertainties combine:
///
/// ```swift
/// // Both drivers have uncertainty
/// let revenueA = ProbabilisticDriver.normal(name: "Revenue A", mean: 100_000.0, stdDev: 10_000.0)
/// let revenueB = ProbabilisticDriver.normal(name: "Revenue B", mean: 80_000.0, stdDev: 8_000.0)
/// let totalRevenue = SumDriver(name: "Total Revenue", lhs: revenueA, rhs: revenueB)
///
/// // Expected value: E[A] + E[B] = 100,000 + 80,000 = 180,000
/// // If independent: Var[A+B] = Var[A] + Var[B]
/// // StdDev[A+B] = sqrt(10,000² + 8,000²) ≈ 12,806
/// ```
///
/// ## Profit Calculation (Revenue - Cost)
///
/// ```swift
/// // Profit = Revenue - Cost
/// let revenue = ProbabilisticDriver.normal(name: "Revenue", mean: 100_000.0, stdDev: 10_000.0)
/// let cost = ProbabilisticDriver.normal(name: "Cost", mean: 70_000.0, stdDev: 7_000.0)
/// let profit = revenue - cost  // Uses convenience operator
///
/// // Expected profit: 100,000 - 70,000 = 30,000
/// // If independent: StdDev ≈ sqrt(10,000² + 7,000²) ≈ 12,207
/// ```
///
/// ## Building Complex Formulas
///
/// ```swift
/// // Total Cost = (Variable Cost per Unit × Units) + Fixed Costs
/// let variableCostPerUnit = DeterministicDriver(name: "Variable Cost/Unit", value: 50.0)
/// let units = ProbabilisticDriver.normal(name: "Units", mean: 1000.0, stdDev: 100.0)
/// let variableCosts = ProductDriver(name: "Variable Costs", lhs: variableCostPerUnit, rhs: units)
/// let fixedCosts = DeterministicDriver(name: "Fixed Costs", value: 10_000.0)
/// let totalCost = SumDriver(name: "Total Cost", lhs: variableCosts, rhs: fixedCosts)
///
/// // Or using operators:
/// let totalCost2 = (variableCostPerUnit * units) + fixedCosts
/// ```
///
/// ## Use Cases
///
/// - **Aggregating Revenue**: Multiple product lines, regions, customers
/// - **Total Costs**: Fixed + Variable, Direct + Indirect
/// - **Profit Margins**: Revenue - Cost
/// - **Cash Flow Components**: Operating + Investing + Financing
/// - **Composite Metrics**: Multiple additive factors
public struct SumDriver<T: Real & Sendable>: Driver, Sendable {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The left-hand side driver.
	private let lhs: AnyDriver<T>

	/// The right-hand side driver.
	private let rhs: AnyDriver<T>

	// MARK: - Initialization

	/// Creates a sum driver that adds two drivers.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - lhs: The left-hand side driver.
	///   - rhs: The right-hand side driver.
	///
	/// ## Example
	/// ```swift
	/// let fixedCost = DeterministicDriver(name: "Fixed", value: 10_000.0)
	/// let variableCost = ProbabilisticDriver.normal(name: "Variable", mean: 50_000.0, stdDev: 5_000.0)
	/// let totalCost = SumDriver(name: "Total Cost", lhs: fixedCost, rhs: variableCost)
	/// ```
	public init<L: Driver, R: Driver>(name: String, lhs: L, rhs: R) where L.Value == T, R.Value == T {
		self.name = name
		self.lhs = AnyDriver(lhs)
		self.rhs = AnyDriver(rhs)
	}

	// MARK: - Driver Protocol

	/// Generates a sample by adding samples from both drivers.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: The sum of the two driver samples.
	///
	/// ## Example
	/// ```swift
	/// let fixed = DeterministicDriver(name: "Fixed", value: 10_000.0)
	/// let variable = DeterministicDriver(name: "Variable", value: 5_000.0)
	/// let total = SumDriver(name: "Total", lhs: fixed, rhs: variable)
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// let sample = total.sample(for: q1)  // 10_000 + 5_000 = 15_000
	/// ```
	public func sample(for period: Period) -> T {
		return lhs.sample(for: period) + rhs.sample(for: period)
	}
}

// MARK: - Convenience Operators

extension Driver {
	/// Adds this driver to another driver.
	///
	/// Creates a `SumDriver` that computes the sum of both drivers.
	///
	/// - Parameters:
	///  - lhs: The driver to add to
	///  - rhs: The driver to add.
	/// - Returns: A new sum driver.
	///
	/// ## Example
	/// ```swift
	/// let revenueA = ProbabilisticDriver.normal(name: "Revenue A", mean: 100_000.0, stdDev: 10_000.0)
	/// let revenueB = ProbabilisticDriver.normal(name: "Revenue B", mean: 80_000.0, stdDev: 8_000.0)
	/// let totalRevenue = revenueA + revenueB  // Creates SumDriver
	/// ```
	public static func + <R: Driver>(lhs: Self, rhs: R) -> SumDriver<Value> where R.Value == Value {
		return SumDriver(name: "\(lhs.name) + \(rhs.name)", lhs: lhs, rhs: rhs)
	}

	/// Subtracts another driver from this driver.
	///
	/// Creates a `SumDriver` where the right-hand side is negated.
	///
	/// - Parameters:
	///   - lhs: The driver to subtract from
	///   - rhs: The driver to subtract.
	/// - Returns: A new sum driver representing the difference.
	///
	/// ## Example
	/// ```swift
	/// let revenue = ProbabilisticDriver.normal(name: "Revenue", mean: 100_000.0, stdDev: 10_000.0)
	/// let cost = ProbabilisticDriver.normal(name: "Cost", mean: 70_000.0, stdDev: 7_000.0)
	/// let profit = revenue - cost  // Creates SumDriver with negated cost
	/// ```
	public static func - <R: Driver>(lhs: Self, rhs: R) -> SumDriver<Value> where R.Value == Value {
		let negatedRhs = ScalarDriver(name: "-\(rhs.name)") { period in
			-rhs.sample(for: period)
		}
		return SumDriver(name: "\(lhs.name) - \(rhs.name)", lhs: lhs, rhs: negatedRhs)
	}
}

// MARK: - Helper: ScalarDriver

/// A driver that applies a custom transformation.
///
/// This is an internal helper used by operators like subtraction.
private struct ScalarDriver<T: Real & Sendable>: Driver, Sendable {
	let name: String
	private let transform: @Sendable (Period) -> T

	init(name: String, transform: @escaping @Sendable (Period) -> T) {
		self.name = name
		self.transform = transform
	}

	func sample(for period: Period) -> T {
		return transform(period)
	}
}
