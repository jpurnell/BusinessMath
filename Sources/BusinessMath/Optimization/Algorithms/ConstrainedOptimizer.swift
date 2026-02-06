//
//  ConstrainedOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Constrained Optimization Result

/// Result from constrained optimization including Lagrange multipliers.
///
/// In constrained optimization, Lagrange multipliers (λ) represent the "shadow prices"
/// of constraints - how much the objective would improve if the constraint were relaxed.
///
/// ## Example
/// ```swift
/// let optimizer = ConstrainedOptimizer<VectorN<Double>>()
/// let result = try optimizer.minimize(
///     portfolioVariance,
///     from: initialWeights,
///     subjectTo: [.budgetConstraint]
/// )
///
/// print("Optimal weights: \(result.solution)")
/// print("Minimum variance: \(result.objectiveValue)")
/// print("Budget constraint shadow price: \(result.lagrangeMultipliers[0])")
/// ```
public struct ConstrainedOptimizationResult<V: VectorSpace> where V.Scalar: Real {
	/// The optimal solution vector x*
	public let solution: V

	/// The objective function value at the solution f(x*)
	public let objectiveValue: V.Scalar

	/// Lagrange multipliers for equality constraints
	///
	/// The i-th multiplier corresponds to the i-th equality constraint.
	/// A positive multiplier means relaxing that constraint would improve the objective.
	public let lagrangeMultipliers: [V.Scalar]

	/// Number of iterations taken to converge
	public let iterations: Int

	/// Whether the optimization converged successfully
	public let converged: Bool

	/// Optimization history for convergence analysis
	/// Tuple format: (iteration, solution, objectiveValue, constraintViolation)
	public let history: [(Int, V, V.Scalar, V.Scalar)]?

	/// Maximum constraint violation at the solution
	public let constraintViolation: V.Scalar

	/// Creates a constrained optimization result.
	public init(
		solution: V,
		objectiveValue: V.Scalar,
		lagrangeMultipliers: [V.Scalar],
		iterations: Int,
		converged: Bool,
		history: [(Int, V, V.Scalar, V.Scalar)]? = nil,
		constraintViolation: V.Scalar = V.Scalar(0)
	) {
		self.solution = solution
		self.objectiveValue = objectiveValue
		self.lagrangeMultipliers = lagrangeMultipliers
		self.iterations = iterations
		self.converged = converged
		self.history = history
		self.constraintViolation = constraintViolation
	}

	/// Formatter used for displaying results (mutable for customization)
	public var formatter: FloatingPointFormatter = .optimization

	// MARK: - Protocol Compatibility

	/// Description of why optimization stopped (for protocol compatibility)
	public var convergenceReason: String {
		if converged {
			if constraintViolation < V.Scalar(1) / V.Scalar(1_000_000) {
				return "Converged: constraints satisfied within tolerance"
			} else {
				return "Converged: but constraint violation = \(constraintViolation)"
			}
		} else {
			return "Maximum iterations reached"
		}
	}

	/// Negate the objective value (for converting minimize to maximize results)
	func negated() -> ConstrainedOptimizationResult<V> {
		ConstrainedOptimizationResult(
			solution: solution,
			objectiveValue: -objectiveValue,
			lagrangeMultipliers: lagrangeMultipliers.map { -$0 },
			iterations: iterations,
			converged: converged,
			history: history?.map { (iter, sol, obj, viol) in
				(iter, sol, -obj, viol)
			},
			constraintViolation: constraintViolation
		)
	}
}

// MARK: - Formatting Extensions (Double only)

extension ConstrainedOptimizationResult where V.Scalar == Double {
	/// Formatted solution with clean floating-point display
	public var formattedSolution: String {
		if let vectorN = solution as? VectorN<Double> {
			return vectorN.formattedDescription(with: formatter)
		}
		// Fallback for other VectorSpace types with Double scalar
		let array = solution.toArray()
		return "[" + formatter.format(array).map(\.formatted).joined(separator: ", ") + "]"
	}

	/// Formatted objective value with clean floating-point display
	public var formattedObjectiveValue: String {
		formatter.format(objectiveValue).formatted
	}

