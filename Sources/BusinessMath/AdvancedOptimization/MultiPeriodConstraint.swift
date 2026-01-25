//
//  MultiPeriodConstraint.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Multi-Period Constraint

/// Constraints for multi-period optimization problems.
///
/// Multi-period constraints can apply to:
/// - Individual periods (intra-temporal)
/// - Transitions between periods (inter-temporal)
/// - The entire trajectory
///
/// ## Example
/// ```swift
/// let constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
///     // Budget constraint each period: Σw = 1
///     .eachPeriod { t, x in x.sum() - 1.0 },
///
///     // Transaction cost constraint: turnover ≤ 20%
///     .transition { t, xₜ, xₜ₊₁ in
///         let turnover = (xₜ₊₁ - xₜ).norm
///         return turnover - 0.20
///     },
///
///     // Terminal condition: final value ≥ target
///     .terminal { xₜ in
///         targetValue - xₜ.dot(expectedReturns)
///     }
/// ]
/// ```
public enum MultiPeriodConstraint<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {

	// MARK: - Intra-Temporal Constraints

	/// Constraint that applies to each period independently.
	///
	/// Function signature: (period: Int, state: V) -> Double
	/// Returns: ≤ 0 for feasibility (inequality) or = 0 (equality)
	///
	/// - Parameters:
	///   - function: Constraint function f(t, xₜ)
	///   - isEquality: Whether this is an equality constraint (default: false)
	case eachPeriod(
		function: @Sendable (Int, V) -> Double,
		isEquality: Bool = false
	)

	// MARK: - Inter-Temporal Constraints

	/// Constraint linking consecutive periods (transition dynamics).
	///
	/// Function signature: (period: Int, currentState: V, nextState: V) -> Double
	/// Returns: ≤ 0 for feasibility (inequality) or = 0 (equality)
	///
	/// Examples:
	/// - Transaction costs: turnover between periods
	/// - Inventory balance: production + stock₍ₜ₎ - demand = stock₍ₜ₊₁₎
	/// - Cash flow dynamics: cash₍ₜ₊₁₎ = cash₍ₜ₎ + revenue₍ₜ₎ - costs₍ₜ₎
	///
	/// - Parameters:
	///   - function: Constraint function g(t, xₜ, xₜ₊₁)
	///   - isEquality: Whether this is an equality constraint (default: false)
	case transition(
		function: @Sendable (Int, V, V) -> Double,
		isEquality: Bool = false
	)

	// MARK: - Terminal Constraints

	/// Constraint applying only to the final period.
	///
	/// Function signature: (finalState: V) -> Double
	/// Returns: ≤ 0 for feasibility (inequality) or = 0 (equality)
	///
	/// Examples:
	/// - Minimum terminal wealth
	/// - Target inventory level at end
	/// - Final portfolio composition
	///
	/// - Parameters:
	///   - function: Constraint function h(xₜ)
	///   - isEquality: Whether this is an equality constraint (default: false)
	case terminal(
		function: @Sendable (V) -> Double,
		isEquality: Bool = false
	)

	// MARK: - Trajectory Constraints

	/// Constraint applying to the entire trajectory.
	///
	/// Function signature: (trajectory: [V]) -> Double
	/// Returns: ≤ 0 for feasibility (inequality) or = 0 (equality)
	///
	/// Examples:
	/// - Average portfolio turnover over all periods
	/// - Total production volume
	/// - Cumulative cash flow
	///
	/// - Parameters:
	///   - function: Constraint function k(x₁, ..., xₜ)
	///   - isEquality: Whether this is an equality constraint (default: false)
	case trajectory(
		function: @Sendable ([V]) -> Double,
		isEquality: Bool = false
	)

	// MARK: - Constraint Properties

	/// Whether this is an equality constraint.
	public var isEquality: Bool {
		switch self {
		case .eachPeriod(_, let isEquality),
			 .transition(_, let isEquality),
			 .terminal(_, let isEquality),
			 .trajectory(_, let isEquality):
			return isEquality
		}
	}

	/// Evaluate the constraint for a given trajectory.
	///
	/// - Parameter trajectory: Decision variables for all periods
	/// - Returns: Array of constraint values (one per constraint evaluation)
	public func evaluate(trajectory: [V]) -> [Double] {
		guard !trajectory.isEmpty else { return [] }

		switch self {
		case .eachPeriod(let function, _):
			// Evaluate for each period
			return trajectory.enumerated().map { t, xₜ in
				function(t, xₜ)
			}

		case .transition(let function, _):
			// Evaluate for each consecutive pair
			guard trajectory.count > 1 else { return [] }
			return (0..<trajectory.count-1).map { t in
				function(t, trajectory[t], trajectory[t+1])
			}

		case .terminal(let function, _):
			// Evaluate only for final period
			return [function(trajectory.last!)]

		case .trajectory(let function, _):
			// Evaluate once for entire trajectory
			return [function(trajectory)]
		}
	}

