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
	@Test("reports a gap rather than claiming success when the budget runs out")
	func budgetExhaustion() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in abs(v[0] - 3.0) }

		let master = CuttingPlaneMaster<VectorN<Double>>(maxRounds: 2, tolerance: 1e-12)
		let result = try master.minimize(objective, from: VectorN([10.0]), subjectTo: [])

		#expect(!result.converged, "two rounds cannot certify 1e-12")
		#expect(result.optimalityGap.isFinite, "the gap must be reported, got \(result.optimalityGap)")
		#expect(result.optimalityGap > 0)
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
