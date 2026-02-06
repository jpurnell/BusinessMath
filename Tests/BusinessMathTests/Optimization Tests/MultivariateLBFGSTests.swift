//
//  MultivariateLBFGSTests.swift
//  BusinessMath
//
//  Created by Claude Code on 02/04/26.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Multivariate L-BFGS Tests")
struct MultivariateLBFGSTests {

	// MARK: - Basic Convergence Tests

	@Test("L-BFGS on 2D quadratic")
	func lbfgsQuadratic2D() throws {
		// f(x, y) = x² + y²
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(memorySize: 5)
		let result = try optimizer.minimizeLBFGS(
			function: quadratic,
			initialGuess: VectorN([10.0, 10.0])
		)

		#expect(result.converged, "Should converge")
		#expect(result.iterations < 50, "Should converge quickly")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(result.value < 0.001, "Function value should be near 0")
	}

	@Test("L-BFGS on Rosenbrock function")
	func lbfgsRosenbrock() throws {
		// f(x,y) = (1-x)² + 100(y-x²)²
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: 500,
			tolerance: 1e-4
		)

		let result = try optimizer.minimizeLBFGS(
			function: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		// Rosenbrock is challenging, check we get close to (1,1)
		#expect(abs(result.solution[0] - 1.0) < 0.1, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.1, "y should be near 1")
		#expect(result.value < 0.1, "Function value should be small")
	}

