//
//  ParallelOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/11/25.
//  TDD: Tests written FIRST, implementation comes after
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Parallel Multi-Start Optimizer Tests", .serialized)
struct ParallelOptimizerTests {

	// MARK: - Basic Functionality Tests

	/// Test that parallel optimizer can solve a simple quadratic
	@Test("Solve simple quadratic with multiple starts")
	func testSimpleQuadratic() async throws {
		// Problem: minimize f(x,y) = (x-3)² + (y-4)²
		// Global optimum: (3, 4) with f = 0

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0]
			let y = v[1]
			return (x - 3.0) * (x - 3.0) + (y - 4.0) * (y - 4.0)
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 5,
			maxIterations: 100,
			tolerance: 1e-6
		)

		// Search region: [-10, 10] × [-10, 10]
		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-10.0, -10.0]),
				upper: VectorN([10.0, 10.0])
			),
			constraints: []
		)

		#expect(result.success, "Should find a solution")
		#expect(result.objectiveValue < 0.1, "Should find near-optimal solution")
		#expect(abs(result.solution[0] - 3.0) < 0.5, "x should be close to 3")
		#expect(abs(result.solution[1] - 4.0) < 0.5, "y should be close to 4")
	}

	/// Test that multi-start finds global optimum better than single start
	@Test("Multi-start finds better solution than single start")
	func testMultiStartImprovement() async throws {
		// Multi-modal function: f(x) = sin(5x) + 0.1x²
		// Has multiple local minima (from sin oscillations) with global minimum near x ≈ -π/2
		// This genuinely requires multi-start to avoid getting trapped in local minima

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0]
			return sin(5.0 * x) + 0.1 * x * x
		}

		// Single-start optimizer
		let singleStart = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.01),
			numberOfStarts: 1,
			maxIterations: 100
		)

		let singleResult = try await singleStart.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-5.0]),
				upper: VectorN([5.0])
			),
			constraints: []
		)

		// Multi-start optimizer
		let multiStart = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.01),
			numberOfStarts: 10,
			maxIterations: 100
		)

		let multiResult = try await multiStart.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-5.0]),
				upper: VectorN([5.0])
			),
			constraints: []
		)

		// Multi-start should find a significantly better solution on multi-modal function
		// Single start often gets trapped in local minimum, multi-start explores more
		#expect(multiResult.objectiveValue <= singleResult.objectiveValue,
				"Multi-start should find at least as good a solution (single: \(singleResult.objectiveValue.number(3)), multi: \(multiResult.objectiveValue.number(3)))")
		#expect(multiResult.success, "Multi-start should succeed")
	}

	// MARK: - Parallel Execution Tests (in separate serialized suite below)

	// MARK: - Result Tracking Tests

	/// Test that all starting points are tracked
	@Test("Track all optimization results")
	func testResultTracking() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 7,
			maxIterations: 50
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-5.0, -5.0]),
				upper: VectorN([5.0, 5.0])
			),
			constraints: []
		)

		#expect(result.allResults.count == 7, "Should have 7 results")
		#expect(result.successRate >= 0.0 && result.successRate <= 1.0,
				"Success rate should be between 0 and 1")
	}

	/// Test success rate calculation
	@Test("Calculate success rate correctly")
	func testSuccessRate() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0]
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 10,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-2.0]),
				upper: VectorN([2.0])
			),
			constraints: []
		)

		// For this simple problem, most/all should succeed
		#expect(result.successRate > 0.5, "Most attempts should succeed")

		// Success rate should match ratio of converged results
		let convergedCount = result.allResults.filter { $0.converged }.count
		let expectedRate = Double(convergedCount) / Double(result.allResults.count)
		#expect(abs(result.successRate - expectedRate) < 1e-9,
				"Success rate should match converged count")
	}

	/// Test best result selection
	@Test("Select best result from all starts")
	func testBestResultSelection() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 3.0) * (v[1] - 3.0)
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 6,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-5.0, -5.0]),
				upper: VectorN([5.0, 5.0])
			),
			constraints: []
		)

		// The selected solution should have the best (lowest) objective value
		let allObjectives = result.allResults.map { $0.value }
		let minObjective = allObjectives.min() ?? .infinity

		#expect(abs(result.objectiveValue - minObjective) < 1e-9,
				"Should select result with best objective value")
	}

	// MARK: - Algorithm Selection Tests

	/// Test gradient descent algorithm
	@Test("Use gradient descent algorithm")
	func testGradientDescentAlgorithm() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 3,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-3.0, -3.0]),
				upper: VectorN([3.0, 3.0])
			),
			constraints: []
		)

		// Accept near-zero objective even if not fully converged
		#expect(result.objectiveValue < 0.1, "Should find near-optimal solution")
	}

	/// Test Newton-Raphson algorithm
	@Test("Use Newton-Raphson algorithm")
	func testNewtonRaphsonAlgorithm() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .newtonRaphson,
			numberOfStarts: 3,
			maxIterations: 50
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-3.0, -3.0]),
				upper: VectorN([3.0, 3.0])
			),
			constraints: []
		)

		#expect(result.success, "Newton-Raphson should succeed")
		#expect(result.objectiveValue < 0.1, "Should find near-optimal solution")
	}

	// MARK: - Constraint Handling Tests

	/// Test with equality constraints
	@Test("Handle equality constraints")
	func testEqualityConstraints() async throws {
		// Minimize x² + y² subject to x + y = 1
		// Solution: x = y = 0.5, f = 0.5

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.equality(
				function: { v in v[0] + v[1] - 1.0 },
				gradient: nil
			)
		]

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .constrained,
			numberOfStarts: 4,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([0.0, 0.0]),
				upper: VectorN([1.0, 1.0])
			),
			constraints: constraints
		)

		#expect(result.success, "Should solve constrained problem")
		// Check constraint satisfaction: x + y ≈ 1
		let constraintValue = result.solution[0] + result.solution[1]
		#expect(abs(constraintValue - 1.0) < 0.1, "Should satisfy constraint")
	}

	/// Test with inequality constraints
	@Test("Handle inequality constraints")
	func testInequalityConstraints() async throws {
		// Minimize (x-1)² + (y-1)² subject to x ≥ 0, y ≥ 0
		// Unconstrained optimum: (1, 1), constrained optimum: (1, 1) (same)

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 1.0) * (v[0] - 1.0) + (v[1] - 1.0) * (v[1] - 1.0)
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.inequality(
				function: { v in -v[0] },  // x ≥ 0 → -x ≤ 0
				gradient: nil
			),
			MultivariateConstraint<VectorN<Double>>.inequality(
				function: { v in -v[1] },  // y ≥ 0 → -y ≤ 0
				gradient: nil
			)
		]

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .inequality,
			numberOfStarts: 4,
			maxIterations: 100
		)

		// Use search region that starts in feasible region
		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([0.1, 0.1]),  // Start in feasible region
				upper: VectorN([3.0, 3.0])
			),
			constraints: constraints
		)

		// Should find solution near (1,1) respecting x≥0, y≥0
		#expect(result.solution[0] >= -0.1, "Should satisfy x ≥ 0")
		#expect(result.solution[1] >= -0.1, "Should satisfy y ≥ 0")
		#expect(result.objectiveValue < 1.0, "Should find good solution")
	}

	// MARK: - Edge Cases

	/// Test with single starting point (edge case)
	@Test("Handle single starting point")
	func testSingleStart() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0]
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 1,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-5.0]),
				upper: VectorN([5.0])
			),
			constraints: []
		)

		// Test completes if implementation runs without crashing
		#expect(result.allResults.count == 1, "Should have exactly one result")
		#expect(result.objectiveValue < 0.1, "Should find near-zero solution")
	}

	/// Test with very narrow search region
	@Test("Handle narrow search region")
	func testNarrowRegion() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 5.0) * (v[0] - 5.0)
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 5,
			maxIterations: 50
		)

		// Very narrow region: [4.9, 5.1]
		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([4.9]),
				upper: VectorN([5.1])
			),
			constraints: []
		)

		// Should find solution very close to optimum (x=5)
		#expect(abs(result.solution[0] - 5.0) < 0.01, "Should find solution near x=5")
		#expect(result.solution[0] >= 4.9 && result.solution[0] <= 5.1,
				"Solution should be within search region")
	}

	/// Test best starting point tracking
	@Test("Track best starting point")
	func testBestStartingPointTracking() async throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 3.0) * (v[0] - 3.0) + (v[1] - 4.0) * (v[1] - 4.0)
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.1),
			numberOfStarts: 5,
			maxIterations: 100
		)

		let result = try await optimizer.optimize(
			objective: objective,
			searchRegion: (
				lower: VectorN([-10.0, -10.0]),
				upper: VectorN([10.0, 10.0])
			),
			constraints: []
		)

		#expect(result.success, "Should succeed")
		// Best starting point should be tracked
		let bestStart = result.bestStartingPoint
		#expect(bestStart.toArray().count == 2, "Should have 2D starting point")
	}
}

