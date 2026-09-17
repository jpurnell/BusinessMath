//
//  ConstraintPenaltyWeightTests.swift
//  BusinessMath
//
//  The constraint penalty weight, which was the literal 100 in five places.
//
//  Every constrained heuristic in this package handles `constraints:` by adding
//  `weight × violation²` to the objective and minimising the sum. That weight decides how
//  far outside the feasible region the answer is allowed to sit, and until this change it
//  was hardcoded — the same `100` in NelderMead, DifferentialEvolution, IslandModel,
//  SimulatedAnnealing and ParticleSwarmOptimization, with no way for a caller to change it
//  anywhere in the optimizer tier.
//
//  The fail-silent shape was the whole point. A penalty method does not report that it
//  settled outside the feasible region; it returned a point, and whether that point respected
//  the constraint depended on how the weight compared with the objective's curvature. A
//  caller minimising costs measured in millions against a constraint measured in units got a
//  violation the weight was far too small to suppress, and nothing in the result said so.
//
//  ## What this file used to assert, and why it no longer can
//
//  It asserted that raising the weight does not increase the violation, and that the weight
//  "must actually move the answer" — because a parameter that does not move the answer is not
//  a parameter. Both were true, and both described a solver that let a *tuning knob* decide
//  whether its answer was admissible.
//
//  That is now fixed at the source: a constrained solve runs an augmented-Lagrangian outer
//  loop and then corrects the point onto the feasible set, and the result reports the
//  violation it actually has. Measured on the fixture below, across weights from 1 to 1e10 and
//  objective scales from 1 to 1e6, every solve returns x = 1.0 with a violation of exactly
//  zero.
//
//  So the assertions invert. The property worth pinning is no longer "the weight controls the
//  violation" but **"the violation does not depend on the weight"** — feasibility is a
//  guarantee, not a setting. The config tests below are unchanged: the parameter still exists,
//  is still validated, and still conditions the inner search.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Constraint penalty weight")
struct ConstraintPenaltyWeightTests {

	/// Minimise `x²`, subject to `x ≥ 1`.
	///
	/// The unconstrained optimum is zero and is infeasible, so the penalised optimum sits
	/// strictly inside the violation — at `w/(1 + w)` for this problem, which approaches
	/// one from below as the weight rises and never reaches it. That is the behaviour a
	/// caller has to be able to tune, and at the shipped weight of 100 it lands at 0.990.
	static func objective(_ v: VectorN<Double>) -> Double {
		let x = v.toArray()[0]
		return x * x
	}

	static let constraint = MultivariateConstraint<VectorN<Double>>.inequality(
		function: { v in 1 - v.toArray()[0] },   // 1 − x ≤ 0  ⟺  x ≥ 1
		gradient: nil
	)

	static func violation(_ v: VectorN<Double>) -> Double {
		let x = v.toArray()[0]
		return Swift.max(0, 1 - x)
	}

	static let weights: [Double] = [1, 10, 100, 10_000]

	/// Feasibility does not depend on the weight, which is the inversion of what this asserted.
	///
	/// The old claim was that violation falls as the weight rises — true of a fixed-weight
	/// penalty, and the reason a caller had to guess a number that suited their objective's
	/// scale. Now every weight in the spread returns the same feasible point.
	@Test("Feasibility does not depend on the penalty weight")
	func feasibilityIsIndependentOfWeight() throws {
		for weight in Self.weights {
			let config = NelderMeadConfig(constraintPenaltyWeight: weight)
			let optimizer = NelderMead<VectorN<Double>>(config: config)
			let result = try optimizer.minimize(Self.objective,
												from: VectorN([0.0]),
												constraints: [Self.constraint])

			let violation: Double = Self.violation(result.solution)
			#expect(violation <= 1e-8,
					"weight \(weight) left a violation of \(violation) at \(result.solution.toArray())")
			#expect(result.terminationReason != .infeasible,
					"weight \(weight) reported infeasible at a violation of \(violation)")

