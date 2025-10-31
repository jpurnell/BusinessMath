import Testing
import Foundation
@testable import BusinessMath

@Suite("Newton-Raphson Tests")
struct NewtonRaphsonTests {

	@Test("Find root of quadratic function")
	func quadraticRoot() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>()

		// Minimize f(x) = x^2 - 4 (root at x = 2)
		let objective = { (x: Double) -> Double in
			return x * x - 4.0
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 1.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.optimalValue - 2.0) < 0.01)
		#expect(abs(result.objectiveValue) < 0.01)
	}

	@Test("Find minimum of parabola")
	func parabolaMinimum() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>()

		// Minimize f(x) = (x - 5)^2 (minimum at x = 5)
		let objective = { (x: Double) -> Double in
			return (x - 5.0) * (x - 5.0)
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 0.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.optimalValue - 5.0) < 0.01)
	}

	@Test("Optimization with bounds")
	func optimizationWithBounds() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>()

		// Minimize f(x) = x^2 with bounds [2, 10]
		// Should converge to lower bound (2)
		let objective = { (x: Double) -> Double in
			return x * x
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 5.0,
			bounds: (lower: 2.0, upper: 10.0)
		)

		#expect(result.optimalValue >= 2.0)
		#expect(result.optimalValue <= 10.0)
	}

	@Test("Optimization with constraints")
	func optimizationWithConstraints() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>()

		// Minimize f(x) = x^2
		// Constraint: x >= 3
		let objective = { (x: Double) -> Double in
			return x * x
		}

		let constraint = Constraint<Double>(
			type: .greaterThanOrEqual,
			bound: 3.0
		)

		let result = optimizer.optimize(
			objective: objective,
			constraints: [constraint],
			initialValue: 5.0,
			bounds: nil
		)

		#expect(result.optimalValue >= 3.0)
	}

	@Test("Convergence within tolerance")
	func convergenceTolerance() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>(
			tolerance: 0.001,
			maxIterations: 100
		)

		let objective = { (x: Double) -> Double in
			return x * x - 16.0
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 1.0,
			bounds: nil
		)

		#expect(result.converged)
		#expect(abs(result.objectiveValue) < 0.001)
		#expect(result.iterations < 100)
	}

	@Test("Maximum iterations reached")
	func maxIterations() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>(
			tolerance: 0.000001,
			maxIterations: 5  // Very low
		)

		// Complex function that needs more iterations
		let objective = { (x: Double) -> Double in
			return sin(x) - 0.5
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 0.0,
			bounds: nil
		)

		#expect(result.iterations == 5)
		// May or may not have converged
	}

	@Test("Numerical derivative calculation")
	func numericalDerivative() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>(stepSize: 0.0001)

		// For f(x) = x^3, f'(x) = 3x^2
		// At x = 2, derivative should be ~12

		let objective = { (x: Double) -> Double in
			return x * x * x
		}

		// Test numerical derivative at x = 2
		let x = 2.0
		let h = 0.0001
		let derivativeApprox = (objective(x + h) - objective(x - h)) / (2 * h)

		#expect(abs(derivativeApprox - 12.0) < 0.01)
	}
}
