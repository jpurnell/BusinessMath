//
//  AdaptiveOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Adaptive Optimizer

/// Automatically selects the best optimization algorithm based on problem characteristics.
///
/// The adaptive optimizer analyzes the problem (size, constraints, gradient availability)
/// and intelligently chooses the most appropriate algorithm.
///
/// ## Example
/// ```swift
/// let optimizer = AdaptiveOptimizer<VectorN<Double>>()
///
/// let result = try optimizer.optimize(
///     objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
///     initialGuess: VectorN([0.0, 0.0]),
///     constraints: []
/// )
///
/// print("Solution: \(result.solution)")
/// print("Algorithm used: \(result.algorithmUsed)")
/// print("Selection reason: \(result.selectionReason)")
/// ```
public struct AdaptiveOptimizer<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Properties

	/// Prefer faster algorithms over more accurate ones
	public let preferSpeed: Bool

	/// Prefer more accurate algorithms over faster ones
	public let preferAccuracy: Bool

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Result

	/// Result from adaptive optimization.
	public struct Result {
		/// Optimal solution
		public let solution: V

		/// Objective value at solution
		public let objectiveValue: V.Scalar

		/// Name of algorithm that was selected
		public let algorithmUsed: String

		/// Explanation of why this algorithm was chosen
		public let selectionReason: String

		/// Number of iterations
		public let iterations: Int

		/// Whether optimization converged
		public let converged: Bool

		/// Constraint violations (if applicable)
		public let constraintViolation: V.Scalar?

		/// Formatter used for displaying results (mutable for customization)
		public var formatter: FloatingPointFormatter = .optimization
	}

	// MARK: - Algorithm Choice

	private enum AlgorithmChoice {
		case gradientDescent
		case newtonRaphson
		case constrained
		case inequality

		var name: String {
			switch self {
			case .gradientDescent: return "Gradient Descent"
			case .newtonRaphson: return "Newton-Raphson"
			case .constrained: return "Constrained Optimizer"
			case .inequality: return "Inequality Optimizer"
			}
		}
	}

	// MARK: - Initialization

	/// Creates an adaptive optimizer with specified preferences.
	public init(
		preferSpeed: Bool = false,
		preferAccuracy: Bool = false,
		maxIterations: Int = 1000,
		tolerance: Double = 1e-6
	) {
		self.preferSpeed = preferSpeed
		self.preferAccuracy = preferAccuracy
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize with automatic algorithm selection.
	///
	/// - Parameters:
	///   - objective: Objective function to minimize
	///   - gradient: Optional gradient function (nil for numerical)
	///   - initialGuess: Starting point
	///   - constraints: Constraints (equality and inequality)
	///   - options: Optimization options
	/// - Returns: Optimization result with algorithm info
	/// - Throws: OptimizationError if optimization fails
	public func optimize(
		objective: @escaping (V) -> V.Scalar,
		gradient: ((V) throws -> V)? = nil,
		initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> Result {

		// Analyze problem characteristics
		let problemSize = initialGuess.toArray().count
		let hasConstraints = !constraints.isEmpty
		let hasInequalities = constraints.contains { !$0.isEquality }
		let hasGradient = gradient != nil

		// Select algorithm
		let choice = selectAlgorithm(
			problemSize: problemSize,
			hasConstraints: hasConstraints,
			hasInequalities: hasInequalities,
			hasGradient: hasGradient
		)

		// Run selected algorithm
		let result: Result

		switch choice.algorithm {
		case .gradientDescent:
			// Use adaptive learning rate based on problem size
			let problemSize = initialGuess.toArray().count
			let learningRate: V.Scalar
			if problemSize > 100 {
				// Large problems: higher learning rate for faster convergence
				learningRate = preferSpeed ? V.Scalar(0.05) : V.Scalar(0.01)
			} else {
				// Small problems: conservative rate for stability
				learningRate = preferSpeed ? V.Scalar(0.01) : V.Scalar(0.001)
			}
			let optimizer = MultivariateGradientDescent<V>(
				learningRate: learningRate,
				maxIterations: maxIterations,
				tolerance: V.Scalar(tolerance)
			)
			let gradientFunc = gradient ?? { try numericalGradient(objective, at: $0) }
			let optimResult = try optimizer.minimize(
				function: objective,
				gradient: gradientFunc,
				initialGuess: initialGuess
			)
			result = Result(
				solution: optimResult.solution,
				objectiveValue: optimResult.value,
				algorithmUsed: choice.algorithm.name,
				selectionReason: choice.reason,
				iterations: optimResult.iterations,
				converged: optimResult.converged,
				constraintViolation: nil
			)

		case .newtonRaphson:
			let optimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxIterations,
				tolerance: V.Scalar(tolerance)
			)
			let gradientFunc = gradient ?? { try numericalGradient(objective, at: $0) }
			let hessianFunc: (V) throws -> [[V.Scalar]] = { try numericalHessian(objective, at: $0) }
			let optimResult = try optimizer.minimize(
				function: objective,
				gradient: gradientFunc,
				hessian: hessianFunc,
				initialGuess: initialGuess
			)
			result = Result(
				solution: optimResult.solution,
				objectiveValue: optimResult.value,
				algorithmUsed: choice.algorithm.name,
				selectionReason: choice.reason,
				iterations: optimResult.iterations,
				converged: optimResult.converged,
				constraintViolation: nil
			)

		case .constrained:
			let optimizer = ConstrainedOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations
			)
			let optimResult = try optimizer.minimize(
				objective,
				from: initialGuess,
				subjectTo: constraints
			)
			result = Result(
				solution: optimResult.solution,
				objectiveValue: optimResult.objectiveValue,
				algorithmUsed: choice.algorithm.name,
				selectionReason: choice.reason,
				iterations: optimResult.iterations,
				converged: optimResult.converged,
				constraintViolation: optimResult.constraintViolation
			)

		case .inequality:
			let optimizer = InequalityOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations
			)
			let optimResult = try optimizer.minimize(
				objective,
				from: initialGuess,
				subjectTo: constraints
			)
			result = Result(
				solution: optimResult.solution,
				objectiveValue: optimResult.objectiveValue,
				algorithmUsed: choice.algorithm.name,
				selectionReason: choice.reason,
				iterations: optimResult.iterations,
				converged: optimResult.converged,
				constraintViolation: optimResult.constraintViolation
			)
		}

		return result
	}

	// MARK: - Algorithm Selection Logic

	/// Select the best algorithm based on problem characteristics.
	private func selectAlgorithm(
		problemSize: Int,
		hasConstraints: Bool,
		hasInequalities: Bool,
		hasGradient: Bool
	) -> (algorithm: AlgorithmChoice, reason: String) {

		// Rule 1: Inequality constraints → InequalityOptimizer
		if hasInequalities {
			return (
				.inequality,
				"Problem has inequality constraints - using penalty-barrier method"
			)
		}

		// Rule 2: Equality constraints only → ConstrainedOptimizer
		if hasConstraints {
			return (
				.constrained,
				"Problem has equality constraints - using augmented Lagrangian method"
			)
		}

		// Rule 3: Large unconstrained problem → Gradient Descent
		if problemSize > 100 {
			return (
				.gradientDescent,
				"Large problem (\(problemSize) variables) - using memory-efficient gradient descent"
			)
		}

		// Rule 4: Prefer accuracy + small problem → Newton-Raphson
		if preferAccuracy && problemSize < 10 {
			return (
				.newtonRaphson,
				"Accuracy preference with small problem - using full Newton-Raphson"
			)
		}

		// Rule 5: Very small problem → Newton-Raphson (best convergence)
		if problemSize <= 5 && !preferSpeed {
			return (
				.newtonRaphson,
				"Small problem (\(problemSize) variables) - using Newton-Raphson for fast convergence"
			)
		}

		// Rule 6: Default unconstrained → Gradient Descent (best balance)
		return (
			.gradientDescent,
			"Unconstrained problem - using gradient descent (optimal speed/memory balance)"
		)
	}

	// MARK: - Convenience Methods

	/// Optimize with minimal parameters (uses all defaults).
	public func optimizeSimple(
		objective: @escaping (V) -> V.Scalar,
		initialGuess: V
	) throws -> Result {
		try optimize(
			objective: objective,
			gradient: nil,
			initialGuess: initialGuess,
			constraints: []
		)
	}
}

