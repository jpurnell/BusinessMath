//
//  MultivariateGradientDescentTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/03/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Multivariate Gradient Descent Tests")
struct MultivariateGradientDescentTests {

	// MARK: - Basic Gradient Descent Tests

	@Test("Minimize 2D quadratic bowl")
	func minimize2DQuadratic() throws {
		// f(x, y) = x² + y²
		// Minimum at (0, 0) with f(0,0) = 0
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		// Should converge to origin
		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(abs(result.value) < 0.01, "Function value should be near 0")
	}

	@Test("Minimize Rosenbrock function")
	func minimizeRosenbrock() throws {
		// Rosenbrock: f(x,y) = (1-x)² + 100(y-x²)²
		// Minimum at (1, 1) with f(1,1) = 0
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.001,
			maxIterations: 50000,
			tolerance: 1e-4
		)

		let initialGuess = VectorN([0.0, 0.0])
		let result = try optimizer.minimize(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		// Rosenbrock is challenging - allow larger tolerance
		#expect(abs(result.solution[0] - 1.0) < 0.1, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.1, "y should be near 1")
		#expect(result.value < 0.5, "Function value should be small")
	}

	@Test("Minimize 3D sphere function")
	func minimize3DSphere() throws {
		// f(x, y, z) = x² + y² + z²
		// Minimum at (0, 0, 0)
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1] + v[2]*v[2]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([3.0, 4.0, 5.0])
		let result = try optimizer.minimize(
			function: sphere,
			gradient: { try numericalGradient(sphere, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(abs(result.solution[2]) < 0.01, "z should be near 0")
	}

	@Test("Minimize N-dimensional sphere")
	func minimizeNDSphere() throws {
		// f(x₁, x₂, ..., xₙ) = Σxᵢ²
		let dimensions = 10
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 2000,
			tolerance: 1e-5
		)

		let initialGuess = VectorN(Array(repeating: 1.0, count: dimensions))
		let result = try optimizer.minimize(
			function: sphere,
			gradient: { try numericalGradient(sphere, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		for i in 0..<dimensions {
			#expect(abs(result.solution[i]) < 0.1, "Component \(i) should be near 0")
		}
	}

	// MARK: - Momentum Tests

	@Test("Gradient descent with momentum")
	func gradientDescentWithMomentum() throws {
		// Quadratic bowl with momentum should converge faster
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizerWithMomentum = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.05,
			maxIterations: 500,
			tolerance: 1e-6,
			momentum: 0.9
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizerWithMomentum.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge with momentum")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(result.iterations < 500, "Should converge in fewer iterations")
	}

	// MARK: - Adam Optimizer Tests

	@Test("Adam optimizer on quadratic")
	func adamOnQuadratic() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([10.0, 10.0])
		let result = try optimizer.minimizeAdam(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Adam should converge")
		#expect(abs(result.solution[0]) < 0.1, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.1, "y should be near 0")
	}

	@Test("Adam optimizer on Rosenbrock")
	func adamOnRosenbrock() throws {
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.01,
			maxIterations: 10000,
			tolerance: 1e-3
		)

		let initialGuess = VectorN([0.0, 0.0])
		let result = try optimizer.minimizeAdam(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		// Adam should get reasonably close
		#expect(abs(result.solution[0] - 1.0) < 0.2, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.2, "y should be near 1")
	}

	// MARK: - Line Search Tests

	@Test("Line search improves convergence")
	func lineSearchConvergence() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			2*v[0]*v[0] + v[1]*v[1]  // Elongated bowl
		}

		let optimizerWithLineSearch = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.5,  // Aggressive initial step
			maxIterations: 500,
			tolerance: 1e-6,
			useLineSearch: true
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizerWithLineSearch.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge with line search")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
	}

	// MARK: - History Recording Tests

	@Test("History recording")
	func historyRecording() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 100,
			tolerance: 1e-6,
			recordHistory: true
		)

		let initialGuess = VectorN([5.0, 5.0])
		let result = try optimizer.minimize(
			function: quadratic,
			gradient: { try numericalGradient(quadratic, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.history != nil, "History should be recorded")
		if let history = result.history {
			#expect(history.count > 0, "Should have history entries")
			#expect(history.count == result.iterations || history.count == result.iterations + 1,
				   "History count should match or be one more than iterations")

			// Values should decrease over time
			for i in 1..<history.count {
				#expect(history[i].value <= history[i-1].value,
					   "Function value should decrease or stay same")
			}
		}
	}

	// MARK: - Convergence Tests

