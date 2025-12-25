//
//  RobustOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Robust Optimization Result

/// Result from robust optimization.
public struct RobustResult<V: VectorSpace> where V.Scalar == Double {
	/// Robust optimal solution
	public let solution: V

	/// Worst-case objective value at the solution
	public let worstCaseObjective: Double

	/// Nominal objective value (at center of uncertainty set)
	public let nominalObjective: Double

	/// Worst-case parameter realization
	public let worstCaseParameters: [Double]

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	// MARK: - Protocol Compatibility

	/// Objective value (alias for worstCaseObjective)
	public var objectiveValue: Double { worstCaseObjective }

	/// Description of optimization outcome
	public var convergenceReason: String {
		if converged {
			return "Robust optimization converged: worst-case objective = \(worstCaseObjective), nominal objective = \(nominalObjective)"
		} else {
			return "Maximum iterations reached: worst-case objective = \(worstCaseObjective), nominal objective = \(nominalObjective)"
		}
	}
}

// MARK: - Robust Optimizer

/// Optimizer for robust optimization under parameter uncertainty.
///
/// Robust optimization solves min-max problems:
/// ```
/// minimize: max{ω ∈ U} f(x, ω)
/// subject to: g(x, ω) ≤ 0 for all ω ∈ U
/// ```
///
/// Where U is the uncertainty set and ω represents uncertain parameters.
///
/// ## Example: Worst-Case Portfolio
/// ```swift
/// let uncertaintySet = BoxUncertaintySet(
///     nominal: [0.10, 0.12, 0.08, 0.04],
///     deviations: [0.02, 0.03, 0.02, 0.01]
/// )
///
/// let optimizer = RobustOptimizer<VectorN<Double>>(
///     uncertaintySet: uncertaintySet,
///     samplesPerIteration: 50
/// )
///
/// let result = try optimizer.optimize(
///     objective: { weights, returns in
///         // Negative for maximization of return
///         -weights.dot(VectorN(returns))
///     },
///     nominalParameters: [0.10, 0.12, 0.08, 0.04],
///     initialSolution: VectorN([0.25, 0.25, 0.25, 0.25]),
///     constraints: [.budgetConstraint] + .nonNegativity(dimension: 4),
///     minimize: true  // Minimize worst-case (maximize worst-case return)
/// )
/// ```
public struct RobustOptimizer<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Properties

	/// Uncertainty set defining parameter ranges
	public let uncertaintySet: any UncertaintySet

	/// Number of samples to use per iteration for worst-case search
	public let samplesPerIteration: Int

	/// Maximum iterations for outer optimization
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Creates a robust optimizer.
	///
	/// - Parameters:
	///   - uncertaintySet: Uncertainty set for parameters
	///   - samplesPerIteration: Samples for worst-case search (default: 100)
	///   - maxIterations: Maximum iterations (default: 500)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		uncertaintySet: any UncertaintySet,
		samplesPerIteration: Int = 100,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) {
		self.uncertaintySet = uncertaintySet
		self.samplesPerIteration = samplesPerIteration
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize for worst-case performance.
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω) depending on decision and parameters
	///   - nominalParameters: Nominal (center) parameter values
	///   - initialSolution: Starting point for decision variables
	///   - constraints: Constraints on decision variables (must hold for all ω)
	///   - minimize: Whether to minimize worst-case (true) or maximize worst-case (false)
	/// - Returns: Robust optimization result
	/// - Throws: OptimizationError if optimization fails
	public func optimize(
		objective: @escaping (V, [Double]) -> Double,
		nominalParameters: [Double],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true
	) throws -> RobustResult<V> {

		precondition(
			nominalParameters.count == uncertaintySet.dimension,
			"Nominal parameters dimension must match uncertainty set"
		)

		// Sample points from uncertainty set for worst-case evaluation
		let uncertaintyPoints = uncertaintySet.samplePoints(numberOfSamples: samplesPerIteration)

		// Create worst-case objective: for each x, find max_ω f(x, ω)
		let worstCaseObjective: (V) -> Double = { x in
			var worstValue = minimize ? -Double.infinity : Double.infinity
			for omega in uncertaintyPoints {
				let value = objective(x, omega)
				if minimize {
					// Minimize worst-case: find maximum over ω
					worstValue = max(worstValue, value)
				} else {
					// Maximize worst-case: find minimum over ω
					worstValue = min(worstValue, value)
				}
			}
			return worstValue
		}

		// Choose optimizer based on constraints
		let hasInequality = constraints.contains { !$0.isEquality }

		let result: ConstrainedOptimizationResult<V>

		if hasInequality {
			let optimizer = InequalityOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(
				worstCaseObjective,
				from: initialSolution,
				subjectTo: constraints
			)
		} else {
			let optimizer = ConstrainedOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(
				worstCaseObjective,
				from: initialSolution,
				subjectTo: constraints
			)
		}

		// Find worst-case parameters at the solution
		let solution = result.solution
		var worstValue = minimize ? -Double.infinity : Double.infinity
		var worstParameters = nominalParameters

		for omega in uncertaintyPoints {
			let value = objective(solution, omega)
			if minimize {
				if value > worstValue {
					worstValue = value
					worstParameters = omega
				}
			} else {
				if value < worstValue {
					worstValue = value
					worstParameters = omega
				}
			}
		}

		// Evaluate at nominal parameters
		let nominalValue = objective(solution, nominalParameters)

		return RobustResult(
			solution: solution,
			worstCaseObjective: worstValue,
			nominalObjective: nominalValue,
			worstCaseParameters: worstParameters,
			converged: result.converged,
			iterations: result.iterations
		)
	}
}