// MARK: - Problem Characteristics Analysis

extension AdaptiveOptimizer {

	/// Analyze problem characteristics for debugging.
	public struct ProblemAnalysis {
		public let size: Int
		public let hasConstraints: Bool
		public let hasInequalities: Bool
		public let hasGradient: Bool
		public let recommendedAlgorithm: String
		public let reason: String
	}

	/// Analyze a problem without running optimization.
	///
	/// Useful for understanding what algorithm will be selected.
	public func analyzeProblem(
		initialGuess: V,
		constraints: [MultivariateConstraint<V>],
		hasGradient: Bool
	) -> ProblemAnalysis {
		let problemSize = initialGuess.toArray().count
		let hasConstraints = !constraints.isEmpty
		let hasInequalities = constraints.contains { !$0.isEquality }

		let choice = selectAlgorithm(
			problemSize: problemSize,
			hasConstraints: hasConstraints,
			hasInequalities: hasInequalities,
			hasGradient: hasGradient
		)

		return ProblemAnalysis(
			size: problemSize,
			hasConstraints: hasConstraints,
			hasInequalities: hasInequalities,
			hasGradient: hasGradient,
			recommendedAlgorithm: choice.algorithm.name,
			reason: choice.reason
		)
	}
}

// MARK: - Formatting Extensions (Double only)

extension AdaptiveOptimizer.Result where V.Scalar == Double {
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

	/// Formatted description showing clean results
	public var formattedDescription: String {
		var desc = "Adaptive Optimization Result:\n"
		desc += "  Algorithm: \(algorithmUsed)\n"
		desc += "  Reason: \(selectionReason)\n"
		desc += "  Solution: \(formattedSolution)\n"
		desc += "  Objective Value: \(formattedObjectiveValue)\n"
		desc += "  Iterations: \(iterations)\n"
		desc += "  Converged: \(converged)"
		if let violation = constraintViolation {
			desc += "\n  Constraint Violation: \(formatter.format(violation).formatted)"
		}
		return desc
	}
}
