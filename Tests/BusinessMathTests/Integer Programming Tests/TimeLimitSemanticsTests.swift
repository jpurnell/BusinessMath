//
//  TimeLimitSemanticsTests.swift
//  BusinessMath
//
//  What `timeLimit: 0` means, asserted rather than assumed.
//

import Testing
import Numerics
import TestSupport
@testable import BusinessMath

/// `timeLimit: 0` is documented as "no limit" on both integer-programming solvers.
///
/// It was implemented as "expire at the first node": the elapsed-time comparison was
/// unguarded, so `elapsed > .seconds(0)` is true the moment the clock advances at all.
/// Nothing caught it because the branch-and-cut solver — whose `timeLimit` *defaults*
/// to `0` — had no test constructing it, and every branch-and-bound test passed a
/// positive budget.
///
/// The consequence was not a slow solver but a silent one: a default-constructed
/// `BranchAndCutSolver` returned `success: false` after exactly one node, with the
/// objective at infinity, for every problem it was ever given.
@Suite("Time limit semantics")
struct TimeLimitSemanticsTests {

	/// A minimal integer program with a known answer: maximise `3x + 2y` subject to
	/// `x + y ≤ 4`, `x, y ∈ {0, 1, 2, 3, 4}`. The optimum is `x = 4, y = 0`, value 12.
	private static func knapsack() -> (
		objective: @Sendable (VectorN<Double>) -> Double,
		constraints: [MultivariateConstraint<VectorN<Double>>],
		spec: IntegerProgramSpecification
	) {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			-(3.0 * v[0] + 2.0 * v[1])   // negated: these solvers minimise
		}
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.linearInequality(coefficients: [1.0, 1.0], rhs: 4.0, sense: .lessOrEqual)
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)
		return (objective, constraints, IntegerProgramSpecification.allInteger(dimension: 2))
	}

	@Test("timeLimit 0 means no limit, not no work")
	func zeroTimeLimitIsUnbounded() throws {
		let problem = Self.knapsack()
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 1000,
			timeLimit: 0   // documented as "no limit"
		)

		let result = try solver.solve(
			objective: problem.objective,
			from: VectorN([2.0, 2.0]),
			subjectTo: problem.constraints,
			integerSpec: problem.spec,
			minimize: true
		)

		// The point of the test: a zero budget must not be a spent budget. Assert the
		// answer rather than the node count — this relaxation is integral at the root, so
		// solving in a single node is correct, and only the objective distinguishes
		// "solved immediately" from "gave up immediately".
		#expect(result.status != IntegerSolutionStatus.timeLimit)
		#expect(result.objectiveValue.isFinite)
		// 1e-6, not tighter: the nonlinear relaxation converges to about 7e-8 here, so a
		// 1e-9 bound would fail on a correct answer.
		#expect(approximatelyEqual(result.objectiveValue, -12.0, tolerance: 1e-6),
			"optimum is x=4, y=0 giving 12, negated for minimisation")
	}

	/// The branch-and-cut solver's `timeLimit` *defaults* to `0`, so this is the same
	/// defect reached without naming the parameter at all — which is how a caller
	/// would have met it.
	@Test("A default-constructed BranchAndCutSolver actually solves")
	func defaultBranchAndCutSolves() throws {
		let problem = Self.knapsack()
		let solver = BranchAndCutSolver<VectorN<Double>>()

		let result = try solver.solve(
			objective: problem.objective,
			from: VectorN([2.0, 2.0]),
			subjectTo: problem.constraints,
			integerSpec: problem.spec,
			minimize: true
		)

		#expect(result.success, "default construction returned no solution")
		#expect(result.objectiveValue.isFinite)
		#expect(approximatelyEqual(result.objectiveValue, -12.0, tolerance: 1e-6),
			"optimum is x=4, y=0 giving 3(4)+2(0)=12, negated for minimisation")
	}

	/// The counterweight: a genuinely positive budget must still be honoured, or the
	/// fix above would have removed the feature rather than corrected its zero case.
	/// There was no test asserting this at all, which is the reason the zero case went
	/// unnoticed — nothing exercised the branch either way.
	@Test("A positive time limit is still honoured")
	func positiveTimeLimitStillTerminates() throws {
		let problem = Self.knapsack()
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 1_000_000,
			timeLimit: 1e-9   // small enough that the first elapsed check exceeds it
		)

		let result = try solver.solve(
			objective: problem.objective,
			from: VectorN([2.0, 2.0]),
			subjectTo: problem.constraints,
			integerSpec: problem.spec,
			minimize: true
		)

		#expect(result.status == IntegerSolutionStatus.timeLimit)
	}
}