			// And the result's own account of the violation matches the measured one, so a caller
			// reading `constraintViolation` is reading the truth rather than a default.
			let discrepancy: Double = abs(result.constraintViolation - violation)
			#expect(discrepancy < 1e-12,
					"weight \(weight): reported \(result.constraintViolation), measured \(violation)")
		}
	}

	@Test("The shipped default is still 100, so no existing caller moves")
	func defaultIsUnchanged() {
		// `isEqual(to:)` rather than `==`: this is an IEEE comparison chosen deliberately,
		// against a value that was written as a literal and never computed, and naming it
		// says so.
		let shipped: Double = 100
		#expect(NelderMeadConfig.default.constraintPenaltyWeight.isEqual(to: shipped))
		#expect(DifferentialEvolutionConfig.default.constraintPenaltyWeight.isEqual(to: shipped))
		#expect(SimulatedAnnealingConfig.default.constraintPenaltyWeight.isEqual(to: shipped))
		#expect(ParticleSwarmConfig.default.constraintPenaltyWeight.isEqual(to: shipped))
		#expect(IslandModelConfig.default.constraintPenaltyWeight.isEqual(to: shipped))
	}

	/// The sixth constrained heuristic, which the 2.17.0 parameterisation missed.
	///
	/// `GeneticAlgorithm` was not among the five because it had never used the literal
	/// `100` — its own hardcoded weight was `1000`, so it did not match what was being
	/// searched for, and it kept the literal for three more releases. Its default preserves
	/// that `1000` so no existing caller's results move.
	///
	/// **There is no principled reason for the two defaults to differ.** This expectation
	/// records the discrepancy rather than endorsing it: unifying them changes results for
	/// every constrained GA solve, which is a decision rather than a cleanup.
	@Test("The genetic algorithm takes the same parameter, defaulting to its own historical 1000")
	func geneticAlgorithmIsParameterisedToo() {
		let geneticShipped: Double = 1000
		#expect(GeneticAlgorithmConfig.default.constraintPenaltyWeight.isEqual(to: geneticShipped))

		// The same fallback contract as the other five: a weight that is not a positive
		// multiplier is refused rather than honoured. The seed is supplied only because
		// the config declares one — nothing here runs the algorithm — and an unseeded
		// construction is what the determinism checker flags.
		#expect(GeneticAlgorithmConfig(seed: 20260916, constraintPenaltyWeight: 0)
			.constraintPenaltyWeight.isEqual(to: geneticShipped))
		#expect(GeneticAlgorithmConfig(seed: 20260916, constraintPenaltyWeight: -5)
			.constraintPenaltyWeight.isEqual(to: geneticShipped))
		#expect(GeneticAlgorithmConfig(seed: 20260916, constraintPenaltyWeight: .nan)
			.constraintPenaltyWeight.isEqual(to: geneticShipped))
		#expect(GeneticAlgorithmConfig(seed: 20260916, constraintPenaltyWeight: .infinity)
			.constraintPenaltyWeight.isEqual(to: geneticShipped))

		let honoured: Double = 7.5
		#expect(GeneticAlgorithmConfig(seed: 20260916, constraintPenaltyWeight: honoured)
			.constraintPenaltyWeight.isEqual(to: honoured))
	}

	@Test("A weight that is not a positive multiplier falls back to the default")
	func invalidWeightsAreRefused() {
		// A zero weight removes the constraint silently, which is the one outcome worse
		// than a badly chosen weight: the caller asked for a constrained solve and would
		// get an unconstrained one back with no indication.
		let shipped: Double = 100
		#expect(NelderMeadConfig(constraintPenaltyWeight: 0).constraintPenaltyWeight.isEqual(to: shipped))
		#expect(NelderMeadConfig(constraintPenaltyWeight: -5).constraintPenaltyWeight.isEqual(to: shipped))
		#expect(NelderMeadConfig(constraintPenaltyWeight: .nan).constraintPenaltyWeight.isEqual(to: shipped))
		#expect(NelderMeadConfig(constraintPenaltyWeight: .infinity).constraintPenaltyWeight.isEqual(to: shipped))
		let honoured: Double = 2.5
		#expect(NelderMeadConfig(constraintPenaltyWeight: honoured).constraintPenaltyWeight.isEqual(to: honoured))
	}

	/// The scale mismatch that made the hardcoded weight a defect, now absorbed.
	///
	/// Same constraint, objective scaled by a million. At the shipped weight of 100 the penalty
	/// was negligible against the objective and the answer sat well outside feasibility — the
	/// original measurement here was a violation above 0.5, against a bound of 1.
	///
	/// The scale is what made it a defect rather than a preference: the answer depended on the
	/// units the caller had chosen, and no single default can be right for costs in dollars and
	/// costs in millions at once. Both now land on the bound exactly.
	@Test("A badly scaled objective no longer leaves a violation")
	func scaleMismatchNoLongerLeavesAViolation() throws {
		let scaled: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v.toArray()[0]
			let squared: Double = x * x
			return squared * 1_000_000
		}

		let shipped = NelderMead<VectorN<Double>>(config: NelderMeadConfig())
		let atDefault = try shipped.minimize(scaled, from: VectorN([0.0]),
											 constraints: [Self.constraint])
		let tuned = NelderMead<VectorN<Double>>(
			config: NelderMeadConfig(constraintPenaltyWeight: 1e10))
		let atTuned = try tuned.minimize(scaled, from: VectorN([0.0]),
										 constraints: [Self.constraint])

		let defaultViolation: Double = Self.violation(atDefault.solution)
		let tunedViolation: Double = Self.violation(atTuned.solution)

		#expect(defaultViolation <= 1e-8,
				"the shipped weight left \(defaultViolation) on an objective scaled by a million")
		#expect(tunedViolation <= 1e-8,
				"a weight matched to the scale left \(tunedViolation)")

		// And the reported objective is the one attainable at the bound: 1e6 × 1² = 1e6. An
		// infeasible answer reports *less* than this, which is what made the old behaviour
		// dangerous rather than merely imprecise.
		let attainable: Double = 1_000_000
		let shortfall: Double = attainable - atDefault.value
		#expect(shortfall < 1.0,
				"reported \(atDefault.value), below the attainable \(attainable)")
	}
}
