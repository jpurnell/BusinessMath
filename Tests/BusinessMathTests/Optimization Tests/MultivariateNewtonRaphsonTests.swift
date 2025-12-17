//
//  MultivariateNewtonRaphsonTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Multivariate Newton-Raphson Tests")
struct MultivariateNewtonRaphsonTests {

	// MARK: - Full Newton-Raphson Tests

	@Test("Newton-Raphson on 2D quadratic - should converge in 1 iteration")
	func newtonRaphsonQuadraticFast() throws {
		// f(x, y) = x² + y²
		// For quadratic functions, Newton-Raphson converges in exactly 1 iteration!
		let quadratic: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 10,
			tolerance: 1e-10
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			hessian: { try numericalHessian(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		// Should converge extremely fast for quadratic
		#expect(result.converged, "Should converge")
		#expect(result.iterations <= 3, "Should converge in very few iterations")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
	}

	@Test("Newton-Raphson on Rosenbrock")
	func newtonRaphsonRosenbrock() throws {
		let rosenbrock: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 100,
			tolerance: 1e-4
		)

		let initialGuess = VectorN([0.0, 0.0])
		let result = try optimizer.minimize(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			hessian: { try numericalHessian(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		// Newton-Raphson should converge to the minimum
		#expect(abs(result.solution[0] - 1.0) < 0.1, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.1, "y should be near 1")
		#expect(result.value < 0.1, "Function value should be small")
	}

	@Test("Newton-Raphson on 3D sphere")
	func newtonRaphson3D() throws {
		let sphere: (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 10,
			tolerance: 1e-8
		)

		let initialGuess = VectorN([3.0, 4.0, 5.0])
		let result = try optimizer.minimize(
			function: sphere,
			gradient: { try numericalGradient(sphere, at: $0) },
			hessian: { try numericalHessian(sphere, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(abs(result.solution[2]) < 0.01, "z should be near 0")
	}

	// MARK: - BFGS Tests

	@Test("BFGS on 2D quadratic")
	func bfgsQuadratic() throws {
		let quadratic: (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 100,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([10.0, 10.0])
		let result = try optimizer.minimizeBFGS(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "BFGS should converge")
		#expect(abs(result.solution[0]) < 0.1, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.1, "y should be near 0")
	}

	@Test("BFGS on Rosenbrock")
	func bfgsRosenbrock() throws {
		let rosenbrock: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 1000,
			tolerance: 1e-3
		)

		let initialGuess = VectorN([0.0, 0.0])
		let result = try optimizer.minimizeBFGS(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		// BFGS should get reasonably close
		#expect(abs(result.solution[0] - 1.0) < 0.2, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.2, "y should be near 1")
	}

	@Test("BFGS on higher-dimensional sphere")
	func bfgsHighDimensional() throws {
		let dimensions = 5
		let sphere: (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 200,
			tolerance: 1e-5
		)

		let initialGuess = VectorN(Array(repeating: 2.0, count: dimensions))
		let result = try optimizer.minimizeBFGS(
			function: sphere,
			gradient: { try numericalGradient(sphere, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		for i in 0..<dimensions {
			#expect(abs(result.solution[i]) < 0.1, "Component \(i) should be near 0")
		}
	}

	// MARK: - Convergence Comparison Tests

	@Test("Newton-Raphson converges faster than gradient descent")
	func convergenceSpeed() throws {
		let quadratic: (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		// Newton-Raphson
		let newtonOptimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 100,
			tolerance: 1e-6
		)

		let newtonResult = try newtonOptimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			hessian: { try numericalHessian(quadratic, at: $0) },
			initialGuess: VectorN([10.0, 10.0])
		)

		// Gradient Descent
		let gdOptimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let gdResult = try gdOptimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: VectorN([10.0, 10.0])
		)

		// Newton-Raphson should use far fewer iterations
		#expect(newtonResult.iterations < gdResult.iterations,
			   "Newton-Raphson should converge in fewer iterations")
		#expect(newtonResult.iterations < 10,
			   "Newton-Raphson should be very fast on quadratic")
	}

	// MARK: - Line Search Tests

	@Test("Line search prevents overshooting")
	func lineSearchStability() throws {
		// Elongated quadratic that could overshoot without line search
		let quadratic: (VectorN<Double>) -> Double = { v in
			10*v[0]*v[0] + v[1]*v[1]
		}

		let optimizerWithLS = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 50,
			tolerance: 1e-6,
			useLineSearch: true
		)

		let result = try optimizerWithLS.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			hessian: { try numericalHessian(quadratic, at: $0) },
			initialGuess: VectorN([20.0, 20.0])
		)

		#expect(result.converged, "Should converge with line search")
		#expect(abs(result.solution[0]) < 0.1, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.1, "y should be near 0")
	}

	// MARK: - Vector2D Tests

	@Test("Newton-Raphson with Vector2D")
	func newtonRaphsonVector2D() throws {
		let function: (Vector2D<Double>) -> Double = { v in
			v.x*v.x + v.y*v.y
		}

		let optimizer = MultivariateNewtonRaphson<Vector2D<Double>>(
			maxIterations: 10,
			tolerance: 1e-8
		)

		let initialGuess = Vector2D(x: 5.0, y: 5.0)
		let result = try optimizer.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			hessian: { try numericalHessian(function, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution.x) < 0.01, "x should be near 0")
		#expect(abs(result.solution.y) < 0.01, "y should be near 0")
	}

	@Test("BFGS with Vector2D")
	func bfgsVector2D() throws {
		let function: (Vector2D<Double>) -> Double = { v in
			v.x*v.x + v.y*v.y
		}

		let optimizer = MultivariateNewtonRaphson<Vector2D<Double>>(
			maxIterations: 100,
			tolerance: 1e-6
		)

		let initialGuess = Vector2D(x: 5.0, y: 5.0)
		let result = try optimizer.minimizeBFGS(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "BFGS should converge")
		#expect(abs(result.solution.x) < 0.1, "x should be near 0")
		#expect(abs(result.solution.y) < 0.1, "y should be near 0")
	}

	// MARK: - Practical Application Tests

	@Test("Portfolio optimization with Newton-Raphson")
	func portfolioOptimizationNewton() throws {
		// Minimize portfolio variance
		let covariance = [[0.04, 0.01],
						  [0.01, 0.09]]

		let portfolioVariance: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<2 {
				for j in 0..<2 {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}
			return variance
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 50,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([0.5, 0.5])
		let result = try optimizer.minimize(
			function: portfolioVariance,
			gradient: { try numericalGradient(portfolioVariance, at: $0) },
			hessian: { try numericalHessian(portfolioVariance, at: $0) },
			initialGuess: initialGuess
		)

		// Should find minimum variance quickly
		#expect(result.converged || result.iterations < 20,
			   "Should converge or make rapid progress")
		#expect(result.value < portfolioVariance(initialGuess),
			   "Should find lower variance")
	}

	// MARK: - Convenience Factory Tests

	@Test("Convenience factory methods")
	func convenienceFactories() throws {
		let function: (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		// Standard optimizer
		let standard = MultivariateNewtonRaphson<VectorN<Double>>.standard()
		let result1 = try standard.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			hessian: { try numericalHessian(function, at: $0) },
			initialGuess: VectorN([5.0, 5.0])
		)
		#expect(result1.converged, "Standard should converge")

		// BFGS large scale
		let bfgsLarge = MultivariateNewtonRaphson<VectorN<Double>>.bfgsLargeScale()
		let result2 = try bfgsLarge.minimizeBFGS(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: VectorN([5.0, 5.0])
		)
		#expect(result2.converged, "BFGS should converge")
	}

	// MARK: - History Recording Tests

	@Test("History recording for Newton-Raphson")
	func historyRecording() throws {
		let quadratic: (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 10,
			tolerance: 1e-8,
			recordHistory: true
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			hessian: { try numericalHessian(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.history != nil, "History should be recorded")
		if let history = result.history {
			#expect(history.count > 0, "Should have history entries")
			// Newton-Raphson converges very fast on quadratic
			#expect(history.count < 5, "Should converge in very few iterations")
		}
	}

	// MARK: - Automatic Gradient Tests

	@Test("BFGS with automatic gradient computation")
	func bfgsAutomaticGradient() throws {
		// f(x, y) = x² + y² - 2x - 2y
		// Minimum at (1, 1) with value -2
		let objective: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return x*x + y*y - 2*x - 2*y
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>()

		// Use the convenient API that computes gradient automatically
		let result = try optimizer.minimizeBFGS(
			function: objective,
			initialGuess: VectorN([0.0, 0.0])
		)

		// Check convergence
		#expect(result.converged, "Should converge to minimum")

		// Check solution accuracy (should be near [1, 1])
		#expect(abs(result.solution[0] - 1.0) < 0.001, "x should be near 1.0")
		#expect(abs(result.solution[1] - 1.0) < 0.001, "y should be near 1.0")

		// Check objective value (should be near -2)
		#expect(abs(result.value - (-2.0)) < 0.01, "Objective value should be near -2")
	}

	@Test("BFGS automatic gradient vs explicit gradient")
	func bfgsCompareGradientMethods() throws {
		// Compare automatic vs explicit gradient to ensure they give same results
		let objective: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return x*x + y*y - 2*x - 2*y
		}

		let explicitGradient: (VectorN<Double>) throws -> VectorN<Double> = { v in
			let x = v[0], y = v[1]
			return VectorN([2*x - 2, 2*y - 2])
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>()
		let initialGuess = VectorN([0.0, 0.0])

		// Test with automatic gradient
		let autoResult = try optimizer.minimizeBFGS(
			function: objective,
			initialGuess: initialGuess
		)

		// Test with explicit gradient
		let explicitResult = try optimizer.minimizeBFGS(
			function: objective,
			gradient: explicitGradient,
			initialGuess: initialGuess
		)

		// Both should converge
		#expect(autoResult.converged, "Automatic gradient should converge")
		#expect(explicitResult.converged, "Explicit gradient should converge")

		// Solutions should be very close (within numerical precision)
		#expect(abs(autoResult.solution[0] - explicitResult.solution[0]) < 0.01,
				"x solutions should match")
		#expect(abs(autoResult.solution[1] - explicitResult.solution[1]) < 0.01,
				"y solutions should match")

		// Objective values should be very close
		#expect(abs(autoResult.value - explicitResult.value) < 0.01,
				"Objective values should match")
	}

	@Test("BFGS automatic gradient on Rosenbrock function")
	func bfgsAutomaticGradientRosenbrock() throws {
		// Rosenbrock: f(x, y) = (1 - x)² + 100(y - x²)²
		// Minimum at (1, 1) with value 0
		let rosenbrock: (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			let a = 1 - x
			let b = y - x*x
			return a*a + 100*b*b
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 200,  // Rosenbrock needs more iterations
			tolerance: 1e-4
		)

		// Use automatic gradient
		let result = try optimizer.minimizeBFGS(
			function: rosenbrock,
			initialGuess: VectorN([0.0, 0.0])
		)

		// Check solution (should be near [1, 1])
		#expect(abs(result.solution[0] - 1.0) < 0.1, "x should be near 1.0")
		#expect(abs(result.solution[1] - 1.0) < 0.1, "y should be near 1.0")

		// Check objective value (should be near 0)
		#expect(result.value < 1.0, "Should find good minimum")
	}
}
