//
//  MultiPeriodOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Multi-Period Result

/// Result from multi-period optimization.
public struct MultiPeriodResult<V: VectorSpace> where V.Scalar == Double {
	/// Optimal trajectory (decision for each period)
	public let trajectory: [V]

	/// Objective values for each period (undiscounted)
	public let periodObjectives: [Double]

	/// Total discounted objective value
	public let totalObjective: Double

	/// Whether the optimization converged
	public let converged: Bool

	/// Number of iterations used
	public let iterations: Int

	/// Constraint violations (if any)
	public let constraintViolations: [Double]

	/// Number of periods
	public var numberOfPeriods: Int { trajectory.count }

	/// Initial state (first period decision)
	public var initialState: V { trajectory.first! }

	/// Terminal state (final period decision)
	public var terminalState: V { trajectory.last! }
}

// MARK: - Multi-Period Optimizer

/// Optimizer for multi-period problems with inter-temporal constraints.
///
/// Multi-period optimization solves:
/// ```
/// minimize: Σₜ δᵗ f(xₜ)
/// subject to:
///   - Intra-temporal constraints: g(t, xₜ) ≤ 0 for all t
///   - Inter-temporal constraints: h(t, xₜ, xₜ₊₁) ≤ 0 for all t
///   - Terminal constraints: k(xₜ) ≤ 0
/// ```
///
/// Where:
/// - xₜ is the decision vector at period t
/// - δ is the discount factor (1 / (1 + discount_rate))
/// - Constraints can link decisions across time
///
/// ## Example: Portfolio Rebalancing
/// ```swift
/// let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
///     numberOfPeriods: 12,
///     discountRate: 0.08
/// )
///
/// let result = try optimizer.optimize(
///     objective: { t, weights in
///         // Expected return for period t
///         weights.dot(expectedReturns[t])
///     },
///     initialState: VectorN([0.25, 0.25, 0.25, 0.25]),
///     constraints: [
///         .budgetEachPeriod,  // Σw = 1 each period
///         .turnoverLimit(0.20)  // Max 20% rebalancing
///     ]
/// )
/// ```
public struct MultiPeriodOptimizer<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Properties

	/// Number of time periods to optimize over
	public let numberOfPeriods: Int

	/// Discount rate per period (for time value of money)
	public let discountRate: Double

	/// Discount factor δ = 1 / (1 + discountRate)
	public var discountFactor: Double { 1.0 / (1.0 + discountRate) }

	/// Maximum iterations for underlying optimizer
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Creates a multi-period optimizer.
	///
	/// - Parameters:
	///   - numberOfPeriods: Number of time periods (T)
	///   - discountRate: Discount rate per period (default: 0.0 = no discounting)
	///   - maxIterations: Maximum iterations (default: 1000)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		numberOfPeriods: Int,
		discountRate: Double = 0.0,
		maxIterations: Int = 1000,
		tolerance: Double = 1e-6
	) {
		precondition(numberOfPeriods > 0, "Number of periods must be positive")
		precondition(discountRate >= 0.0, "Discount rate must be non-negative")

		self.numberOfPeriods = numberOfPeriods
		self.discountRate = discountRate
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize over multiple periods.
	///
	/// - Parameters:
	///   - objective: Period objective function f(t, xₜ) to maximize/minimize
	///   - initialState: Starting decision (x₀)
	///   - constraints: Multi-period constraints
	///   - minimize: Whether to minimize (true) or maximize (false) the objective
	/// - Returns: Multi-period optimization result
	/// - Throws: OptimizationError if optimization fails
	public func optimize(
		objective: @escaping (Int, V) -> Double,
		initialState: V,
		constraints: [MultiPeriodConstraint<V>] = [],
		minimize: Bool = false  // Default: maximize
	) throws -> MultiPeriodResult<V> {

		// Flatten the multi-period problem into a single large vector space
		// Decision vector: [x₀, x₁, ..., xₜ₋₁] concatenated
		let dimension = initialState.toArray().count
		let totalDimension = dimension * numberOfPeriods

		precondition(dimension > 0, "Initial state must have positive dimension")

		// Create initial flattened vector (repeat initial state for all periods)
		var flatInitial = [Double]()
		for _ in 0..<numberOfPeriods {
			flatInitial.append(contentsOf: initialState.toArray())
		}
		let initialFlat = VectorN(flatInitial)

		// Flattened objective: sum of discounted period objectives
		let flatObjective: (VectorN<Double>) -> Double = { flat in
			let trajectory = self.unflattenTrajectory(flat, dimension: dimension)
			var total = 0.0
			for (t, xₜ) in trajectory.enumerated() {
				let periodValue = objective(t, xₜ)
				let discount = pow(self.discountFactor, Double(t))
				total += discount * periodValue
			}
			return minimize ? total : -total  // Negate for maximization
		}

		// Convert multi-period constraints to single-vector constraints
		let flatConstraints = try convertConstraints(
			constraints,
			dimension: dimension
		)

		// Choose optimizer based on constraint types
		let hasInequality = flatConstraints.contains { !$0.isEquality }

		let result: ConstrainedOptimizationResult<VectorN<Double>>

		if hasInequality {
			// Use inequality optimizer
			let optimizer = InequalityOptimizer<VectorN<Double>>(
				constraintTolerance: tolerance,
				gradientTolerance: tolerance,
				maxIterations: maxIterations,
				maxInnerIterations: 500
			)
			result = try optimizer.minimize(
				flatObjective,
				from: initialFlat,
				subjectTo: flatConstraints
			)
		} else {
			// Use equality-only optimizer
			let optimizer = ConstrainedOptimizer<VectorN<Double>>(
				constraintTolerance: tolerance,
				gradientTolerance: tolerance,
				maxIterations: maxIterations,
				maxInnerIterations: 500
			)
			result = try optimizer.minimize(
				flatObjective,
				from: initialFlat,
				subjectTo: flatConstraints
			)
		}

		// Unflatten the result into trajectory
		let trajectory = unflattenTrajectory(result.solution, dimension: dimension)

		// Compute period objectives (undiscounted)
		let periodObjectives = trajectory.enumerated().map { t, xₜ in
			objective(t, xₜ)
		}

		// Compute total discounted objective (negate back if maximizing)
		let totalObjective = minimize ? result.objectiveValue : -result.objectiveValue

		// Check constraint violations
		let violations = constraints.flatMap { constraint in
			constraint.evaluate(trajectory: trajectory)
		}

		return MultiPeriodResult(
			trajectory: trajectory,
			periodObjectives: periodObjectives,
			totalObjective: totalObjective,
			converged: result.converged,
			iterations: result.iterations,
			constraintViolations: violations
		)
	}

	// MARK: - Helper Methods

	/// Flatten a trajectory into a single vector.
	private func flattenTrajectory(_ trajectory: [V]) -> VectorN<Double> {
		let flat = trajectory.flatMap { $0.toArray() }
		return VectorN(flat)
	}

	/// Unflatten a single vector into a trajectory.
	private func unflattenTrajectory(_ flat: VectorN<Double>, dimension: Int) -> [V] {
		let array = flat.toArray()
		var trajectory: [V] = []

		guard dimension > 0 else {
			fatalError("Dimension must be positive, got: \(dimension)")
		}

		for t in 0..<numberOfPeriods {
			let start = t * dimension
			let end = start + dimension

			guard start >= 0 && end <= array.count && start <= end else {
				fatalError("Invalid range: start=\(start), end=\(end), array.count=\(array.count)")
			}

			let periodArray = Array(array[start..<end])
			if let periodVector = V.fromArray(periodArray) {
				trajectory.append(periodVector)
			}
		}

		return trajectory
	}

	/// Convert multi-period constraints to flattened single-vector constraints.
	private func convertConstraints(
		_ constraints: [MultiPeriodConstraint<V>],
		dimension: Int
	) throws -> [MultivariateConstraint<VectorN<Double>>] {

		var flatConstraints: [MultivariateConstraint<VectorN<Double>>] = []

		for constraint in constraints {
			switch constraint {

			case .eachPeriod(let function, let isEquality):
				// Create one constraint per period
				for t in 0..<numberOfPeriods {
					let flat = createPeriodConstraint(
						period: t,
						dimension: dimension,
						function: function,
						isEquality: isEquality
					)
					flatConstraints.append(flat)
				}

			case .transition(let function, let isEquality):
				// Create one constraint per transition
				for t in 0..<(numberOfPeriods - 1) {
					let flat = createTransitionConstraint(
						period: t,
						dimension: dimension,
						function: function,
						isEquality: isEquality
					)
					flatConstraints.append(flat)
				}

			case .terminal(let function, let isEquality):
				// Create one constraint for final period
				let flat = createTerminalConstraint(
					dimension: dimension,
					function: function,
					isEquality: isEquality
				)
				flatConstraints.append(flat)

			case .trajectory(let function, let isEquality):
				// Create one constraint for entire trajectory
				let flat = createTrajectoryConstraint(
					dimension: dimension,
					function: function,
					isEquality: isEquality
				)
				flatConstraints.append(flat)
			}
		}

		return flatConstraints
	}

	/// Create constraint for a single period.
	private func createPeriodConstraint(
		period t: Int,
		dimension: Int,
		function: @escaping (Int, V) -> Double,
		isEquality: Bool
	) -> MultivariateConstraint<VectorN<Double>> {

		let constraintFunction: (VectorN<Double>) -> Double = { flat in
			let trajectory = self.unflattenTrajectory(flat, dimension: dimension)
			return function(t, trajectory[t])
		}

		if isEquality {
			return .equality(function: constraintFunction, gradient: nil)
		} else {
			return .inequality(function: constraintFunction, gradient: nil)
		}
	}

	/// Create constraint for transition between periods.
	private func createTransitionConstraint(
		period t: Int,
		dimension: Int,
		function: @escaping (Int, V, V) -> Double,
		isEquality: Bool
	) -> MultivariateConstraint<VectorN<Double>> {

		let constraintFunction: (VectorN<Double>) -> Double = { flat in
			let trajectory = self.unflattenTrajectory(flat, dimension: dimension)
			return function(t, trajectory[t], trajectory[t+1])
		}

		if isEquality {
			return .equality(function: constraintFunction, gradient: nil)
		} else {
			return .inequality(function: constraintFunction, gradient: nil)
		}
	}

	/// Create constraint for terminal period.
	private func createTerminalConstraint(
		dimension: Int,
		function: @escaping (V) -> Double,
		isEquality: Bool
	) -> MultivariateConstraint<VectorN<Double>> {

		let constraintFunction: (VectorN<Double>) -> Double = { flat in
			let trajectory = self.unflattenTrajectory(flat, dimension: dimension)
			return function(trajectory.last!)
		}

		if isEquality {
			return .equality(function: constraintFunction, gradient: nil)
		} else {
			return .inequality(function: constraintFunction, gradient: nil)
		}
	}

	/// Create constraint for entire trajectory.
	private func createTrajectoryConstraint(
		dimension: Int,
		function: @escaping ([V]) -> Double,
		isEquality: Bool
	) -> MultivariateConstraint<VectorN<Double>> {

		let constraintFunction: (VectorN<Double>) -> Double = { flat in
			let trajectory = self.unflattenTrajectory(flat, dimension: dimension)
			return function(trajectory)
		}

		if isEquality {
			return .equality(function: constraintFunction, gradient: nil)
		} else {
			return .inequality(function: constraintFunction, gradient: nil)
		}
	}
}

// MARK: - Convenience Extensions

extension MultiPeriodOptimizer {

	/// Optimize with a simpler API (no per-period objective).
	///
	/// Use this when the objective is the same across all periods.
	///
	/// - Parameters:
	///   - objective: Period objective function f(xₜ) (same for all t)
	///   - initialState: Starting decision
	///   - constraints: Multi-period constraints
	///   - minimize: Whether to minimize (default: false = maximize)
	public func optimize(
		objective: @escaping (V) -> Double,
		initialState: V,
		constraints: [MultiPeriodConstraint<V>] = [],
		minimize: Bool = false
	) throws -> MultiPeriodResult<V> {
		// Wrap in time-varying objective
		return try optimize(
			objective: { _, x in objective(x) },
			initialState: initialState,
			constraints: constraints,
			minimize: minimize
		)
	}
}