	/// Check if the constraint is satisfied for a given trajectory.
	///
	/// - Parameters:
	///   - trajectory: Decision variables for all periods
	///   - tolerance: Feasibility tolerance (default: 1e-6)
	/// - Returns: True if constraint is satisfied
	public func isSatisfied(trajectory: [V], tolerance: Double = 1e-6) -> Bool {
		let values = evaluate(trajectory: trajectory)

		if isEquality {
			// Equality: |value| ≤ tolerance
			return values.allSatisfy { abs($0) <= tolerance }
		} else {
			// Inequality: value ≤ tolerance
			return values.allSatisfy { $0 <= tolerance }
		}
	}
}

// MARK: - Common Multi-Period Constraints

extension MultiPeriodConstraint {

	/// Budget constraint for each period: Σw = 1
	///
	/// Ensures portfolio weights sum to 1 in every period.
	public static var budgetEachPeriod: MultiPeriodConstraint {
		.eachPeriod(
			function: { _, x in
				let sum = x.toArray().reduce(0.0, +)
				return sum - 1.0
			},
			isEquality: true
		)
	}

	/// Non-negativity constraint for each period: w ≥ 0
	///
	/// Prevents short-selling in every period.
	///
	/// - Parameter dimension: Number of assets
	/// - Returns: Array of non-negativity constraints
	public static func nonNegativityEachPeriod(dimension: Int) -> [MultiPeriodConstraint] {
		return (0..<dimension).map { i in
			.eachPeriod(function: { _, x in -x.toArray()[i] })  // x[i] ≥ 0 → -x[i] ≤ 0
		}
	}

	/// Maximum turnover constraint between periods.
	///
	/// Limits the L1 norm of portfolio changes: ||xₜ₊₁ - xₜ||₁ ≤ maxTurnover
	///
	/// - Parameter maxTurnover: Maximum allowed turnover (default: 0.20 = 20%)
	/// - Returns: Transition constraint
	public static func turnoverLimit(_ maxTurnover: Double = 0.20) -> MultiPeriodConstraint {
		.transition { _, xₜ, xₜ₊₁ in
			// L1 norm of difference (sum of absolute changes)
			let changes = zip(xₜ.toArray(), xₜ₊₁.toArray()).map { abs($1 - $0) }
			let turnover = changes.reduce(0.0, +)
			return turnover - maxTurnover
		}
	}

	/// Transaction cost penalty in objective (modeled as constraint).
	///
	/// Penalizes portfolio changes proportionally: cost = rate × turnover
	///
	/// - Parameter rate: Transaction cost rate (default: 0.001 = 0.1%)
	/// - Returns: Transition constraint (inequality for maximum cost)
	public static func transactionCost(rate: Double = 0.001, maxCost: Double) -> MultiPeriodConstraint {
		.transition { _, xₜ, xₜ₊₁ in
			let changes = zip(xₜ.toArray(), xₜ₊₁.toArray()).map { abs($1 - $0) }
			let turnover = changes.reduce(0.0, +)
			let cost = rate * turnover
			return cost - maxCost
		}
	}

	/// Terminal wealth constraint: final portfolio value ≥ target
	///
	/// - Parameters:
	///   - targetValue: Minimum required terminal value
	///   - valuationFunction: Function to compute portfolio value from weights
	/// - Returns: Terminal constraint
	public static func terminalWealth(
		targetValue: Double,
		valuationFunction: @escaping @Sendable (V) -> Double
	) -> MultiPeriodConstraint {
		.terminal { xₜ in
			targetValue - valuationFunction(xₜ)  // value ≥ target → target - value ≤ 0
		}
	}

	/// Average constraint across all periods.
	///
	/// Enforces that the average of some metric across all periods meets a threshold.
	///
	/// Example: Average portfolio return ≥ 8%
	///
	/// - Parameters:
	///   - metric: Function computing metric for each period
	///   - threshold: Minimum average value
	/// - Returns: Trajectory constraint
	public static func averageConstraint(
		metric: @escaping @Sendable (V) -> Double,
		minimumAverage threshold: Double
	) -> MultiPeriodConstraint {
		.trajectory { trajectory in
			let values = trajectory.map(metric)
			let average = values.reduce(0.0, +) / Double(values.count)
			return threshold - average  // average ≥ threshold → threshold - average ≤ 0
		}
	}

	/// Cumulative sum constraint across all periods.
	///
	/// Example: Total production ≤ capacity
	///
	/// - Parameters:
	///   - metric: Function computing metric for each period
	///   - maxCumulative: Maximum cumulative sum
	/// - Returns: Trajectory constraint
	public static func cumulativeLimit(
		metric: @escaping @Sendable (V) -> Double,
		maximum maxCumulative: Double
	) -> MultiPeriodConstraint {
		.trajectory { trajectory in
			let total = trajectory.map(metric).reduce(0.0, +)
			return total - maxCumulative  // total ≤ max → total - max ≤ 0
		}
	}
}