	/// Formatted Lagrange multipliers with clean floating-point display
	public var formattedLagrangeMultipliers: String {
		"[" + formatter.format(lagrangeMultipliers).map(\.formatted).joined(separator: ", ") + "]"
	}

	/// Formatted constraint violation with clean floating-point display
	public var formattedConstraintViolation: String {
		formatter.format(constraintViolation).formatted
	}

	/// Formatted description showing clean results
	public var formattedDescription: String {
		var desc = "Constrained Optimization Result:\n"
		desc += "  Solution: \(formattedSolution)\n"
		desc += "  Objective Value: \(formattedObjectiveValue)\n"
		desc += "  Lagrange Multipliers: \(formattedLagrangeMultipliers)\n"
		desc += "  Constraint Violation: \(formattedConstraintViolation)\n"
		desc += "  Iterations: \(iterations)\n"
		desc += "  Converged: \(converged)"
		return desc
	}
}

// MARK: - Constrained Optimizer

/// Optimizer for equality-constrained problems using Lagrange multipliers.
///
/// Solves optimization problems of the form:
/// ```
/// minimize f(x)
/// subject to: hᵢ(x) = 0 for i = 1..m (equality constraints)
/// ```
///
/// ## Mathematical Approach
///
/// Uses the **augmented Lagrangian method**, which combines:
/// 1. Lagrange multipliers for constraint satisfaction
/// 2. Penalty terms for robustness
///
/// The augmented Lagrangian is:
/// ```
/// L(x, λ, μ) = f(x) + Σᵢ λᵢ·hᵢ(x) + (μ/2)·Σᵢ hᵢ(x)²
/// ```
///
/// ## Usage Example
/// ```swift
/// let optimizer = ConstrainedOptimizer<VectorN<Double>>(
///     tolerance: 1e-6,
///     maxIterations: 1000
/// )
///
/// // Portfolio optimization with budget constraint
/// let result = try optimizer.minimize(
///     { weights in portfolioVariance(weights) },
///     from: VectorN([0.33, 0.33, 0.34]),
///     subjectTo: [.budgetConstraint]
/// )
/// ```
public struct ConstrainedOptimizer<V: VectorSpace> where V.Scalar: Real {

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

	/// Creates a constrained optimizer with specified parameters.
	///
	/// - Parameters:
	///   - constraintTolerance: Maximum acceptable constraint violation (default: 1e-6)
	///   - gradientTolerance: Gradient norm for convergence (default: 1e-6)
	///   - maxIterations: Maximum outer iterations (default: 100)
	///   - maxInnerIterations: Maximum inner iterations per outer step (default: 1000)
	///   - initialPenalty: Starting penalty parameter (default: 10)
	///   - penaltyIncrease: Factor to increase penalty (default: 10)
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

	/// Minimize an objective function subject to equality constraints.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of equality constraints (hᵢ(x) = 0)
	/// - Returns: Optimization result with solution and Lagrange multipliers
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		// Separate equality and inequality constraints
		let equalityConstraints = constraints.filter { $0.isEquality }
		let inequalityConstraints = constraints.filter { $0.isInequality }

		guard inequalityConstraints.isEmpty else {
			throw OptimizationError.invalidInput(
				message: "ConstrainedOptimizer only handles equality constraints. Use InequalityOptimizer for inequality constraints."
			)
		}

		guard !equalityConstraints.isEmpty else {
			// No constraints - use unconstrained optimizer
			throw OptimizationError.invalidInput(
				message: "No equality constraints provided. Use unconstrained optimizer instead."
			)
		}

