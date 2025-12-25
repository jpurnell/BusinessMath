//
//  ParallelOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  TDD Implementation: Written to pass tests
//

import Foundation
import Numerics

// MARK: - Parallel Multi-Start Optimizer

/// Parallel multi-start optimization for finding global optima.
///
/// Runs multiple optimization attempts from different randomly generated starting
/// points in parallel using Swift's async/await concurrency. Returns the best
/// result found across all attempts, significantly improving the chances of
/// finding the global optimum instead of getting stuck in local minima.
///
/// ## Example
/// ```swift
/// let optimizer = ParallelOptimizer(
///     algorithm: .gradientDescent(learningRate: 0.01),
///     numberOfStarts: 10,
///     maxIterations: 1000
/// )
///
/// let result = try await optimizer.optimize(
///     objective: rosenbrock,
///     searchRegion: (
///         lower: VectorN([-5.0, -5.0]),
///         upper: VectorN([5.0, 5.0])
///     ),
///     constraints: []
/// )
///
/// print("Best objective: \(result.objectiveValue)")
/// print("Success rate: \(result.successRate)")
/// print("Nodes explored: \(result.allResults.count)")
/// ```
public struct ParallelOptimizer<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {

	// MARK: - Algorithm Selection

	/// Algorithm to use for each optimization run
	public enum Algorithm: Sendable {
		case gradientDescent(learningRate: Double)
		case newtonRaphson
		case constrained
		case inequality
	}

	// MARK: - Properties

	/// Algorithm to use for each optimization attempt
	public let algorithm: Algorithm

	/// Number of random starting points to try
	public let numberOfStarts: Int

