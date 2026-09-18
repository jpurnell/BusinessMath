//
//  CuttingPlaneMasterTests.swift
//
//  RED phase for project/plans/proposals/NonsmoothOptimization.md.
//
//  Every expected value here is derived independently of the solver — by hand for the
//  kink cases, and from the newsvendor critical ratio for the motivating one — so a
//  passing test means the answer is right, not merely stable.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Cutting Plane Master")
struct CuttingPlaneMasterTests {

	// MARK: - The canonical kink

	/// `minimize |x − 3|` from `x = 10`.
	///
	/// The optimum is exactly at the kink, which is where a smooth-gradient method
	/// stalls: the subgradient has magnitude 1 on both sides and never shrinks, so a
	/// step sized by the gradient cannot settle.
	@Test("minimizes an absolute value, whose optimum is the kink")
	func absoluteValue() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			abs(v[0] - 3.0)
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 200, tolerance: 1e-6)
		let result = try master.minimize(
			objective,
			from: VectorN([10.0]),
			subjectTo: []
		)

		#expect(result.converged, "should certify the kink, not stall on it")
		#expect(abs(result.solution[0] - 3.0) < 1e-4, "optimum is x = 3, got \(result.solution[0])")
		#expect(result.objectiveValue < 1e-4, "objective at the optimum is 0, got \(result.objectiveValue)")
	}

	/// `minimize max(2x, −x) + x²/10` — a kink that is not at a stationary point of
	/// either piece, so the answer cannot be recovered by following one branch.
	@Test("minimizes a max of two lines against a smooth term")
	func maxOfLines() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0]
			let piecewise = Swift.max(2.0 * x, -x)
			return piecewise + (x * x) / 10.0
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 200, tolerance: 1e-6)
		let result = try master.minimize(objective, from: VectorN([5.0]), subjectTo: [])

		// Below zero the objective is −x + x²/10, decreasing until x = 5 — outside the
		// branch. Above zero it is 2x + x²/10, increasing. So the minimum is the kink
		// at x = 0, value 0.
		#expect(result.converged)
		#expect(abs(result.solution[0]) < 1e-3, "optimum is x = 0, got \(result.solution[0])")
	}

	// MARK: - The motivating case

	/// The newsvendor from `productionPlanningWithUncertainDemand`.
	///
	/// Reference: the critical-ratio quantile, computed without reference to any solver.
	/// `Cu = (25 − 10) + 5 = 20`, `Co = 10 + 2 = 12`, ratio `20/32 = 0.625`, so
	/// `q* = 100 + 20·z(0.625) = 106.4`.
	@Test("solves the newsvendor, whose objective is piecewise linear")
	func newsvendor() throws {
		let price = 25.0, unitCost = 10.0, shortagePenalty = 5.0, excessCost = 2.0
		let demandMean = 100.0, demandStdDev = 20.0

		// A fixed demand sample, so the test measures the optimizer rather than a draw.
		var generator = DeterministicRNG(seed: 20260812)
		let demands: [Double] = (0..<400).map { _ in
			let (_, z): (Double, Double) = boxMullerSeed(using: &generator)
			return Swift.max(0, demandMean + demandStdDev * z)
		}

		// Expected profit, negated because the master minimizes.
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let quantity = v[0]
			var total = 0.0
			for demand in demands {
				let sold = Swift.min(quantity, demand)
				let shortage = Swift.max(0, demand - quantity)
				let excess = Swift.max(0, quantity - demand)
				let profit = sold * price - quantity * unitCost
					- shortage * shortagePenalty - excess * excessCost
				total += profit
			}
			return -total / Double(demands.count)
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 300, tolerance: 1e-6)
		let result = try master.minimize(
			objective,
			from: VectorN([110.0]),
			subjectTo: [.linearInequality(coefficients: [1.0], rhs: 0.0, sense: .greaterOrEqual)]
		)

		#expect(result.converged, "should converge, not walk to the clamped boundary")
		#expect(
			abs(result.solution[0] - 106.4) < 2.0,
			"critical ratio gives q* = 106.4, got \(result.solution[0])"
		)
	}

	// MARK: - Contracts

	/// A smooth problem must still reach the same answer — the master is an addition,
	/// not a replacement.
	@Test("agrees with the smooth path on a smooth problem")
	func smoothAgreement() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let dx = v[0] - 2.0
			let dy = v[1] - 3.0
			return dx * dx + dy * dy
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 300, tolerance: 1e-8)
		let result = try master.minimize(objective, from: VectorN([0.0, 0.0]), subjectTo: [])

		#expect(abs(result.solution[0] - 2.0) < 1e-3, "got \(result.solution[0])")
		#expect(abs(result.solution[1] - 3.0) < 1e-3, "got \(result.solution[1])")
	}

	/// Exhausting the budget must report the gap, never a bare number presented as an
	/// answer. This is the fail-silent contract the proposal makes explicit.
	///
	/// ## Why two rounds now report an infinite gap
	///
	/// This test asserted `optimalityGap.isFinite` after two rounds, and that finite number came
	/// from the defect the trust-region tests above describe: the bound was read off the model
	/// minimised *within the trust region*, which always produces a number and never produces a
	/// bound.
	///
	/// With the bound taken over the caller's constraints instead, two rounds of `|x − 3|` from
	/// `x = 10` cut twice on the same side — both with slope `+1` — so the model is the line
	/// `x − 3`, which is unbounded below. There is genuinely nothing proved, and `∞` says so.
	/// A finite gap there would be the old falsehood in a new place.
	///
	/// Both halves of the contract are still covered, because both still happen: the gap is
	/// infinite while nothing has been proved, and finite and positive once the cuts bracket the
	/// kink but the tolerance is still out of reach. Five rounds is where that changeover falls
	/// for this objective — measured, not chosen.
	@Test("reports a gap rather than claiming success when the budget runs out")
	func budgetExhaustion() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - 3.0) }

		// Two rounds: every cut is on the descending side, so the model has no floor.
		let starved = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 2, tolerance: 1e-12)
		let unproven = try starved.minimize(objective, from: VectorN([10.0]), subjectTo: [])

		#expect(!unproven.converged, "two rounds cannot certify 1e-12")
		#expect(unproven.optimalityGap == .infinity,
				"""
				nothing bounds the model from below after two one-sided cuts; \
				the gap is \(unproven.optimalityGap)
				""")

		// Five rounds: the cuts now bracket the kink, so a real bound exists — and it is still
		// far too loose to certify 1e-12, which is what makes this the reported-gap case.
		let budgeted = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 5, tolerance: 1e-12)
		let bounded = try budgeted.minimize(objective, from: VectorN([10.0]), subjectTo: [])

		#expect(!bounded.converged, "five rounds cannot certify 1e-12 either")
		#expect(bounded.optimalityGap.isFinite,
				"the cuts bracket the kink, so the gap must be a number, got \(bounded.optimalityGap)")
		#expect(bounded.optimalityGap > 0, "an uncertified solve has a positive gap")

		// And the bound behind that gap must still be a bound: the minimum of |x − 3| is 0.
		let claimedFloor = bounded.objectiveValue - bounded.optimalityGap
		#expect(claimedFloor <= 1e-5,
				"the solve claims nothing beats \(claimedFloor), but the minimum is 0")
	}

	// MARK: - Non-convexity

	/// A non-convex objective must not come back certified.
	///
	/// `f(x) = (x² − 1)²` is the double well: minima at ±1, a local maximum at 0. A cut
	/// taken at the origin is flat at `f(0) = 1`, and the model built from it therefore
	/// sits *above* the function at `x = 1`, where `f = 0`. That is a proof the cut is not
	/// an under-estimator, and so that the objective is not convex — which the solve must
	/// notice rather than report a gap that bounds nothing.
	@Test("refuses to certify a non-convex objective")
	func nonConvexIsNotCertified() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let inner = v[0] * v[0] - 1.0
			return inner * inner
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 60, tolerance: 1e-6, initialTrustRegion: 2.0)
		let result = try master.minimize(objective, from: VectorN([0.0]), subjectTo: [])

		#expect(!result.isCertified, "the model rises above the objective here; that is not convex")
		#expect(!result.converged, "an uncertified solve must not claim convergence")

		// It should still be useful — the best point seen beats where it started.
		#expect(result.objectiveValue < 1.0, "should improve on f(0) = 1, got \(result.objectiveValue)")
	}

	/// The convex cases must not be tripped by the detector's tolerance.
	@Test("certifies a convex objective")
	func convexIsCertified() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - 3.0) }

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 200, tolerance: 1e-6)
		let result = try master.minimize(objective, from: VectorN([10.0]), subjectTo: [])

		#expect(result.isCertified, "an absolute value is convex; nothing should disprove it")
		#expect(result.converged)
	}

	// MARK: - The certificate has to be a certificate

	/// An optimum beyond the initial trust region must not be reported as proven.
	///
	/// ## The defect this was written for
	///
	/// `lowerBound` was folded from `solveMaster`'s `modelValue` — the model minimised **over
	/// the trust region**. That is not a lower bound on the objective's minimum. It is the
	/// model's minimum over a box the method drew itself, and restricting a minimisation can
	/// only raise its value, so the quantity being used as a floor was systematically too high.
	///
	/// The consequence was not a loose bound. With the default trust region of 100 and the
	/// optimum at `x = 1000`, the first round cuts at `x = 0`, the master walks to the corner at
	/// `x = 100`, and the model's value there *equals* the objective's — the cut is exact along
	/// the whole descending branch. So `gap = 0`, and the method returned:
	///
	/// | | |
	/// |---|---|
	/// | `solution` | 100 |
	/// | `objectiveValue` | 900 |
	/// | `optimalityGap` | **0.0** |
	/// | `converged` | **true** |
	/// | `isCertified` | **true** |
	/// | `iterations` | 1 |
	///
	/// A claim of proven optimality, after one round, 900 away from the answer. Every existing
	/// test in this file placed its optimum inside the first trust region, so none of them could
	/// see it.
	///
	/// The targets below straddle the default half-width of 100 deliberately: 50 was always
	/// right, and is here so the fix is shown not to have broken the case that worked.
	@Test("An optimum outside the first trust region is still found", arguments: [50.0, 150.0, 400.0, 1000.0])
	func anOptimumBeyondTheTrustRegionIsStillFound(target: Double) throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - target) }

		let master = CuttingPlaneMaster<VectorN<Double>>()
		let result = try master.minimize(objective, from: VectorN([0.0]), subjectTo: [])

		let located = result.solution[0]
		#expect(abs(located - target) < 1e-3,
				"the kink is at \(target); the solve stopped at \(located)")
		#expect(result.objectiveValue < 1e-3,
				"the objective is 0 at the kink, the solve reports \(result.objectiveValue)")
	}

	/// The gap must bound the distance to a minimum that is known independently.
	///
	/// This is the law the type's documentation asserts — "the gap between it and the best point
	/// seen is a certificate rather than a guess" — stated as something that can fail. For each
	/// objective the true minimum is known by construction, so `objectiveValue − optimalityGap`
	/// is a claimed lower bound that can be checked against it directly.
	///
	/// Where the bound is *tight* is not the interesting part. Where it is **above** the true
	/// minimum, the certificate is false, and a caller reading `converged` has been told
	/// something that is not so.
	///
	/// The slack allowed is the solve tolerance: cuts are built from finite differences, so the
	/// bound inherits their error and can sit a few ulps of the objective's scale on the wrong
	/// side. It cannot sit 900 on the wrong side.
	@Test("The lower bound really is below the true minimum", arguments: [
		(0.0, 300.0),     // far kink, the case that was broken
		(0.0, 40.0),      // near kink, inside the first trust region
		(500.0, 12.5)     // start beyond the optimum, so the walk runs the other way
	])
	func theLowerBoundIsBelowTheTrueMinimum(start: Double, target: Double) throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - target) }

		let master = CuttingPlaneMaster<VectorN<Double>>()
		let result = try master.minimize(objective, from: VectorN([start]), subjectTo: [])

		// The true minimum of |x − target| is 0, by construction.
		let trueMinimum = 0.0
		let claimedLowerBound = result.objectiveValue - result.optimalityGap
		let slack = 1e-5
		#expect(claimedLowerBound <= trueMinimum + slack,
				"""
				the solve claims nothing beats \(claimedLowerBound), 				but the minimum is \(trueMinimum)
				""")
	}

	/// Same, with the optimum pinned by a constraint rather than by the objective's shape.
	///
	/// Every other test in this file passes `subjectTo: []`, so the constrained branch of
	/// `solveMaster` — the rows it builds from the caller's linearised constraints, sitting
	/// alongside the cuts and the trust-region box — had no answer to be checked against.
	///
	/// `min |x − 3|` subject to `x ≤ 1` has its optimum pushed off the kink and onto the
	/// constraint boundary: `x = 1`, value 2. Reversed, `x ≥ 5` gives `x = 5`, value 2.
	@Test("A constraint that moves the optimum off the kink is honoured", arguments: [
		(1.0, ConstraintSense.lessOrEqual, 1.0),
		(5.0, ConstraintSense.greaterOrEqual, 5.0)
	])
	func aConstraintMovesTheOptimum(rhs: Double, sense: ConstraintSense, expected: Double) throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - 3.0) }

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 200, tolerance: 1e-6)
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.linearInequality(coefficients: [1.0], rhs: rhs, sense: sense)
		]
		let result = try master.minimize(objective, from: VectorN([10.0]), subjectTo: constraints)

		#expect(abs(result.solution[0] - expected) < 1e-4,
				"the constraint puts the optimum at \(expected), the solve found \(result.solution[0])")
		#expect(abs(result.objectiveValue - 2.0) < 1e-4,
				"|\(expected) − 3| is 2, the solve reports \(result.objectiveValue)")

		// And the point it returns must satisfy the constraint it was given.
		let residual = sense == .lessOrEqual ? result.solution[0] - rhs : rhs - result.solution[0]
		#expect(residual <= 1e-6, "the answer breaches its own constraint by \(residual)")
	}

	/// Same seed, same answer — the sampled subgradients must not make the optimum move.
	@Test("is deterministic across repeated runs")
	func determinism() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			Swift.max(abs(v[0] - 1.0), abs(v[1] + 2.0))
		}

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 200, tolerance: 1e-6)
		let first = try master.minimize(objective, from: VectorN([7.0, 7.0]), subjectTo: [])
		let second = try master.minimize(objective, from: VectorN([7.0, 7.0]), subjectTo: [])

		#expect(first.solution[0] == second.solution[0], "run to run drift in x")
		#expect(first.solution[1] == second.solution[1], "run to run drift in y")
	}
}