		return try optimizeWithAugmentedLagrangian(
			objective: objective,
			initialGuess: initialGuess,
			equalityConstraints: equalityConstraints
		)
	}

	/// Maximize an objective function subject to equality constraints.
	///
	/// - Parameters:
	///   - objective: Function to maximize f: V → ℝ
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of equality constraints (hᵢ(x) = 0)
	/// - Returns: Optimization result with solution and Lagrange multipliers
	/// - Throws: `OptimizationError` if optimization fails
	public func maximize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {
		// Maximize f(x) = minimize -f(x)
		let result = try minimize({ -objective($0) }, from: initialGuess, subjectTo: constraints)
		return result.negated()
	}

	// MARK: - Augmented Lagrangian Method

	private func optimizeWithAugmentedLagrangian(
		objective: @escaping (V) -> V.Scalar,
		initialGuess: V,
		equalityConstraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		var x = initialGuess
		var lambda = [V.Scalar](repeating: V.Scalar(0), count: equalityConstraints.count)
		var mu = initialPenalty
		var history: [(Int, V, V.Scalar, V.Scalar)] = []

		for outerIter in 0..<maxIterations {
			// Build augmented Lagrangian: L(x) = f(x) + Σλᵢhᵢ(x) + (μ/2)Σhᵢ(x)²
			let augmentedLagrangian: (V) -> V.Scalar = { point in
				let objValue = objective(point)
				var augmented = objValue

				// Add Lagrange multiplier terms: Σλᵢhᵢ(x)
				for (i, constraint) in equalityConstraints.enumerated() {
					let h = constraint.evaluate(at: point)
					augmented = augmented + lambda[i] * h
				}

				// Add penalty terms: (μ/2)Σhᵢ(x)²
				let halfMu = mu / V.Scalar(2)
				for constraint in equalityConstraints {
					let h = constraint.evaluate(at: point)
					augmented = augmented + halfMu * h * h
				}

				return augmented
			}

			// Minimize augmented Lagrangian using BFGS
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

			// Evaluate constraints at new x
			let constraintValues = equalityConstraints.map { $0.evaluate(at: x) }
			let maxViolation = constraintValues.map { abs($0) }.max() ?? V.Scalar(0)

			// Record history
			let objValue = objective(x)
			history.append((outerIter, x, objValue, maxViolation))

			// Check convergence
			if maxViolation < constraintTolerance {
				return ConstrainedOptimizationResult(
					solution: x,
					objectiveValue: objValue,
					lagrangeMultipliers: lambda,
					iterations: outerIter + 1,
					converged: true,
					history: history,
					constraintViolation: maxViolation
				)
			}

			// Update Lagrange multipliers: λᵢ ← λᵢ + μ·hᵢ(x)
			for i in 0..<lambda.count {
				lambda[i] = lambda[i] + mu * constraintValues[i]
			}

			// Increase penalty parameter
			mu = mu * penaltyIncrease
		}

		// Did not converge
		let finalObjValue = objective(x)
		let finalViolation = equalityConstraints.map { abs($0.evaluate(at: x)) }.max() ?? V.Scalar(0)

		return ConstrainedOptimizationResult(
			solution: x,
			objectiveValue: finalObjValue,
			lagrangeMultipliers: lambda,
			iterations: maxIterations,
			converged: false,
			history: history,
			constraintViolation: finalViolation
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension ConstrainedOptimizer: MultivariateOptimizer {
	/// Minimize an objective function subject to constraints (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by delegating to the
	/// specialized ``minimize(_:from:subjectTo:)`` method and converting the result type.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of constraints. Must be equality constraints only.
	/// - Returns: Optimization result (base protocol type)
	/// - Throws: ``OptimizationError`` if constraints contain inequality constraints or optimization fails
	///
	/// - Note: For access to Lagrange multipliers, use the specialized
	///   ``minimize(_:from:subjectTo:)`` method which returns ``ConstrainedOptimizationResult``.
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// Validate: only equality constraints supported
		let inequalityConstraints = constraints.filter { $0.isInequality }
		guard inequalityConstraints.isEmpty else {
			throw OptimizationError.unsupportedConstraints(
				"ConstrainedOptimizer only supports equality constraints. " +
				"Found \(inequalityConstraints.count) inequality constraint(s). " +
				"Use InequalityOptimizer for mixed equality/inequality constraints."
			)
		}

		// Delegate to specialized method
		let result = try minimize(objective, from: initialGuess, subjectTo: constraints)

		// Convert to protocol result type (discards Lagrange multipliers)
		return MultivariateOptimizationResult(
			solution: result.solution,
			value: result.objectiveValue,
			iterations: result.iterations,
			converged: result.converged,
			gradientNorm: V.Scalar(0),  // Not tracked for constrained optimizers
			history: nil  // History format incompatible (constraint violation vs gradient norm)
		)
	}
}