	/// Maximum iterations per optimization attempt
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Create a parallel multi-start optimizer.
	///
	/// - Parameters:
	///   - algorithm: Algorithm to use for each attempt
	///   - numberOfStarts: Number of random starting points (default: 10)
	///   - maxIterations: Maximum iterations per attempt (default: 1000)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		algorithm: Algorithm,
		numberOfStarts: Int = 10,
		maxIterations: Int = 1000,
		tolerance: Double = 1e-6
	) {
		self.algorithm = algorithm
		self.numberOfStarts = numberOfStarts
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize with multiple random starting points in parallel.
	///
	/// - Parameters:
	///   - objective: Objective function to minimize
	///   - searchRegion: Region to sample starting points from (lower, upper bounds)
	///   - constraints: Optimization constraints
	/// - Returns: Result containing best solution and all attempt results
	public func optimize(
		objective: @Sendable @escaping (V) -> Double,
		searchRegion: (lower: V, upper: V),
		constraints: [MultivariateConstraint<V>] = []
	) async throws -> ParallelOptimizationResult<V> {

		// Generate random starting points within search region
		let startingPoints = generateStartingPoints(
			count: numberOfStarts,
			region: searchRegion
		)

		// Run optimizations in parallel using TaskGroup
		let allResults = try await withThrowingTaskGroup(
			of: (startingPoint: V, result: MultivariateOptimizationResult<V>).self
		) { group in

			// Add a task for each starting point
			// Capture necessary parameters explicitly for sendability
			let algo = algorithm
			let maxIter = maxIterations
			let tol = tolerance

			for start in startingPoints {
				group.addTask {
					let result = try ParallelOptimizer.runSingleOptimization(
						algorithm: algo,
						maxIterations: maxIter,
						tolerance: tol,
						objective: objective,
						initialGuess: start,
						constraints: constraints
					)
					return (startingPoint: start, result: result)
				}
			}

			// Collect all results
			var results: [(V, MultivariateOptimizationResult<V>)] = []
			for try await (start, result) in group {
				results.append((start, result))
			}
			return results
		}

		// Find best result (lowest objective value for minimization)
		var bestResult: MultivariateOptimizationResult<V>? = nil
		var bestStartingPoint: V? = nil
		var bestObjective = Double.infinity

		for (start, result) in allResults {
			if result.value < bestObjective {
				bestObjective = result.value  // Use 'value' not 'objectiveValue'
				bestResult = result
				bestStartingPoint = start
			}
		}

		// Calculate success rate
		let convergedCount = allResults.filter { $0.1.converged }.count
		let successRate = Double(convergedCount) / Double(numberOfStarts)

		// Extract just the optimization results (without starting points)
		let optimizationResults = allResults.map { $0.1 }

		guard let best = bestResult, let bestStart = bestStartingPoint else {
			throw OptimizationError.failedToConverge(message: "No valid solution found")
		}

		return ParallelOptimizationResult(
			success: best.converged,
			solution: best.solution,
			objectiveValue: best.value,  // Use 'value' not 'objectiveValue'
			allResults: optimizationResults,
			successRate: successRate,
			bestStartingPoint: bestStart
		)
	}

	// MARK: - Helper Methods

	/// Generate random starting points within search region
	private func generateStartingPoints(
		count: Int,
		region: (lower: V, upper: V)
	) -> [V] {
		let lowerArray = region.lower.toArray()
		let upperArray = region.upper.toArray()
		let dimension = lowerArray.count

		var points: [V] = []
		for _ in 0..<count {
			var coordinates: [Double] = []
			for d in 0..<dimension {
				let lower = lowerArray[d]
				let upper = upperArray[d]
				let random = Double.random(in: 0...1)
				let value = lower + random * (upper - lower)
				coordinates.append(value)
			}
			// Use fromArray which returns Optional, unwrap with default to zero vector
			if let point = V.fromArray(coordinates) {
				points.append(point)
			}
		}
		return points
	}

	/// Run a single optimization from a starting point
	private static func runSingleOptimization(
		algorithm: Algorithm,
		maxIterations: Int,
		tolerance: Double,
		objective: @escaping (V) -> Double,
		initialGuess: V,
		constraints: [MultivariateConstraint<V>]
	) throws -> MultivariateOptimizationResult<V> {

		switch algorithm {
		case .gradientDescent(let learningRate):
			let optimizer = MultivariateGradientDescent<V>(
				learningRate: learningRate,
				maxIterations: maxIterations,
				tolerance: tolerance
			)
			let gradient = { (v: V) throws -> V in
				try numericalGradient(objective, at: v)
			}
			return try optimizer.minimize(
				function: objective,
				gradient: gradient,
				initialGuess: initialGuess
			)

		case .newtonRaphson:
			let optimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxIterations,
				tolerance: tolerance
			)
			let gradient = { (v: V) throws -> V in
				try numericalGradient(objective, at: v)
			}
			let hessian = { (v: V) throws -> [[Double]] in
				try numericalHessian(objective, at: v)
			}
			return try optimizer.minimize(
				function: objective,
				gradient: gradient,
				hessian: hessian,
				initialGuess: initialGuess
			)

		case .constrained:
			let optimizer = ConstrainedOptimizer<V>(
				constraintTolerance: tolerance,
				gradientTolerance: tolerance,
				maxIterations: maxIterations
			)
			let result = try optimizer.minimize(
				objective,
				from: initialGuess,
				subjectTo: constraints
			)
			// Convert to MultivariateOptimizationResult
			return MultivariateOptimizationResult(
				solution: result.solution,
				value: result.objectiveValue,
				iterations: result.iterations,
				converged: result.converged,
				gradientNorm: 0.0,  // Not tracked for constrained optimizers
				history: nil  // No history tracking
			)

		case .inequality:
			let optimizer = InequalityOptimizer<V>(
				constraintTolerance: tolerance,
				gradientTolerance: tolerance,
				maxIterations: maxIterations
			)
			let result = try optimizer.minimize(
				objective,
				from: initialGuess,
				subjectTo: constraints
			)
			// Convert to MultivariateOptimizationResult
			return MultivariateOptimizationResult(
				solution: result.solution,
				value: result.objectiveValue,
				iterations: result.iterations,
				converged: result.converged,
				gradientNorm: 0.0,  // Not tracked for inequality optimizers
				history: nil  // No history tracking
			)
		}
	}
}

