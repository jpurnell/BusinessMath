//
//  InequalityOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Inequality Optimizer

/// Optimizer for problems with both equality and inequality constraints.
///
/// Solves optimization problems of the form:
/// ```
/// minimize f(x)
/// subject to: hᵢ(x) = 0  (equality constraints)
///            gⱼ(x) ≤ 0  (inequality constraints)
/// ```
///
/// ## Method
///
/// Uses an **augmented Lagrangian with quadratic penalties**:
/// - Equality constraints: Augmented Lagrangian with multiplier updates
/// - Inequality constraints: Quadratic penalty on violations only
///
/// The modified objective becomes:
/// ```
/// L(x,λ,μ,ρ) = f(x) + Σλᵢhᵢ(x) + (ρ/2)Σhᵢ(x)² + (ρ/2)Σmax(0, gⱼ(x))²
/// ```
///
/// As ρ → ∞, the solution approaches the constrained optimum.
///
/// ## Usage Example
/// ```swift
/// let optimizer = InequalityOptimizer<VectorN<Double>>()
///
/// // Portfolio optimization: minimize variance, Σw=1, w≥0
/// let result = try optimizer.minimize(
///     portfolioVariance,
///     from: VectorN([0.33, 0.33, 0.34]),
///     subjectTo: [
///         .budgetConstraint,  // Σw = 1
///     ] + .nonNegativity(dimension: 3)  // w ≥ 0
/// )
/// ```
public struct InequalityOptimizer<V: VectorSpace> where V.Scalar: Real {

	/// Convergence tolerance for constraint satisfaction
	public let constraintTolerance: V.Scalar

	/// Convergence tolerance for gradient norm
	public let gradientTolerance: V.Scalar

	/// Maximum number of outer iterations
	public let maxIterations: Int

	/// Maximum number of inner iterations per outer iteration
	public let maxInnerIterations: Int

	/// Initial penalty parameter
	public let initialPenalty: V.Scalar

	/// Penalty increase factor
	public let penaltyIncrease: V.Scalar

	/// Creates an inequality optimizer with specified parameters.
	public init(
		constraintTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		gradientTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		maxIterations: Int = 100,
		maxInnerIterations: Int = 1000,
		initialPenalty: V.Scalar = V.Scalar(10),
		penaltyIncrease: V.Scalar = V.Scalar(10)
	) {
		self.constraintTolerance = constraintTolerance
		self.gradientTolerance = gradientTolerance
		self.maxIterations = maxIterations
		self.maxInnerIterations = maxInnerIterations
		self.initialPenalty = initialPenalty
		self.penaltyIncrease = penaltyIncrease
	}

	// MARK: - Public API

	/// Minimize an objective function subject to equality and inequality constraints.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point
	///   - constraints: Array of equality and/or inequality constraints
	/// - Returns: Optimization result with solution and Lagrange multipliers
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		guard !constraints.isEmpty else {
			throw OptimizationError.invalidInput(
				message: "No constraints provided. Use unconstrained optimizer instead."
			)
		}

		// Separate constraints
		let equalityConstraints = constraints.filter { $0.isEquality }
		let inequalityConstraints = constraints.filter { $0.isInequality }

