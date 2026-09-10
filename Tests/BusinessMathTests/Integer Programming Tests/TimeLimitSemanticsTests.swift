//
//  TimeLimitSemanticsTests.swift
//  BusinessMath
//
//  What a solver's time budget means at each of the three values that mean
//  something different, asserted rather than assumed.
//

import Testing
import Numerics
import TestSupport
import Foundation
@testable import BusinessMath

/// A clock that advances a fixed step on every read.
///
/// ``ManualElapsedTimeSource`` holds still until told to move, which models "no time
/// passed" but cannot model "time passes while the solver works" — `solve` is synchronous,
/// so nothing can call `advance(by:)` in the middle of it. Stepping on read is the smallest
/// thing that lets these assertions be about the solver rather than about the scheduler.
// Justification: The single mutable stored property (reading) is protected by an NSLock; no unguarded access.
private final class SteppingElapsedTimeSource: ElapsedTimeSource, @unchecked Sendable {
	private var reading: ContinuousClock.Instant
	private let step: Duration
	private let lock = NSLock()

	init(step: Duration) {
		self.reading = ContinuousClock().now
		self.step = step
	}

	var now: ContinuousClock.Instant {
		lock.lock()
		defer { lock.unlock() }
		let current = reading
		reading = reading.advanced(by: step)
		return current
	}
}

/// `timeLimit` is `Duration?`, and `nil` is the absent budget.
///
/// It was `Double`, with `0` documented as "no limit" — a sentinel, and the one value a
/// caller is most likely to read as its exact opposite. It cost a defect in that opposite
/// direction: the elapsed comparison was unguarded, so `elapsed > .seconds(0)` was true the
/// moment the clock advanced at all, and a zero budget expired at the first node rather than
/// never. Nothing caught it, because the branch-and-cut solver — whose `timeLimit`
/// *defaulted* to `0` — had no test constructing it, and every branch-and-bound test passed
/// a positive budget.
///
/// The consequence was not a slow solver but a silent one: a default-constructed
/// `BranchAndCutSolver` returned `success: false` after exactly one node, objective at
/// infinity, for every problem it was ever given.
///
/// The guard that fixed it was correct and is now gone, because there is nothing left to
/// guard. `nil` removes the absent case from the expression, and `.zero` is free to mean
/// what it reads like. This suite pins all three readings so neither can drift back.
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

	private static func solve(
		timeLimit: Duration?,
		clockStep: Duration
	) throws -> IntegerOptimizationResult<VectorN<Double>> {
		let problem = knapsack()
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 1000,
			timeLimit: timeLimit,
			elapsedTime: SteppingElapsedTimeSource(step: clockStep)
		)
		return try solver.solve(
			objective: problem.objective,
			from: VectorN([2.0, 2.0]),
			subjectTo: problem.constraints,
			integerSpec: problem.spec,
			minimize: true
		)
	}

	@Test("nil means no limit, however much modelled time passes")
	func nilTimeLimitIsUnbounded() throws {
		// An hour of modelled time per clock read. Any finite budget expires on the first
		// check; `nil` has to survive it, or the type is not expressing "unlimited".
		//
		// Assert the answer rather than the node count — this relaxation is integral at
		// the root, so solving in a single node is correct, and only the objective
		// distinguishes "solved immediately" from "gave up immediately".
		let result = try Self.solve(timeLimit: nil, clockStep: .seconds(3600))

		#expect(result.status != IntegerSolutionStatus.timeLimit,
				"a nil budget reported \(result.status); nil means there is no deadline to miss")
		#expect(result.objectiveValue.isFinite)
		// 1e-6, not tighter: the nonlinear relaxation converges to about 7e-8 here, so a
		// 1e-9 bound would fail on a correct answer.
		#expect(approximatelyEqual(result.objectiveValue, -12.0, tolerance: 1e-6),
				"optimum is x=4, y=0 giving 12, negated for minimisation")
	}

	@Test("Duration.zero is a deadline already missed, not the absence of one")
	func zeroTimeLimitExpiresImmediately() throws {
		// The inversion the type change buys, and the reason it is worth a breaking
		// change rather than a doc fix. Under `Double`, this exact value meant
		// "unlimited"; a caller who wrote `timeLimit: 0` meaning "don't spend any time on
		// this" got the opposite of what they asked for, silently.
		let result = try Self.solve(timeLimit: .zero, clockStep: .seconds(1))

		#expect(result.status == IntegerSolutionStatus.timeLimit,
				"a zero budget reported \(result.status); zero time cannot be enough time")
	}

	@Test("A positive limit expires when tight and does not when generous")
	func positiveTimeLimitCutsBothWays() throws {
		// The counterweight, in both directions, because each alone is passed by a wrong
		// implementation. "A tight budget expires" is satisfied by a solver that expires on
		// every non-nil budget; "a generous budget completes" is satisfied by one that never
		// checks the clock at all. Only the pair says the deadline is real.
		//
		// There was no test asserting either before the sentinel defect, which is precisely
		// why it went unnoticed — nothing exercised the branch in any direction.
		let tight = try Self.solve(timeLimit: .nanoseconds(1), clockStep: .milliseconds(50))
		#expect(tight.status == IntegerSolutionStatus.timeLimit,
				"a 1ns budget under a 50ms-per-read clock reported \(tight.status)")

		// Same problem, same clock, a budget it cannot exhaust. Note this is a *positive*
		// budget, not nil: it separates "the deadline works" from "the deadline is absent".
		let generous = try Self.solve(timeLimit: .seconds(3600), clockStep: .milliseconds(50))
		#expect(generous.status != IntegerSolutionStatus.timeLimit,
				"an hour's budget reported \(generous.status) on a problem integral at the root")
		#expect(approximatelyEqual(generous.objectiveValue, -12.0, tolerance: 1e-6),
				"optimum is x=4, y=0 giving 12, negated for minimisation")
	}

	/// The branch-and-cut solver's budget is absent by default, so this reaches the
	/// contract without naming the parameter — which is how a caller would meet it.
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

	@Test("The defaults say which solver is bounded and which is not")
	func defaultsAreExplicit() {
		// The two disagreed before as `300.0` against a literal `0`, where only one of
		// those numbers meant what it looked like. The disagreement is deliberate; what
		// was wrong was that it was unreadable.
		let bound = BranchAndBoundSolver<VectorN<Double>>()
		#expect(bound.timeLimit == .seconds(300),
				"branch and bound's default budget is \(String(describing: bound.timeLimit))")

		let cut = BranchAndCutSolver<VectorN<Double>>()
		#expect(cut.timeLimit == nil,
				"branch and cut's default budget is \(String(describing: cut.timeLimit)), not nil")
	}
}
