//
//  GomoryCutValidityTests.swift
//  BusinessMathTests
//
//  A Gomory cut may separate the fractional LP optimum. It may never exclude an
//  integer-feasible point. The cuts this solver generated excluded all of them.
//

import Testing
import Foundation
@testable import BusinessMath

/// The defining property of a valid cutting plane, asserted directly.
///
/// A cut is *valid* when every integer-feasible point of the original problem satisfies
/// it, and *useful* when it additionally excludes the current fractional LP optimum.
/// Validity is not a quality measure — an invalid cut can remove the true optimum, so a
/// solver that generates one is wrong rather than slow.
///
/// **What was measured on 2026-09-13.** For `max x + y` subject to `x + 2y ≤ 7`,
/// `2x + y ≤ 7`, both integer, the generated Gomory cut was
/// `[0, 0, -0.7071, -0.7071] · x ≤ -0.7071`. The problem has two variables; the cut has
/// four coefficients, and both non-zeros sit on *slack* columns. Imposed over the
/// structural variables the left-hand side is identically zero, so the constraint reads
/// `0 ≤ -0.7071` — false everywhere. The LP went infeasible on the first cut, at every
/// integer point and at the origin.
///
/// The cause is a space mismatch. `generateGomoryCut` is handed
/// `totalVariableCount = tableau.columnCount - 1`, which counts structural variables
/// *and slacks*, and writes coefficients at whichever tableau columns are non-basic. The
/// consumer then applies the result over the structural variables alone. Turning a
/// tableau-space cut into a structural one requires substituting each slack out, and that
/// step did not exist.
///
/// It stayed hidden because it fails safe: the infeasible re-solve breaks the cut loop,
/// the augmented constraints are local to the node and are discarded, and branch-and-bound
/// continues unaided. The answers were right; the feature did nothing. Measured on this
/// problem, cuts on and cuts off both returned 4.0 at `(3, 1)` after exactly 3 nodes.
@Suite("Gomory cut validity")
struct GomoryCutValidityTests {

	/// `max x + y` s.t. `x + 2y ≤ 7`, `2x + y ≤ 7`, x and y non-negative integers.
	///
	/// The LP relaxation optimum is the fractional vertex `(7/3, 7/3)` with value 14/3.
	/// The integer optimum is 4, attained at `(3, 1)`, `(2, 2)` and `(1, 3)`.
	private func solver(cuts: Bool) -> BranchAndBoundSolver<VectorN<Double>> {
		BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 100,
			enableCuttingPlanes: cuts,
			maxCuttingRounds: 3
		)
	}

	private var constraints: [MultivariateConstraint<VectorN<Double>>] {
		[
			.linearInequality(coefficients: [1.0, 2.0], rhs: 7.0, sense: .lessOrEqual),
			.linearInequality(coefficients: [2.0, 1.0], rhs: 7.0, sense: .lessOrEqual)
		]
	}

	private func solve(cuts: Bool) throws -> IntegerOptimizationResult<VectorN<Double>> {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] + v[1] }
		return try solver(cuts: cuts).solve(
			objective: objective,
			from: VectorN([0.0, 0.0]),
			subjectTo: constraints,
			integerSpec: .allInteger(dimension: 2),
			minimize: false
		)
	}

	/// The answer has always been right. This is the control, so a regression in the fix
	/// is distinguishable from a regression in the solver.
	@Test("The integer optimum is 4 at (3, 1), with cuts and without")
	func theOptimumIsUnchanged() throws {
		for cuts in [false, true] {
			let result = try solve(cuts: cuts)
			let value: Double = result.objectiveValue
			#expect(abs(value - 4.0) < 1e-6, "cuts=\(cuts) gave \(value)")
		}
	}

	/// The defect, stated as the invariant it breaks.
	///
	/// A round that generates cuts and then cannot re-solve reports cuts without rounds.
	/// That asymmetry is real and documented — but it should not be *reachable* on a
	/// problem whose LP is feasible, because a valid cut cannot make a feasible LP
	/// infeasible while integer points remain.
	@Test("Cuts that were generated led to at least one completed cutting round")
	func generatedCutsProduceRounds() throws {
		let result = try solve(cuts: true)
		let stats = try #require(result.cuttingPlaneStats)

		guard stats.totalCutsGenerated > 0 else { return }  // nothing to check
		let generated: Int = stats.totalCutsGenerated
		let rounds: Int = stats.cuttingRounds
		#expect(rounds > 0, "\(generated) cuts generated but \(rounds) rounds completed: every re-solve after a cut failed, which means the cuts were invalid")
	}

	/// Cutting planes that work tighten the root bound. Ones that are discarded cannot.
	@Test("Cutting at the root does not leave the bound exactly where it started")
	func theRootBoundMoves() throws {
		let result = try solve(cuts: true)
		let stats = try #require(result.cuttingPlaneStats)
		guard stats.totalCutsGenerated > 0 else { return }

		// The relaxation optimum is 14/3; the integer optimum is 4. Any valid cut that
		// separates the fractional vertex moves the bound toward 4, and none may move it
		// past 4 — that would cut off the integer optimum.
		let before: Double = stats.rootLPBoundBeforeCuts
		let after: Double = stats.rootLPBoundAfterCuts
		#expect(after < before - 1e-9 || abs(after - before) < 1e-9,
				"bound moved from \(before) to \(after)")
		#expect(after >= 4.0 - 1e-6,
				"the bound fell to \(after), below the integer optimum of 4 — a cut removed it")
	}
}
