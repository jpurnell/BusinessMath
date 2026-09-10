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
//  The fail-silent shape is the whole point. A penalty method does not report that it
//  settled outside the feasible region; it returns a point, and whether that point respects
//  the constraint depends on how the weight compares with the objective's curvature. A
//  caller minimising costs measured in millions against a constraint measured in units gets
//  a violation the weight is far too small to suppress, and nothing in the result says so.
//
//  **The property, and it is what makes the parameter meaningful:** raising the weight must
//  not increase the constraint violation. It is monotone. A parameter that does not move
//  the answer is not a parameter, and this is the assertion a stub cannot pass — it holds
//  across a spread of weights rather than at one.
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

	@Test("NelderMead exposes the weight, and violation is monotone in it")
	func nelderMeadWeightIsMonotone() throws {
		var violations: [Double] = []
		for weight in Self.weights {
			let config = NelderMeadConfig(constraintPenaltyWeight: weight)
			let optimizer = NelderMead<VectorN<Double>>(config: config)
			let result = try optimizer.minimize(Self.objective,
												from: VectorN([0.0]),
												constraints: [Self.constraint])
			violations.append(Self.violation(result.solution))
		}
		for index in 1..<violations.count {
			let heavier: Double = violations[index]
			let lighter: Double = violations[index - 1]
			let slack: Double = lighter + 1e-9
			let note = "weight \(Self.weights[index]) gave \(heavier), previous gave \(lighter)"
			#expect(heavier <= slack, "\(note)")
		}
		let first = try #require(violations.first)
		let last = try #require(violations.last)
		#expect(last < first, "the weight must actually move the answer: \(first) → \(last)")
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

	@Test("A weight far too small for the objective's scale leaves a large violation")
	func scaleMismatchIsTheFailureBeingFixed() throws {
		// The reason the hardcoded 100 was a defect rather than a preference. Same
		// constraint, objective scaled by a million: at weight 100 the penalty is
		// negligible against the objective and the answer sits well outside feasibility.
		let scaled: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v.toArray()[0]
			let squared: Double = x * x
			return squared * 1_000_000
		}
		let shipped = NelderMead<VectorN<Double>>(config: NelderMeadConfig())
		let poor = try shipped.minimize(scaled, from: VectorN([0.0]),
										constraints: [Self.constraint])
		let tuned = NelderMead<VectorN<Double>>(
			config: NelderMeadConfig(constraintPenaltyWeight: 1e10))
		let better = try tuned.minimize(scaled, from: VectorN([0.0]),
										constraints: [Self.constraint])

		let poorViolation = Self.violation(poor.solution)
		let betterViolation = Self.violation(better.solution)
		#expect(poorViolation > 0.5, "at the shipped weight: \(poorViolation)")
		#expect(betterViolation < poorViolation,
				"a weight matched to the scale does better: \(betterViolation)")
	}
}