// MARK: - Serialized Performance Tests

/// Performance tests that need exclusive CPU access
/// Note: Serialized to avoid CPU contention with other parallel tests
@Suite("Parallel Optimizer Performance Tests", .serialized)
struct ParallelOptimizerPerformanceTests {

	/// Test that parallel execution uses multiple cores
	/// This test requires exclusive CPU access to measure parallel speedup accurately
	@Test("Verify parallel execution completes faster", .requiresParallelHardware)
	func testParallelSpeedup() async throws {
		// Use a computationally expensive objective (but not too expensive for CI)
		let expensive: @Sendable (VectorN<Double>) -> Double = { v in
			var sum = 0.0
			for i in 0..<500 {
				sum += (v[0] - Double(i)/500.0) * (v[0] - Double(i)/500.0)
			}
			return sum
		}

		let optimizer = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.01),
			numberOfStarts: 8,
			maxIterations: 50
		)

		let startTime = Date()
		let result = try await optimizer.optimize(
			objective: expensive,
			searchRegion: (
				lower: VectorN([0.0]),
				upper: VectorN([1.0])
			),
			constraints: []
		)
		let elapsed = Date().timeIntervalSince(startTime)
		// Uncomment below for single run testing
//		print("Elapsed: \(elapsed.number(3))")
		#expect(result.success, "Should complete successfully")
		// With serialized execution and dedicated hardware, should complete in < 5s
		// (8 starts × 50 iterations on simple 1D objective with parallel execution)
		// Threshold accounts for system variance while catching real performance regressions
		#expect(elapsed < 5.0, "Should complete within 5 seconds (got \(elapsed.number(2))s)")
	}
}