// MARK: - Result Type

/// Result from parallel multi-start optimization.
public struct ParallelOptimizationResult<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {
	/// Whether optimization succeeded (best result converged)
	public let success: Bool

	/// Best solution found across all starting points
	public let solution: V

	/// Objective value at best solution
	public let objectiveValue: Double

	/// Results from all optimization attempts
	public let allResults: [MultivariateOptimizationResult<V>]

	/// Proportion of attempts that converged (0.0 to 1.0)
	public let successRate: Double

	/// Starting point that led to best solution
	public let bestStartingPoint: V

	public init(
		success: Bool,
		solution: V,
		objectiveValue: Double,
		allResults: [MultivariateOptimizationResult<V>],
		successRate: Double,
		bestStartingPoint: V
	) {
		self.success = success
		self.solution = solution
		self.objectiveValue = objectiveValue
		self.allResults = allResults
		self.successRate = successRate
		self.bestStartingPoint = bestStartingPoint
	}

	// MARK: - Protocol Compatibility

	/// Number of iterations taken (sum across all attempts)
	public var iterations: Int {
		allResults.map(\.iterations).reduce(0, +)
	}

	/// Whether optimization converged (best result converged)
	public var converged: Bool { success }

	/// Description of optimization outcome
	public var convergenceReason: String {
		let convergedCount = allResults.filter(\.converged).count
		if success {
			return "Multi-start optimization converged: \(convergedCount)/\(allResults.count) attempts succeeded (success rate: \(successRate.percent()))"
		} else {
			return "Multi-start optimization failed: \(convergedCount)/\(allResults.count) attempts succeeded (success rate: \(successRate.percent()))"
		}
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension ParallelOptimizer: MultivariateOptimizer {
	/// Minimize an objective function with multi-start optimization (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by running multiple
	/// optimization attempts from random starting points. Since this is a synchronous method,
	/// it runs the attempts **sequentially** rather than in parallel.
	///
	/// - Important: For parallel execution with better performance, use the async
	///   ``optimize(objective:searchRegion:constraints:)`` method instead. The protocol
	///   method runs sequentially and loses the concurrency benefits.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Center point for generating random starting points
	///   - constraints: Array of constraints
	/// - Returns: Optimization result from best attempt
	/// - Throws: ``OptimizationError`` if optimization fails
	///
	/// - Note: This method automatically generates a search region around the initial guess
	///   (±5 units in each dimension). For custom search regions, use the async
	///   ``optimize(objective:searchRegion:constraints:)`` method.
	public func minimize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// Generate search region around initial guess (±5 units per dimension)
		let initialArray = initialGuess.toArray()
		let lowerArray = initialArray.map { $0 - 5.0 }
		let upperArray = initialArray.map { $0 + 5.0 }

		guard let lower = V.fromArray(lowerArray),
		      let upper = V.fromArray(upperArray) else {
			throw OptimizationError.invalidInput(
				message: "Failed to create search region from initial guess"
			)
		}

		let searchRegion = (lower: lower, upper: upper)

		// Generate random starting points
		let startingPoints = generateStartingPoints(
			count: numberOfStarts,
			region: searchRegion
		)

		// Run optimizations sequentially (not in parallel, since this is a sync method)
		var allResults: [MultivariateOptimizationResult<V>] = []
		var bestResult: MultivariateOptimizationResult<V>? = nil
		var bestObjective = Double.infinity

		for start in startingPoints {
			let result = try ParallelOptimizer.runSingleOptimization(
				algorithm: algorithm,
				maxIterations: maxIterations,
				tolerance: tolerance,
				objective: objective,
				initialGuess: start,
				constraints: constraints
			)
			allResults.append(result)

			if result.value < bestObjective {
				bestObjective = result.value
				bestResult = result
			}
		}

		guard let best = bestResult else {
			throw OptimizationError.failedToConverge(message: "No valid solution found")
		}

		// Return best result (protocol type)
		return best
	}
}
