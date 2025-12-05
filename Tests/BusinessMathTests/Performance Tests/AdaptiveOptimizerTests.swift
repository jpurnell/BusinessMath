//
//  AdaptiveOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import XCTest
@testable import BusinessMath

final class AdaptiveOptimizerTests: XCTestCase {

	// MARK: - Algorithm Selection Tests

	/// Test that inequality constraints select InequalityOptimizer
	func testInequalityConstraintSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([5.0, 5.0]),
			constraints: [
				.inequality(function: { x in -x.toArray()[0] }, gradient: nil),  // x >= 0
				.inequality(function: { x in -x.toArray()[1] }, gradient: nil)   // y >= 0
			]
		)

		XCTAssertEqual(result.algorithmUsed, "Inequality Optimizer")
		XCTAssertTrue(result.selectionReason.contains("inequality"))
		XCTAssertTrue(result.converged)
	}

	/// Test that equality constraints select ConstrainedOptimizer
	func testEqualityConstraintSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: [
				.equality(function: { x in x.toArray()[0] + x.toArray()[1] - 1.0 }, gradient: nil)
			]
		)

		XCTAssertEqual(result.algorithmUsed, "Constrained Optimizer")
		XCTAssertTrue(result.selectionReason.contains("equality"))
		XCTAssertTrue(result.converged)
	}

	/// Test that large unconstrained problems select Gradient Descent
	func testLargeProblemSelection() throws {
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

		XCTAssertEqual(result.algorithmUsed, "Gradient Descent")
		XCTAssertTrue(result.selectionReason.contains("Large problem"))
		XCTAssertTrue(result.converged)
	}

	/// Test that small unconstrained problems select Newton-Raphson by default
	func testSmallUnconstrainedSelection() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try optimizer.optimize(
			objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
			initialGuess: VectorN([0.0, 0.0])
		)

		XCTAssertEqual(result.algorithmUsed, "Newton-Raphson")
		XCTAssertTrue(result.selectionReason.contains("Small problem"))
		XCTAssertTrue(result.converged)

		// Verify solution
		XCTAssertEqual(result.solution[0], 1.0, accuracy: 0.1)
		XCTAssertEqual(result.solution[1], 2.0, accuracy: 0.1)
	}

	/// Test preference for speed still uses gradient descent (fastest available)
	func testSpeedPreference() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(preferSpeed: true)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			gradient: { x in VectorN([2 * x[0], 2 * x[1]]) },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: []
		)

		XCTAssertEqual(result.algorithmUsed, "Gradient Descent")
		XCTAssertTrue(result.converged)
	}

	/// Test preference for accuracy
	func testAccuracyPreference() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(preferAccuracy: true)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0]),
			constraints: []
		)

		XCTAssertEqual(result.algorithmUsed, "Newton-Raphson")
		XCTAssertTrue(result.selectionReason.contains("Accuracy preference"))
	}

	// MARK: - Problem Analysis Tests

	/// Test problem analysis without running optimization
	func testProblemAnalysis() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let analysis = optimizer.analyzeProblem(
			initialGuess: VectorN([1.0, 2.0]),
			constraints: [
				.inequality(function: { x in -x[0] }, gradient: nil)
			],
			hasGradient: true
		)

		XCTAssertEqual(analysis.size, 2)
		XCTAssertTrue(analysis.hasConstraints)
		XCTAssertTrue(analysis.hasInequalities)
		XCTAssertTrue(analysis.hasGradient)
		XCTAssertEqual(analysis.recommendedAlgorithm, "Inequality Optimizer")
	}

	// MARK: - Real-World Problems

	/// Test adaptive optimization on Rosenbrock function
	func testRosenbrockOptimization() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let rosenbrock: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let result = try optimizer.optimize(
			objective: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		XCTAssertTrue(result.converged)
		XCTAssertEqual(result.solution[0], 1.0, accuracy: 0.1)
		XCTAssertEqual(result.solution[1], 1.0, accuracy: 0.1)
		XCTAssertLessThan(result.objectiveValue, 0.1)
	}

	/// Test adaptive optimization on constrained portfolio
	func testConstrainedPortfolio() throws {
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

		XCTAssertEqual(result.algorithmUsed, "Inequality Optimizer")
		XCTAssertTrue(result.converged)

		// Check budget constraint
		let sum = result.solution.toArray().reduce(0, +)
		XCTAssertEqual(sum, 1.0, accuracy: 0.01)

		// Check non-negativity
		for weight in result.solution.toArray() {
			XCTAssertGreaterThanOrEqual(weight, 0.0)
		}
	}

	// MARK: - Convergence Tests

	/// Test that adaptive optimizer converges on easy problems
	func testConvergenceOnQuadratic() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		// Simple quadratic: (x-3)^2 + (y-4)^2
		let result = try optimizer.optimize(
			objective: { x in
				(x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4)
			},
			initialGuess: VectorN([0.0, 0.0])
		)

		XCTAssertTrue(result.converged)
		XCTAssertEqual(result.solution[0], 3.0, accuracy: 0.01)
		XCTAssertEqual(result.solution[1], 4.0, accuracy: 0.01)
		XCTAssertLessThan(Double(result.objectiveValue), 0.01)
	}

	/// Test custom tolerance
	func testCustomTolerance() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(tolerance: 1e-8)

		let result = try optimizer.optimize(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0])
		)

		XCTAssertTrue(result.converged)
		XCTAssertLessThan(Double(result.objectiveValue), 1e-6)
	}

	/// Test max iterations limit
	func testMaxIterations() throws {
		let optimizer = AdaptiveOptimizer<VectorN<Double>>(maxIterations: 5)  // Very low limit

		// Rosenbrock is hard to optimize
		let rosenbrock: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let result = try optimizer.optimize(
			objective: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		XCTAssertLessThanOrEqual(result.iterations, 5)
	}
}
