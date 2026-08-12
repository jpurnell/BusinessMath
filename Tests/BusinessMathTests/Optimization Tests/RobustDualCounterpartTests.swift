//
//  RobustDualCounterpartTests.swift
//
//  Step 1 of the build order in project/plans/proposals/RobustScenarioGeneration.md.
//
//  Sampling an uncertainty set only ever bounds the worst case from below, so a sampled
//  "robust" answer can be optimistic. Dualization replaces the sample with the closed
//  form, and the test that tells them apart is not accuracy — it is whether the answer
//  still moves when the sample count does.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Robust Dual Counterpart")
struct RobustDualCounterpartTests {

	/// The `5.14` quick start. For `w ≥ 0` the worst return vector is `nominal − deviation`
	/// = `[0.08, 0.09, 0.07]`, so maximising the worst case puts everything on the best of
	/// those: `w = [0, 1, 0]` at `−0.09`. Derived by hand, not from a solver.
	private func quickStart(samples: Int) throws -> RobustResult<VectorN<Double>> {
		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: try BoxUncertaintySet(
				nominal: [0.10, 0.12, 0.08],
				deviations: [0.02, 0.03, 0.01]
			),
			samplesPerIteration: samples,
			maxIterations: 200,
			tolerance: 1e-6
		)

		let constraints: [MultivariateConstraint<VectorN<Double>>] =
			[.budgetConstraint] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

		return try optimizer.optimize(
			objective: { weights, returns in -weights.dot(VectorN(returns)) },
			nominalParameters: [0.10, 0.12, 0.08],
			initialSolution: VectorN([0.33, 0.33, 0.34]),
			constraints: constraints,
			minimize: true
		)
	}

	/// The closed form, reached without reference to how many scenarios were requested.
	@Test("reaches the closed-form worst case")
	func closedForm() throws {
		let result = try quickStart(samples: 100)

		#expect(abs(result.worstCaseObjective - (-0.09)) < 1e-6,
				"worst case is exactly −0.09, got \(result.worstCaseObjective)")

		let weights = result.solution.toArray()
		#expect(abs(weights[1] - 1.0) < 1e-4, "all weight belongs on asset 2, got \(weights)")
	}

	/// The property that separates a bound from a sample statistic.
	///
	/// Under sampling, more scenarios means a tighter lower bound on the worst case, so
	/// the reported number drifts with the count. Under dualization the uncertainty set is
	/// handled in closed form and the count is irrelevant — the answers must agree to
	/// solver precision, not merely to a few decimals.
	@Test("gives the same answer regardless of how many scenarios were asked for")
	func independentOfSampleCount() throws {
		let few = try quickStart(samples: 8)
		let many = try quickStart(samples: 400)

		#expect(abs(few.worstCaseObjective - many.worstCaseObjective) < 1e-9,
				"8 samples gave \(few.worstCaseObjective), 400 gave \(many.worstCaseObjective)")

		let a = few.solution.toArray()
		let b = many.solution.toArray()
		for i in 0..<a.count {
			#expect(abs(a[i] - b[i]) < 1e-6, "weight \(i) moved with the sample count: \(a[i]) vs \(b[i])")
		}
	}

	/// Sampling cannot see a worst case it did not draw. The dual form must not be
	/// optimistic about one.
	@Test("is not optimistic about the worst case")
	func notOptimistic() throws {
		let result = try quickStart(samples: 8)

		// Check the reported worst case against the true box vertex directly.
		let weights = result.solution.toArray()
		let worstReturns = [0.10 - 0.02, 0.12 - 0.03, 0.08 - 0.01]
		var trueWorst = 0.0
		for i in 0..<weights.count {
			trueWorst -= weights[i] * worstReturns[i]
		}

		#expect(result.worstCaseObjective >= trueWorst - 1e-6,
				"reported \(result.worstCaseObjective) is better than the true worst case \(trueWorst)")
	}

	/// A quadratic objective is not affine in the uncertain parameters, so the dual form
	/// does not apply and the general path must still handle it.
	@Test("falls through to the general path on a non-affine objective")
	func nonAffineFallsThrough() throws {
		let vols = [0.15, 0.10, 0.05]
		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: try BoxUncertaintySet(
				nominal: [0.10, 0.12, 0.08],
				deviations: [0.02, 0.03, 0.01]
			),
			samplesPerIteration: 50,
			maxIterations: 200,
			tolerance: 1e-6
		)

		let constraints: [MultivariateConstraint<VectorN<Double>>] =
			[.budgetConstraint] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

		let result = try optimizer.optimize(
			objective: { weights, returns in
				let w = weights.toArray()
				var variance = 0.0
				for i in 0..<w.count { variance += w[i] * w[i] * vols[i] * vols[i] }
				return -(weights.dot(VectorN(returns)) - 1.5 * variance)
			},
			nominalParameters: [0.10, 0.12, 0.08],
			initialSolution: VectorN([0.33, 0.33, 0.34]),
			constraints: constraints,
			minimize: true
		)

		let weights = result.solution.toArray()
		let total = weights.reduce(0, +)
		#expect(abs(total - 1.0) < 1e-3, "weights must still sum to 1, got \(total)")
		#expect(result.worstCaseObjective.isFinite)
	}
}