		return try optimizeWithQuadraticPenalty(
			objective: objective,
			initialGuess: initialGuess,
			equalityConstraints: equalityConstraints,
			inequalityConstraints: inequalityConstraints
		)
	}

	/// Maximize an objective function subject to constraints.
	public func maximize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {
		let result = try minimize({ -objective($0) }, from: initialGuess, subjectTo: constraints)
		return result.negated()
	}

	// MARK: - Quadratic Penalty Method

	private func optimizeWithQuadraticPenalty(
		objective: @escaping (V) -> V.Scalar,
		initialGuess: V,
		equalityConstraints: [MultivariateConstraint<V>],
		inequalityConstraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		var x = initialGuess
		var lambdaEq = [V.Scalar](repeating: V.Scalar(0), count: equalityConstraints.count)
		var rho = initialPenalty
		var history: [(Int, V, V.Scalar, V.Scalar)] = []

		for outerIter in 0..<maxIterations {
			// Build augmented Lagrangian with quadratic penalties
			let augmentedLagrangian: (V) -> V.Scalar = { point in
				var value = objective(point)

				// Equality constraints: λᵢhᵢ(x) + (ρ/2)hᵢ(x)²
				for (i, constraint) in equalityConstraints.enumerated() {
					let h = constraint.evaluate(at: point)
					value = value + lambdaEq[i] * h + (rho / V.Scalar(2)) * h * h
				}

				// Inequality constraints: (ρ/2)Σmax(0, gⱼ(x))²
				// Only penalize violations (g > 0), satisfied constraints contribute 0
				for constraint in inequalityConstraints {
					let g = constraint.evaluate(at: point)
					if g > V.Scalar(0) {
						value = value + (rho / V.Scalar(2)) * g * g
					}
				}

				return value
			}

			// Minimize augmented Lagrangian
			let innerOptimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxInnerIterations,
				tolerance: gradientTolerance,
				useLineSearch: true,
				recordHistory: false
			)

			let innerResult = try innerOptimizer.minimizeBFGS(
				function: augmentedLagrangian,
				gradient: { point in try numericalGradient(augmentedLagrangian, at: point) },
				initialGuess: x
			)
			x = innerResult.solution

			// Evaluate constraints
			let eqViolations = equalityConstraints.map { abs($0.evaluate(at: x)) }
			let ineqViolations = inequalityConstraints.map { Swift.max(0, $0.evaluate(at: x)) }
			let maxEqViolation = eqViolations.max() ?? V.Scalar(0)
			let maxIneqViolation = ineqViolations.max() ?? V.Scalar(0)
			let maxViolation = Swift.max(maxEqViolation, maxIneqViolation)

			// Record history
			let objValue = objective(x)
			history.append((outerIter, x, objValue, maxViolation))

			// Check convergence
			if maxViolation < constraintTolerance {
				return ConstrainedOptimizationResult(
					solution: x,
					objectiveValue: objValue,
					lagrangeMultipliers: lambdaEq,
					iterations: outerIter + 1,
					converged: true,
					history: history,
					constraintViolation: maxViolation
				)
			}

			// Update Lagrange multipliers for equality constraints
			for i in 0..<lambdaEq.count {
				lambdaEq[i] = lambdaEq[i] + rho * equalityConstraints[i].evaluate(at: x)
			}

			// Increase penalty parameter
			rho = rho * penaltyIncrease
		}

		// Did not converge
		let finalObjValue = objective(x)
		let finalEqViolation = equalityConstraints.map { abs($0.evaluate(at: x)) }.max() ?? V.Scalar(0)
		let finalIneqViolation = inequalityConstraints.map { Swift.max(0, $0.evaluate(at: x)) }.max() ?? V.Scalar(0)
		let finalViolation = Swift.max(finalEqViolation, finalIneqViolation)

		return ConstrainedOptimizationResult(
			solution: x,
			objectiveValue: finalObjValue,
			lagrangeMultipliers: lambdaEq,
			iterations: maxIterations,
			converged: false,
			history: history,
			constraintViolation: finalViolation
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension InequalityOptimizer: MultivariateOptimizer {
	/// Minimize an objective function subject to constraints (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by delegating to the
	/// specialized ``minimize(_:from:subjectTo:)`` method and converting the result type.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of constraints. Accepts both equality and inequality constraints.
	/// - Returns: Optimization result (base protocol type)
	/// - Throws: ``OptimizationError`` if no constraints provided or optimization fails
	///
	/// - Note: For access to Lagrange multipliers, use the specialized
	///   ``minimize(_:from:subjectTo:)`` method which returns ``ConstrainedOptimizationResult``.
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// InequalityOptimizer accepts both equality and inequality constraints
		// No constraint type validation needed

		// Delegate to specialized method
		let result = try minimize(objective, from: initialGuess, subjectTo: constraints)

		// Convert to protocol result type (discards Lagrange multipliers)
		return MultivariateOptimizationResult(
			solution: result.solution,
			value: result.objectiveValue,
			iterations: result.iterations,
			converged: result.converged,
			gradientNorm: V.Scalar(0),  // Not tracked for inequality optimizers
			history: nil  // History format incompatible (constraint violation vs gradient norm)
		)
	}
}