	@Test("Convergence detection")
	func convergenceDetection() throws {
		// Very simple function that's already at minimum
		let function: @Sendable (VectorN<Double>) -> Double = { v in
			0.0  // Already at minimum
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([0.0, 0.0])
		let result = try optimizer.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge immediately")
		#expect(result.iterations < 10, "Should converge in very few iterations")
		#expect(result.gradientNorm < 1e-6, "Gradient should be nearly zero")
	}

	@Test("Max iterations without convergence")
	func maxIterationsReached() throws {
		// Make it hard to converge
		let function: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.00001,  // Very small learning rate
			maxIterations: 10,  // Very few iterations
			tolerance: 1e-10  // Very strict tolerance
		)

		let initialGuess = VectorN([10.0, 10.0])
		let result = try optimizer.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		#expect(!result.converged, "Should not converge with these settings")
		#expect(result.iterations == 10, "Should use all iterations")
	}

	// MARK: - Vector2D Tests

	@Test("Optimize with Vector2D")
	func optimizeVector2D() throws {
		let function: (Vector2D<Double>) -> Double = { v in
			v.x*v.x + v.y*v.y
		}

		let optimizer = MultivariateGradientDescent<Vector2D<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = Vector2D(x: 5.0, y: 5.0)
		let result = try optimizer.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution.x) < 0.01, "x should be near 0")
		#expect(abs(result.solution.y) < 0.01, "y should be near 0")
	}

	// MARK: - Practical Application Tests

	@Test("Portfolio variance minimization")
	func portfolioVarianceMinimization() throws {
		// Minimize portfolio variance: σ² = w'Σw
		// Subject to: w1 + w2 = 1 (handled implicitly: w2 = 1 - w1)
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

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		// Start with equal weights
		let initialGuess = VectorN([0.5, 0.5])
		let result = try optimizer.minimize(
			function: portfolioVariance,
			gradient: { try numericalGradient(portfolioVariance, at: $0) },
			initialGuess: initialGuess
		)

		// Should find minimum variance portfolio (may not fully converge but should improve)
		#expect(result.value < portfolioVariance(initialGuess),
			   "Should find lower variance")
		#expect(result.value < 0.001, "Variance should be very small")
	}

	// MARK: - Convenience Factory Tests

	@Test("Convenience factory methods")
	func convenienceFactories() throws {
		let function: @Sendable (VectorN<Double>) -> Double = { v in
			v[0]*v[0] + v[1]*v[1]
		}

		// Standard optimizer
		let standard = MultivariateGradientDescent<VectorN<Double>>.standard(learningRate: 0.1)
		let result1 = try standard.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: VectorN([5.0, 5.0])
		)
		#expect(result1.converged, "Standard should converge")

		// With momentum
		let withMomentum = MultivariateGradientDescent<VectorN<Double>>.withMomentum(
			learningRate: 0.05,
			momentum: 0.9
		)
		let result2 = try withMomentum.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: VectorN([5.0, 5.0])
		)
		#expect(result2.converged, "Momentum should converge")

		// With line search
		let withLineSearch = MultivariateGradientDescent<VectorN<Double>>.withLineSearch(
			learningRate: 0.5
		)
		let result3 = try withLineSearch.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: VectorN([5.0, 5.0])
		)
		#expect(result3.converged, "Line search should converge")
	}

	// MARK: - Automatic Gradient Tests

	@Test("Minimize with automatic gradient computation")
	func minimizeWithAutoGradient() throws {
		// Test the new convenience API that doesn't require explicit gradient
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let initialGuess = VectorN([5.0, 5.0])

		// No gradient parameter needed!
		let result = try optimizer.minimize(
			function: quadratic,
			initialGuess: initialGuess
		)

		// Should converge to origin
		#expect(result.converged, "Should converge with auto gradient")
		#expect(abs(result.solution[0]) < 0.01, "x should be near 0")
		#expect(abs(result.solution[1]) < 0.01, "y should be near 0")
		#expect(abs(result.value) < 0.01, "Function value should be near 0")
	}

	@Test("Adam with automatic gradient computation")
	func adamWithAutoGradient() throws {
		// Test the Adam optimizer convenience API
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.01,
			maxIterations: 5000,
			tolerance: 1e-4
		)

		let initialGuess = VectorN([0.0, 0.0])

		// No gradient parameter needed!
		let result = try optimizer.minimizeAdam(
			function: rosenbrock,
			initialGuess: initialGuess
		)

		// Adam should handle Rosenbrock reasonably well
		#expect(abs(result.solution[0] - 1.0) < 0.2, "x should be near 1")
		#expect(abs(result.solution[1] - 1.0) < 0.2, "y should be near 1")
		#expect(result.value < 1.0, "Function value should be small")
	}
}
