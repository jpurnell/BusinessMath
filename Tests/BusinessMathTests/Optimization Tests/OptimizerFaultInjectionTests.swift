//
//  OptimizerFaultInjectionTests.swift
//  BusinessMath
//
//  Fault injection tests verifying the MultivariateGradientDescent optimizer
//  handles pathological inputs gracefully (NaN regions, ill-conditioning,
//  divergence, constant functions).
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Optimizer Fault Injection Tests")
struct OptimizerFaultInjectionTests {

	@Test("Function with NaN region terminates gracefully")
	func functionWithNaNRegion() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] > 0 ? v[0] * v[0] : Double.nan
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 100
		)

		do {
			let result = try optimizer.minimize(
				function: objective,
				initialGuess: VectorN([2.0])
			)
			#expect(result.iterations >= 0)
		} catch {
			#expect(error is OptimizationError, "Should throw OptimizationError, not crash")
		}
	}

	@Test("Function with Infinity region terminates gracefully")
	func functionWithInfinityRegion() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] < -1e10 ? Double.infinity : v[0] * v[0]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.01,
			maxIterations: 200
		)

		let result = try optimizer.minimize(
			function: objective,
			initialGuess: VectorN([-100.0])
		)
		#expect(result.iterations >= 0)
	}

	@Test("Extremely ill-conditioned function terminates with valid result")
	func illConditionedFunction() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			1e6 * v[0] * v[0] + 1e-6 * v[1] * v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 1e-7,
			maxIterations: 500
		)

		let result = try optimizer.minimize(
			function: objective,
			initialGuess: VectorN([1.0, 1.0])
		)

		#expect(result.value.isFinite, "Result value should be finite")
		#expect(result.solution.toArray().allSatisfy({ $0.isFinite }), "Solution should be finite")
	}

	@Test("Constant function converges immediately with zero gradient")
	func constantFunction() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { _ in 42.0 }

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 0.1,
			maxIterations: 1000,
			tolerance: 1e-6
		)

		let result = try optimizer.minimize(
			function: objective,
			initialGuess: VectorN([5.0, 5.0])
		)

		#expect(result.converged, "Should converge since gradient is zero everywhere")
		#expect(result.iterations <= 1, "Should converge in 0 or 1 iterations")
		#expect(result.value == 42.0, "Function value should be 42.0")
	}

	@Test("Very large learning rate does not crash")
	func veryLargeLearningRate() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let optimizer = MultivariateGradientDescent<VectorN<Double>>(
			learningRate: 1000.0,
			maxIterations: 100
		)

		let result = try optimizer.minimize(
			function: objective,
			initialGuess: VectorN([1.0, 1.0])
		)
		#expect(result.iterations >= 0)
	}
}
