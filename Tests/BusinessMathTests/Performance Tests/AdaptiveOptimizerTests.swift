//
//  AdaptiveOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Testing
@testable import BusinessMath

@Suite("Adaptive Optimizer Tests", .serialized)
struct AdaptiveOptimizerTests {

	// MARK: - Expected Algorithm Names (from AdaptiveOptimizer.AlgorithmChoice)

	private let expectedGradientDescent = "Gradient Descent"
	private let expectedNewtonRaphson = "Newton-Raphson"
	private let expectedConstrained = "Constrained Optimizer"
	private let expectedInequality = "Inequality Optimizer"

	// MARK: - Algorithm Selection Tests

	/// Test that inequality constraints select InequalityOptimizer
	@Test func inequalityConstraintSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([5.0, 5.0]),
			constraints: [
				.inequality(function: { x in -x.toArray()[0] }, gradient: nil),  // x >= 0
				.inequality(function: { x in -x.toArray()[1] }, gradient: nil)   // y >= 0
			]
		)

		#expect(result.algorithmUsed == expectedInequality)
		#expect(result.selectionReason.contains("inequality"))
		#expect(result.converged)
	}

	/// Test that equality constraints select ConstrainedOptimizer
	@Test func equalityConstraintSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: [
				.equality(function: { x in x.toArray()[0] + x.toArray()[1] - 1.0 }, gradient: nil)
			]
		)

		#expect(result.algorithmUsed == expectedConstrained)
		#expect(result.selectionReason.contains("equality"))
		#expect(result.converged)
	}

	/// Test that large unconstrained problems select Gradient Descent
	@Test func largeProblemSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		// 150-dimensional problem
		let dimension = 150
		let initial = VectorN(Array(repeating: 0.5, count: dimension))

		let result = try optimizer.optimize(
			objective: { x in
				// Simple quadratic
				x.toArray().reduce(0.0) { $0 + $1 * $1 }
			},
			initialGuess: initial,
			constraints: []
		)

		#expect(result.algorithmUsed == expectedGradientDescent)
		#expect(result.selectionReason.contains("Large problem"))
		#expect(result.converged)
	}

	/// Test that small unconstrained problems select Newton-Raphson by default
	@Test func smallUnconstrainedSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(result.algorithmUsed == expectedNewtonRaphson)
		#expect(result.selectionReason.contains("Small problem"))
		#expect(result.converged)

		// Verify solution
		#expect(abs(result.solution[0] - 1.0) < 0.1)
		#expect(abs(result.solution[1] - 2.0) < 0.1)
	}

	/// Test preference for speed still uses gradient descent (fastest available)
	@Test func speedPreference() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(preferSpeed: true)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			gradient: { x in VectorN([2 * x[0], 2 * x[1]]) },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: []
		)

		#expect(result.algorithmUsed == expectedGradientDescent)
		#expect(result.converged)
	}

	/// Test preference for accuracy
	@Test func accuracyPreference() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(preferAccuracy: true)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: []
		)

		#expect(result.algorithmUsed == expectedNewtonRaphson)
		#expect(result.selectionReason.contains("Accuracy preference"))
	}

	// MARK: - Problem Analysis Tests

	/// Test problem analysis without running optimization
	@Test func problemAnalysis() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let analysis = optimizer.analyzeProblem(
			initialGuess: VectorN([1.0, 2.0]),
			constraints: [
				.inequality(function: { x in -x[0] }, gradient: nil)
			],
			hasGradient: true
		)

		#expect(analysis.size == 2)
		#expect(analysis.hasConstraints)
		#expect(analysis.hasInequalities)
		#expect(analysis.hasGradient)
		#expect(analysis.recommendedAlgorithm == "Inequality Optimizer")
	}

	// MARK: - Real-World Problems

	/// Test adaptive optimization on Rosenbrock function
	@Test func rosenbrockOptimization() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let result = try optimizer.optimize(
			objective: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(result.converged)
		#expect(abs(result.solution[0] - 1.0) < 0.1)
		#expect(abs(result.solution[1] - 1.0) < 0.1)
		#expect(result.objectiveValue < 0.1)
	}

	/// Test adaptive optimization on constrained portfolio
	@Test func constrainedPortfolio() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		// Minimize variance: x'Σx
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.015],
			[0.02, 0.015, 0.16]
		]

		let result = try optimizer.optimize(
			objective: { weights in
				let w = weights.toArray()
				var variance = 0.0
				for i in 0..<3 {
					for j in 0..<3 {
						variance += w[i] * covariance[i][j] * w[j]
					}
				}
				return variance
			},
			initialGuess: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: [
				.equality(function: { x in x.toArray().reduce(0, +) - 1.0 }, gradient: nil),
				.inequality(function: { x in -x[0] }, gradient: nil),
				.inequality(function: { x in -x[1] }, gradient: nil),
				.inequality(function: { x in -x[2] }, gradient: nil)
			]
		)

		#expect(result.algorithmUsed == expectedInequality)
		#expect(result.converged)

		// Check budget constraint
		let sum = result.solution.toArray().reduce(0, +)
		#expect(abs(sum - 1.0) < 0.01)

		// Check non-negativity
		for weight in result.solution.toArray() {
			#expect(weight >= 0.0)
		}
	}

	// MARK: - Convergence Tests

	/// Test that adaptive optimizer converges on easy problems
	@Test func convergenceOnQuadratic() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		// Simple quadratic: (x-3)^2 + (y-4)^2
		let result = try optimizer.optimize(
			objective: { x in
				(x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
			},
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(result.converged)
		#expect(abs(result.solution[0] - 3.0) < 0.01)
		#expect(abs(result.solution[1] - 4.0) < 0.01)
		#expect(Double(result.objectiveValue) < 0.01)
	}

	/// Test custom tolerance
	@Test func customTolerance() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(tolerance: 1e-8)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0])
		)

		#expect(result.converged)
		#expect(Double(result.objectiveValue) < 1e-6)
	}

	/// Test max iterations limit
	@Test func maxIterations() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(maxIterations: 5)  // Very low limit

		// Rosenbrock is hard to optimize
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let result = try optimizer.optimize(
			objective: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(result.iterations <= 5)
	}
}
