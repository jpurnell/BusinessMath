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
/// Uses a **penalty-barrier approach**:
/// - Equality constraints: Augmented Lagrangian (like ConstrainedOptimizer)
/// - Inequality constraints: Logarithmic barrier function for active constraints
///
/// The modified objective becomes:
/// ```
/// L(x,λ,μ,ρ) = f(x) + Σλᵢhᵢ(x) + (μ/2)Σhᵢ(x)² - ρΣlog(-gⱼ(x))
/// ```
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

	/// Initial penalty parameter for equality constraints
	public let initialPenalty: V.Scalar

	/// Initial barrier parameter for inequality constraints
	public let initialBarrier: V.Scalar

	/// Penalty/barrier increase factor
	public let parameterIncrease: V.Scalar

	/// Safety epsilon for barrier (prevents log(0))
	public let barrierEpsilon: V.Scalar

	/// Creates an inequality optimizer with specified parameters.
	public init(
		constraintTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		gradientTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		maxIterations: Int = 100,
		maxInnerIterations: Int = 1000,
		initialPenalty: V.Scalar = V.Scalar(10),
		initialBarrier: V.Scalar = V.Scalar(1),
		parameterIncrease: V.Scalar = V.Scalar(10),
		barrierEpsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000_000)
	) {
		self.constraintTolerance = constraintTolerance
		self.gradientTolerance = gradientTolerance
		self.maxIterations = maxIterations
		self.maxInnerIterations = maxInnerIterations
		self.initialPenalty = initialPenalty
		self.initialBarrier = initialBarrier
		self.parameterIncrease = parameterIncrease
		self.barrierEpsilon = barrierEpsilon
	}

	// MARK: - Public API

	/// Minimize an objective function subject to equality and inequality constraints.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point (should be feasible for inequality constraints)
	///   - constraints: Array of equality and/or inequality constraints
	/// - Returns: Optimization result with solution and Lagrange multipliers
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		_ objective: @escaping (V) -> V.Scalar,
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

		// Ensure initial point is strictly feasible for inequality constraints
		var x = try ensureFeasibility(initialGuess, inequalityConstraints: inequalityConstraints)

		return try optimizeWithPenaltyBarrier(
			objective: objective,
			initialGuess: x,
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

	// MARK: - Penalty-Barrier Method

	private func optimizeWithPenaltyBarrier(
		objective: @escaping (V) -> V.Scalar,
		initialGuess: V,
		equalityConstraints: [MultivariateConstraint<V>],
		inequalityConstraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		var x = initialGuess
		var lambdaEq = [V.Scalar](repeating: V.Scalar(0), count: equalityConstraints.count)
		var mu = initialPenalty
		var rho = initialBarrier
		var history: [(Int, V, V.Scalar, V.Scalar)] = []

		for outerIter in 0..<maxIterations {
			// Build combined penalty-barrier function
			let penaltyBarrier: (V) -> V.Scalar = { point in
				var value = objective(point)

				// Equality constraint penalties: Σλᵢhᵢ(x) + (μ/2)Σhᵢ(x)²
				for (i, constraint) in equalityConstraints.enumerated() {
					let h = constraint.evaluate(at: point)
					value = value + lambdaEq[i] * h + (mu / V.Scalar(2)) * h * h
				}

				// Inequality constraint barriers: -ρΣlog(-gⱼ(x))
				for constraint in inequalityConstraints {
					let g = constraint.evaluate(at: point)
					// Only apply barrier if constraint is nearly active
					if g > -V.Scalar(1) {
						// Use smoothed barrier to avoid numerical issues
						let barrier = -rho * Self.logBarrier(g, epsilon: self.barrierEpsilon)
						value = value + barrier
					}
				}

				return value
			}

			// Minimize penalty-barrier function
			let innerOptimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxInnerIterations,
				tolerance: gradientTolerance,
				useLineSearch: true,
				recordHistory: false
			)

			let innerResult = try innerOptimizer.minimizeBFGS(
				function: penaltyBarrier,
				gradient: { point in try numericalGradient(penaltyBarrier, at: point) },
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
				lambdaEq[i] = lambdaEq[i] + mu * equalityConstraints[i].evaluate(at: x)
			}

			// Update penalty and barrier parameters
			mu = mu * parameterIncrease
			rho = rho / parameterIncrease  // Decrease barrier weight as we approach solution
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

	// MARK: - Helper Methods

	/// Logarithmic barrier function: -log(-g) for g < 0
	private static func logBarrier(_ g: V.Scalar, epsilon: V.Scalar) -> V.Scalar {
		// Smoothed barrier to avoid numerical issues
		if g < -epsilon {
			return V.Scalar.log(-g)
		} else {
			// Linear extrapolation near boundary to avoid log(0)
			let logEps = V.Scalar.log(epsilon)
			let slope = -V.Scalar(1) / epsilon
			return logEps + slope * (g + epsilon)
		}
	}

	/// Ensure initial point is strictly feasible for inequality constraints
	private func ensureFeasibility(
		_ point: V,
		inequalityConstraints: [MultivariateConstraint<V>]
	) throws -> V {
		var x = point
		let components = x.toArray()

		// Project to feasible region if needed
		var adjusted = false
		for constraint in inequalityConstraints {
			let g = constraint.evaluate(at: x)
			if g > -barrierEpsilon {
				// Constraint violated or too close to boundary
				adjusted = true

				// Simple projection: move slightly into feasible region
				// This is a heuristic - for complex constraints, more sophisticated methods needed
				let grad = try constraint.gradient(at: x)
				let gradArray = grad.toArray()
				let gradNormSq = gradArray.reduce(V.Scalar(0)) { $0 + $1 * $1 }

				if gradNormSq > V.Scalar(0) {
					// Move in direction of -∇g to decrease g
					let stepSize = (g + V.Scalar(10) * barrierEpsilon) / gradNormSq
					let newComponents = zip(components, gradArray).map { $0 - stepSize * $1 }
					if let newX = V.fromArray(newComponents) {
						x = newX
					}
				}
			}
		}

		// Verify feasibility
		let stillInfeasible = inequalityConstraints.contains {
			$0.evaluate(at: x) > -barrierEpsilon / V.Scalar(10)
		}

		if stillInfeasible && adjusted {
			throw OptimizationError.invalidInput(
				message: "Could not find strictly feasible starting point. Try different initial guess."
			)
		}

		return x
	}
}