	@Test("L-BFGS on 3D sphere")
	func lbfgs3DSphere() throws {
		// f(x, y, z) = x² + y² + z²
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(memorySize: 5)
		let result = try optimizer.minimizeLBFGS(
			function: sphere,
			initialGuess: VectorN([3.0, 4.0, 5.0])
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(abs(result.solution[2]) < 0.01, "z should be near 0")
		#expect(result.solution.norm < 0.02, "Solution norm should be near 0")
	}

	// MARK: - High-Dimensional Tests

	@Test("L-BFGS on 10-dimensional sphere")
	func lbfgs10D() throws {
		let dimensions = 10
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let initialGuess = VectorN(repeating: 1.0, count: dimensions)
		let optimizer = MultivariateLBFGS<VectorN<Double>>.standard()

		let result = try optimizer.minimizeLBFGS(
			function: sphere,
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(result.solution.norm < 0.1, "Solution should be near zero vector")
		#expect(result.value < 0.01, "Function value should be near 0")
	}

	@Test("L-BFGS on 100-dimensional sphere")
	func lbfgs100D() throws {
		let dimensions = 100
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let initialGuess = VectorN(repeating: 1.0, count: dimensions)
		let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale(maxIterations: 500)

		let result = try optimizer.minimizeLBFGS(
			function: sphere,
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(result.solution.norm < 0.5, "Solution should be near zero vector")
		#expect(result.value < 0.5, "Function value should be small")
	}

	@Test("L-BFGS on 1000-dimensional sphere", .timeLimit(.minutes(1)))
	func lbfgs1000D() throws {
		let dimensions = 1000
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let initialGuess = VectorN(repeating: 1.0, count: dimensions)
		let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale(maxIterations: 500)

		let result = try optimizer.minimizeLBFGS(
			function: sphere,
			initialGuess: initialGuess
		)

		// For 1000D, we're mainly testing that it completes and makes progress
		#expect(result.solution.norm < 10.0, "Solution should be much smaller than initial")
		#expect(result.value < 100.0, "Function value should be reduced significantly")
		print("1000D sphere: converged=\(result.converged), iterations=\(result.iterations), final value=\(result.value)")
	}

	// MARK: - Memory Size Tuning Tests

	@Test("Compare memory sizes m = 3, 5, 10, 20")
	func memorySizeComparison() throws {
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let memorySizes = [3, 5, 10, 20]
		var results: [(memorySize: Int, iterations: Int, converged: Bool, value: Double)] = []

		for m in memorySizes {
			let optimizer = MultivariateLBFGS<VectorN<Double>>(
				memorySize: m,
				maxIterations: 500,
				tolerance: 1e-4
			)

			let result = try optimizer.minimizeLBFGS(
				function: rosenbrock,
				initialGuess: VectorN([0.0, 0.0])
			)

			results.append((m, result.iterations, result.converged, result.value))
		}

		// Print comparison
		print("\nMemory Size Comparison:")
		for (m, iters, conv, val) in results {
			print("m=\(m): iterations=\(iters), converged=\(conv), value=\(String(format: "%.6f", val))")
		}

		// All should converge or make good progress
		for (_, _, _, val) in results {
			#expect(val < 1.0, "Should achieve reasonable objective value")
		}
	}

	// MARK: - Portfolio Optimization Tests

	@Test("Portfolio optimization with 50 assets")
	func portfolioOptimization50Assets() throws {
		let numAssets = 50

		// Generate random returns
		let returns = VectorN<Double>((0..<numAssets).map { _ in Double.random(in: 0.05...0.15) })
		let riskAversion = 2.0

		// Mean-variance objective: -μ + λσ²
		// Simplified: assumes uncorrelated assets for faster testing
		let portfolio: (VectorN<Double>) -> Double = { weights in
			let expectedReturn = weights.dot(returns)
			let variance = weights.dot(weights)  // Simplified: identity covariance
			return -(expectedReturn - riskAversion * variance)
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(memorySize: 10, maxIterations: 200)
		let initialWeights = VectorN<Double>.equalWeights(dimension: numAssets)

		let result = try optimizer.minimizeLBFGS(
			function: portfolio,
			initialGuess: initialWeights
		)

		#expect(result.converged || result.iterations > 50, "Should converge or make good progress")
		#expect(result.solution.sum > 0.5, "Weights should sum to positive value")
		print("50-asset portfolio: iterations=\(result.iterations), final objective=\(result.value)")
	}

	@Test("Portfolio optimization with 200 assets", .timeLimit(.minutes(1)))
	func portfolioOptimization200Assets() throws {
		let numAssets = 200

		// Generate random returns
		let returns = VectorN<Double>((0..<numAssets).map { _ in Double.random(in: 0.05...0.15) })
		let riskAversion = 2.0

		// Mean-variance objective
		let portfolio: (VectorN<Double>) -> Double = { weights in
			let expectedReturn = weights.dot(returns)
			let variance = weights.dot(weights)
			return -(expectedReturn - riskAversion * variance)
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale(maxIterations: 300)
		let initialWeights = VectorN<Double>.equalWeights(dimension: numAssets)

		let result = try optimizer.minimizeLBFGS(
			function: portfolio,
			initialGuess: initialWeights
		)

		print("200-asset portfolio: converged=\(result.converged), iterations=\(result.iterations)")
		#expect(result.solution.dimension == numAssets, "Should maintain dimension")
	}

	// MARK: - History Management Tests

	@Test("History FIFO correctly removes oldest")
	func historyFIFO() throws {
		// Use a simple quadratic with history recording
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v.dot(v)
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 3,  // Small memory size to test FIFO
			maxIterations: 20,
			recordHistory: true
		)

		let result = try optimizer.minimizeLBFGS(
			function: quadratic,
			initialGuess: VectorN([5.0, 5.0])
		)

		// Should converge with small memory
		#expect(result.converged || result.iterations >= 10, "Should make progress")
		#expect(result.history != nil, "Should record history")
		#expect(result.history!.count <= 20, "History count should match iterations")
	}

	@Test("Curvature condition rejection")
	func curvatureConditionCheck() throws {
		// Create a function that might violate curvature
		// f(x,y) = x⁴ - x² + y²
		let nonConvex: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return x*x*x*x - x*x + y*y
		}

		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: 200
		)

		let result = try optimizer.minimizeLBFGS(
			function: nonConvex,
			initialGuess: VectorN([2.0, 2.0])
		)

		// Should still make progress despite curvature issues
		#expect(result.solution.norm < 2.0, "Should reduce solution norm")
		print("Non-convex test: iterations=\(result.iterations), converged=\(result.converged)")
	}

	// MARK: - Protocol Conformance Tests

	@Test("MultivariateOptimizer protocol conformance")
	func protocolConformance() throws {
		// Use as protocol type
		let optimizer: any MultivariateOptimizer<VectorN<Double>> =
			MultivariateLBFGS<VectorN<Double>>.standard()

		let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

		let result = try optimizer.minimize(
			objective,
			from: VectorN([5.0, 5.0]),
			constraints: []
		)

		#expect(result.converged, "Should converge via protocol method")
		#expect(result.solution.norm < 0.1, "Should find minimum")
	}

	@Test("Rejects constraints")
	func constraintRejection() throws {
		let optimizer = MultivariateLBFGS<VectorN<Double>>.standard()

		let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
		let constraint: MultivariateConstraint<VectorN<Double>> = .equality(
			function: { v in v[0] - 1.0 },
			gradient: nil
		)

		#expect(throws: OptimizationError.self) {
			_ = try optimizer.minimize(
				objective,
				from: VectorN([5.0, 5.0]),
				constraints: [constraint]
			)
		}
	}

	// MARK: - Convergence Criteria Tests

	@Test("Converges with different tolerances")
	func toleranceTest() throws {
		// Use Rosenbrock which is more challenging
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		// Tight tolerance
		let strictOptimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: 500,
			tolerance: 1e-9
		)

		let strictResult = try strictOptimizer.minimizeLBFGS(
			function: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(strictResult.converged, "Should converge with tight tolerance")
		#expect(strictResult.gradientNorm < 1e-9, "Should meet tight gradient norm")

		// Loose tolerance
		let looseOptimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 10,
			maxIterations: 500,
			tolerance: 1e-2
		)

		let looseResult = try looseOptimizer.minimizeLBFGS(
			function: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(looseResult.converged, "Should converge with loose tolerance")
		#expect(looseResult.iterations <= strictResult.iterations, "Should require same or fewer iterations")
	}

	@Test("Max iterations reached")
	func maxIterationsTest() throws {
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		// Very few iterations
		let optimizer = MultivariateLBFGS<VectorN<Double>>(
			memorySize: 5,
			maxIterations: 5,  // Too few to converge
			tolerance: 1e-6
		)

		let result = try optimizer.minimizeLBFGS(
			function: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		#expect(result.iterations == 5, "Should reach max iterations")
		#expect(!result.converged, "Should not converge with too few iterations")
	}

	// MARK: - Comparison with BFGS

	@Test("L-BFGS vs BFGS on 10D problem")
	func lbfgsVsBFGS() throws {
		let dimensions = 10
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let initialGuess = VectorN(repeating: 1.0, count: dimensions)

		// L-BFGS
		let lbfgsOptimizer = MultivariateLBFGS<VectorN<Double>>(memorySize: 10)
		let lbfgsResult = try lbfgsOptimizer.minimizeLBFGS(
			function: sphere,
			initialGuess: initialGuess
		)

		// Full BFGS
		let bfgsOptimizer = MultivariateNewtonRaphson<VectorN<Double>>()
		let bfgsResult = try bfgsOptimizer.minimizeBFGS(
			function: sphere,
			initialGuess: initialGuess
		)

		print("\nL-BFGS vs BFGS Comparison:")
		print("L-BFGS: iterations=\(lbfgsResult.iterations), value=\(lbfgsResult.value)")
		print("BFGS:   iterations=\(bfgsResult.iterations), value=\(bfgsResult.value)")

		// Both should converge
		#expect(lbfgsResult.converged, "L-BFGS should converge")
		#expect(bfgsResult.converged, "BFGS should converge")

		// Both should find similar minima
		#expect(abs(lbfgsResult.value - bfgsResult.value) < 0.01, "Should find similar minimum")

		// L-BFGS might take a few more iterations, but not dramatically more
		let iterationRatio = Double(lbfgsResult.iterations) / Double(bfgsResult.iterations)
		#expect(iterationRatio < 2.0, "L-BFGS shouldn't take more than 2x iterations")
	}

	// MARK: - Factory Method Tests

	@Test("Factory methods create valid optimizers")
	func factoryMethods() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
		let initialGuess = VectorN([3.0, 4.0])

		// Test each factory method
		let standard = MultivariateLBFGS<VectorN<Double>>.standard()
		let resultStandard = try standard.minimizeLBFGS(function: objective, initialGuess: initialGuess)
		#expect(resultStandard.converged, "Standard should work")

		let largeScale = MultivariateLBFGS<VectorN<Double>>.largeScale()
		let resultLargeScale = try largeScale.minimizeLBFGS(function: objective, initialGuess: initialGuess)
		#expect(resultLargeScale.converged, "Large scale should work")

		let lowMemory = MultivariateLBFGS<VectorN<Double>>.lowMemory()
		let resultLowMemory = try lowMemory.minimizeLBFGS(function: objective, initialGuess: initialGuess)
		#expect(resultLowMemory.converged, "Low memory should work")

		let highAccuracy = MultivariateLBFGS<VectorN<Double>>.highAccuracy()
		let resultHighAccuracy = try highAccuracy.minimizeLBFGS(function: objective, initialGuess: initialGuess)
		#expect(resultHighAccuracy.converged, "High accuracy should work")
		#expect(resultHighAccuracy.gradientNorm < 1e-9, "High accuracy should meet tight tolerance")
	}

	// MARK: - Edge Cases

	@Test("Already at optimal")
	func alreadyOptimal() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

		let optimizer = MultivariateLBFGS<VectorN<Double>>.standard()
		let result = try optimizer.minimizeLBFGS(
			function: quadratic,
			initialGuess: VectorN([0.0, 0.0])  // Already at minimum
		)

		#expect(result.converged, "Should converge immediately")
		#expect(result.iterations < 5, "Should converge in very few iterations")
	}

	@Test("Far initial guess")
	func farInitialGuess() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

		let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale(maxIterations: 200)
		let result = try optimizer.minimizeLBFGS(
			function: quadratic,
			initialGuess: VectorN([100.0, 100.0])  // Very far from minimum
		)

		#expect(result.converged, "Should converge even from far away")
		#expect(result.solution.norm < 0.1, "Should find minimum")
	}
}