// MARK: - Convenience Extensions

extension RobustOptimizer {

	/// Optimize with box uncertainty set (convenience method).
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω)
	///   - nominal: Nominal parameter values
	///   - deviations: Maximum deviations for each parameter
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision variables
	///   - minimize: Whether to minimize worst-case
	/// - Returns: Robust optimization result
	public static func optimizeBox(
		objective: @escaping (V, [Double]) -> Double,
		nominal: [Double],
		deviations: [Double],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true,
		samplesPerIteration: Int = 100,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) throws -> RobustResult<V> {

		let uncertaintySet = BoxUncertaintySet(
			nominal: nominal,
			deviations: deviations
		)

		let optimizer = RobustOptimizer<V>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: samplesPerIteration,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		return try optimizer.optimize(
			objective: objective,
			nominalParameters: nominal,
			initialSolution: initialSolution,
			constraints: constraints,
			minimize: minimize
		)
	}

	/// Optimize with discrete uncertainty set (convenience method).
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω)
	///   - uncertainPoints: Discrete set of possible parameter values
	///   - nominalIndex: Index of nominal parameters in uncertainPoints
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision variables
	///   - minimize: Whether to minimize worst-case
	/// - Returns: Robust optimization result
	public static func optimizeDiscrete(
		objective: @escaping (V, [Double]) -> Double,
		uncertainPoints: [[Double]],
		nominalIndex: Int = 0,
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) throws -> RobustResult<V> {

		precondition(nominalIndex >= 0 && nominalIndex < uncertainPoints.count,
					 "Nominal index out of bounds")

		let uncertaintySet = DiscreteUncertaintySet(points: uncertainPoints)

		let optimizer = RobustOptimizer<V>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: uncertainPoints.count,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		return try optimizer.optimize(
			objective: objective,
			nominalParameters: uncertainPoints[nominalIndex],
			initialSolution: initialSolution,
			constraints: constraints,
			minimize: minimize
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension RobustOptimizer: MultivariateOptimizer {
	/// Minimize a deterministic objective function (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by treating the
	/// objective as deterministic (no parameter uncertainty). This is a simplified version
	/// that doesn't leverage robust optimization.
	///
	/// - Important: For true robust optimization with parameter uncertainty, use the
	///   specialized ``optimize(objective:nominalParameters:initialSolution:constraints:minimize:)``
	///   method which handles worst-case optimization over uncertain parameters. The protocol
	///   method treats the objective as deterministic.
	///
	/// - Parameters:
	///   - objective: Deterministic function to minimize f: V → ℝ (no uncertain parameters)
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of constraints
	/// - Returns: Optimization result (base protocol type)
	/// - Throws: ``OptimizationError`` if optimization fails
	///
	/// - Note: The returned result is based on the deterministic objective, not worst-case
	///   analysis. Use the specialized ``optimize()`` method for robust results with
	///   worst-case and nominal objective values.
	public func minimize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// For protocol conformance, treat objective as deterministic
		// Choose optimizer based on constraints
		let hasConstraints = !constraints.isEmpty
		let hasInequality = constraints.contains { !$0.isEquality }

		if hasConstraints {
			// Use constrained optimization
			let result: ConstrainedOptimizationResult<V>

			if hasInequality {
				let optimizer = InequalityOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations
				)
				result = try optimizer.minimize(
					objective,
					from: initialGuess,
					subjectTo: constraints
				)
			} else {
				let optimizer = ConstrainedOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations
				)
				result = try optimizer.minimize(
					objective,
					from: initialGuess,
					subjectTo: constraints
				)
			}

			// Convert to protocol result type
			return MultivariateOptimizationResult(
				solution: result.solution,
				value: result.objectiveValue,
				iterations: result.iterations,
				converged: result.converged,
				gradientNorm: 0.0,  // Not tracked for robust optimizer
				history: nil
			)
		} else {
			// Use unconstrained optimization
			let optimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxIterations,
				tolerance: V.Scalar(tolerance)
			)
			let gradient: (V) throws -> V = { point in
				try numericalGradient(objective, at: point)
			}
			let hessian: (V) throws -> [[V.Scalar]] = { point in
				try numericalHessian(objective, at: point)
			}

			return try optimizer.minimize(
				function: objective,
				gradient: gradient,
				hessian: hessian,
				initialGuess: initialGuess
			)
		}
	}
}
