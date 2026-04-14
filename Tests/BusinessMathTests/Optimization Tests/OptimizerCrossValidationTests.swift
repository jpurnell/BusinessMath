//
//  OptimizerCrossValidationTests.swift
//  BusinessMath
//
//  Cross-validates optimization results between MultivariateGradientDescent
//  and MultivariateNewtonRaphson (BFGS) to ensure both find consistent minima.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Optimizer Cross-Validation Tests")
struct OptimizerCrossValidationTests {

	// MARK: - Shared Test Helpers

	/// Runs both gradient descent and Newton-Raphson BFGS on the same problem,
	/// then asserts both solutions agree within the given tolerance.
	private func crossValidate(
		function: @Sendable @escaping (VectorN<Double>) -> Double,
		initialGuess: VectorN<Double>,
		expectedMinimum: VectorN<Double>,
		expectedValue: Double,
		solutionTolerance: Double,
		valueTolerance: Double,
		gdLearningRate: Double = 0.01,
		gdMaxIterations: Int = 50_000,
		nrMaxIterations: Int = 1_000
	) throws {
		let gdOptimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: gdLearningRate,
			maxIterations: gdMaxIterations,
			tolerance: 1e-8,
			useLineSearch: true
		)

		let nrOptimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: nrMaxIterations,
			tolerance: 1e-8,
			useLineSearch: true
		)

		let gdResult = try gdOptimizer.minimize(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		let nrResult = try nrOptimizer.minimizeBFGS(
			function: function,
			gradient: { try numericalGradient(function, at: $0) },
			initialGuess: initialGuess
		)

		// Both should find solutions near the expected minimum
		let gdSolution = gdResult.solution.toArray()
		let nrSolution = nrResult.solution.toArray()
		let expected = expectedMinimum.toArray()

		for i in 0..<expected.count {
			#expect(
				abs(gdSolution[i] - expected[i]) < solutionTolerance,
				"GD solution[\(i)] = \(gdSolution[i]) not within \(solutionTolerance) of expected \(expected[i])"
			)
			#expect(
				abs(nrSolution[i] - expected[i]) < solutionTolerance,
				"NR solution[\(i)] = \(nrSolution[i]) not within \(solutionTolerance) of expected \(expected[i])"
			)
		}

		// Both function values should be near the expected minimum value
		#expect(
			abs(gdResult.value - expectedValue) < valueTolerance,
			"GD value \(gdResult.value) not within \(valueTolerance) of expected \(expectedValue)"
		)
		#expect(
			abs(nrResult.value - expectedValue) < valueTolerance,
			"NR value \(nrResult.value) not within \(valueTolerance) of expected \(expectedValue)"
		)

		// Cross-check: both optimizers should agree with each other
		for i in 0..<gdSolution.count {
			#expect(
				abs(gdSolution[i] - nrSolution[i]) < solutionTolerance * 2,
				"GD and NR disagree on solution[\(i)]: GD=\(gdSolution[i]), NR=\(nrSolution[i])"
			)
		}
	}

	// MARK: - Test Cases

	@Test("Cross-validate quadratic bowl: f(x,y) = x^2 + y^2")
	func crossValidateQuadraticBowl() throws {
		let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		try crossValidate(
			function: quadratic,
			initialGuess: VectorN([5.0, 5.0]),
			expectedMinimum: VectorN([0.0, 0.0]),
			expectedValue: 0.0,
			solutionTolerance: 0.01,
			valueTolerance: 0.01,
			gdLearningRate: 0.1
		)
	}

	@Test("Cross-validate Booth function: f(x,y) = (x+2y-7)^2 + (2x+y-5)^2")
	func crossValidateBoothFunction() throws {
		let booth: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			let term1 = (x + 2 * y - 7)
			let term2 = (2 * x + y - 5)
			return term1 * term1 + term2 * term2
		}

		try crossValidate(
			function: booth,
			initialGuess: VectorN([0.0, 0.0]),
			expectedMinimum: VectorN([1.0, 3.0]),
			expectedValue: 0.0,
			solutionTolerance: 0.01,
			valueTolerance: 0.01,
			gdLearningRate: 0.01
		)
	}

	@Test("Cross-validate Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2")
	func crossValidateRosenbrock() throws {
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x)
		}

		let gdOptimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.001,
			maxIterations: 100_000,
			tolerance: 1e-6,
			momentum: 0.9,
			useLineSearch: true
		)

		let nrOptimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 5_000,
			tolerance: 1e-8,
			useLineSearch: true
		)

		let initialGuess = VectorN([0.5, 0.5])

		let gdResult = try gdOptimizer.minimize(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		let nrResult = try nrOptimizer.minimizeBFGS(
			function: rosenbrock,
			gradient: { try numericalGradient(rosenbrock, at: $0) },
			initialGuess: initialGuess
		)

		let tolerance = 0.1
		#expect(abs(gdResult.solution[0] - 1.0) < tolerance, "GD x should be near 1.0")
		#expect(abs(gdResult.solution[1] - 1.0) < tolerance, "GD y should be near 1.0")
		#expect(abs(nrResult.solution[0] - 1.0) < tolerance, "NR x should be near 1.0")
		#expect(abs(nrResult.solution[1] - 1.0) < tolerance, "NR y should be near 1.0")

		#expect(gdResult.value < 0.1, "GD value should be near 0")
		#expect(nrResult.value < 0.01, "NR value should be near 0")
	}

	@Test("Cross-validate 5D sphere function: f(x) = sum(xi^2)")
	func crossValidate5DSphere() throws {
		let sphere: @Sendable (VectorN<Double>) -> Double = { v in
			let arr = v.toArray()
			return arr.reduce(0.0) { $0 + $1 * $1 }
		}

		try crossValidate(
			function: sphere,
			initialGuess: VectorN([3.0, -2.0, 1.0, -4.0, 2.0]),
			expectedMinimum: VectorN([0.0, 0.0, 0.0, 0.0, 0.0]),
			expectedValue: 0.0,
			solutionTolerance: 0.01,
			valueTolerance: 0.01,
			gdLearningRate: 0.05
		)
	}
}
