import Testing
import Foundation
@testable import BusinessMath

@Suite("Gradient Descent Tests")
struct GradientDescentTests {

	@Test("Find minimum of simple quadratic")
	func simpleQuadratic() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.001,
			maxIterations: 1000,
			momentum: 0.0  // No momentum for simple test
		)

		// Minimize f(x) = x^2 (minimum at x = 0)
		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 10.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.optimalValue) < 0.1)
		#expect(result.objectiveValue < 0.01)
	}

	@Test("Find minimum with offset")
	func quadraticWithOffset() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.05,
			tolerance: 0.001,
			maxIterations: 1000
		)

		// Minimize f(x) = (x - 7)^2 (minimum at x = 7)
		let objective = { (x: Double) -> Double in
			let diff = x - 7.0
			return diff * diff
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 0.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.optimalValue - 7.0) < 0.2)
	}

	@Test("Gradient descent with momentum")
	func withMomentum() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.01,
			tolerance: 0.001,
			maxIterations: 500,
			momentum: 0.9
		)

		// Minimize f(x) = x^2
		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 10.0,
			bounds: nil
		)

		// With momentum, should converge faster
		#expect(result.converged)
		#expect(result.iterations < 500)
	}

	@Test("Learning rate too high - divergence")
	func learningRateTooHigh() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 2.0,  // Too high
			tolerance: 0.001,
			maxIterations: 100,
			momentum: 0.0
		)

		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 10.0,
			bounds: nil
		)

		// With too high learning rate, should either not converge
		// or produce a result far from optimal
		let isGoodResult = result.converged && abs(result.optimalValue) < 0.1
		#expect(!isGoodResult, "High learning rate should prevent good convergence")
	}

	@Test("Gradient descent with bounds")
	func withBounds() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.001,
			maxIterations: 1000
		)

		// Minimize f(x) = x^2 with bounds [-5, -1]
		// Should converge to -1 (closest to 0 within bounds)
		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: -3.0,
			bounds: (lower: -5.0, upper: -1.0)
		)

		#expect(result.optimalValue >= -5.0)
		#expect(result.optimalValue <= -1.0)
		#expect(abs(result.optimalValue - (-1.0)) < 0.2)
	}

	@Test("Iteration history recorded")
	func iterationHistory() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.001,
			maxIterations: 50
		)

		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 5.0,
			bounds: nil
		)

		#expect(result.history.count > 0)
		#expect(result.history.count == result.iterations)

		// Check history shows convergence
		let firstObjective = result.history[0].objective
		let lastObjective = result.history[result.history.count - 1].objective

		#expect(lastObjective < firstObjective)
	}

	@Test("Numerical gradient calculation")
	func numericalGradient() throws {
		let optimizer = GradientDescentOptimizer<Double>(
			learningRate: 0.1,
			tolerance: 0.01,
			maxIterations: 100
		)

		// For f(x) = x^3 - 6x^2 + 9x, f'(x) = 3x^2 - 12x + 9
		// This has minima, so the optimizer can find them
		let objective = { (x: Double) -> Double in
			return x * x * x - 6 * x * x + 9 * x
		}

		// Start from x = 0, should find minimum at x = 3
		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 0.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.optimalValue - 3.0) < 0.2)
	}
}
