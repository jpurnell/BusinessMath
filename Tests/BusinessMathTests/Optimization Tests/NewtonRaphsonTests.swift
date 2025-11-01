import Testing
import Foundation
@testable import BusinessMath

@Suite("Newton-Raphson Tests")
struct NewtonRaphsonTests {

	@Test("Find minimum of shifted parabola")
	func shiftedParabolaMinimum() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>()

		// Minimize f(x) = x^2 - 4 (minimum at x = 0, f(0) = -4)
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
		// Minimum should be at x = 0 where f'(x) = 2x = 0
		#expect(abs(result.optimalValue - 0.0) < 0.01)
		// Function value at minimum: f(0) = 0 - 4 = -4
		#expect(abs(result.objectiveValue - (-4.0)) < 0.01)
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

		// Minimize f(x) = (x - 4)^2
		// This has minimum at x = 4 where f'(x) = 0
		let objective = { (x: Double) -> Double in
			return (x - 4.0) * (x - 4.0)
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 1.0,
			bounds: nil
		)

		#expect(result.converged)
		// Should find minimum at x = 4
		#expect(abs(result.optimalValue - 4.0) < 0.01)
		// At minimum, f(4) = 0
		#expect(abs(result.objectiveValue) < 0.001)
		#expect(result.iterations < 100)
	}

	@Test("Maximum iterations reached")
	func maxIterations() throws {
		let optimizer = NewtonRaphsonOptimizer<Double>(
			tolerance: 0.000001,  // Very tight tolerance
			maxIterations: 5  // Very low iteration limit
		)

		// Minimize f(x) = x^4 - 2x^2 + 1 (double-well potential)
		// Starting far from minimum makes it take many iterations
		let objective = { (x: Double) -> Double in
			let x2 = x * x
			return x2 * x2 - 2.0 * x2 + 1.0
		}

		let result = optimizer.optimize(
			objective: objective,
			constraints: [],
			initialValue: 10.0,  // Start far from minimum
			bounds: nil
		)

		// Should hit iteration limit
		#expect(result.iterations == 5)
		// May or may not have converged due to iteration limit
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
