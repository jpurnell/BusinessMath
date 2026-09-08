//
//  InequalityOptimizerExhaustionTests.swift
//  BusinessMath
//
//  The augmented Lagrangian stops when its schedule is exhausted.
//
//  ρ is the only lever the escalation path has: it starts at 10, multiplies tenfold
//  when feasibility lags, and caps at 1/ulp ≈ 4.5e15, so it saturates around the
//  sixteenth outer step. η and ω are derived from it and become constant at the same
//  moment, and the multipliers are not banked while the violation exceeds η. From
//  there every outer step repeats the last one, and on a genuinely infeasible problem
//  it repeated it eighty-odd more times before reporting a violation that had been
//  flat since the twentieth.
//
//  These tests pin both halves of that: that an infeasible problem now stops early,
//  and — the half that matters more — that nothing which was converging had its answer
//  or its iteration count changed by the stopping rule.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Inequality optimizer: schedule exhaustion")
struct InequalityOptimizerExhaustionTests {

	/// `minimize x² + y² − 5x − 5y` — the objective is irrelevant to feasibility here.
	private static let objective: @Sendable (VectorN<Double>) -> Double = { v in
		let quadratic = v[0] * v[0] + v[1] * v[1]
		let linear = 5.0 * v[0] + 5.0 * v[1]
		return quadratic - linear
	}

	/// The disc `x² + y² ≤ 9`, with its gradient.
	private static let disc: MultivariateConstraint<VectorN<Double>> = .inequality(
		function: { v in v[0] * v[0] + v[1] * v[1] - 9.0 },
		gradient: { v in VectorN<Double>([2.0 * v[0], 2.0 * v[1]]) }
	)

	private static func optimizer(
		outer: Int = 100, inner: Int = 1000
	) -> InequalityOptimizer<VectorN<Double>> {
		InequalityOptimizer<VectorN<Double>>(
			constraintTolerance: 1e-6, gradientTolerance: 1e-6,
			maxIterations: outer, maxInnerIterations: inner
		)
	}

	private static let start = VectorN<Double>([1.0, 1.0])

	// MARK: - The case the rule exists for

	@Test("An infeasible problem stops well before the outer budget")
	func infeasibleProblemStopsEarly() throws {
		// `x ≥ 4` cannot be met inside a disc of radius 3, so the violation plateaus
		// and no amount of penalty will move it.
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			Self.disc,
			.inequality(function: { v in 4.0 - v[0] }, gradient: nil)
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

		let result = try Self.optimizer().minimize(Self.objective, from: Self.start,
												   subjectTo: constraints)

		#expect(result.converged == false, "an infeasible problem must not report convergence")
		#expect(result.constraintViolation > 1e-6,
				"violation is \(result.constraintViolation), which would read as feasible")
		// Saturation lands near the sixteenth step and the rule allows three more.
		#expect(result.iterations < 30,
				"stopped after \(result.iterations) outer steps; the schedule was exhausted by ~20")
		#expect(result.iterations > 3,
				"stopped after only \(result.iterations) steps, before ρ could have saturated")
	}

	@Test("The early stop reports the same verdict the full budget would have")
	func earlyStopKeepsTheVerdict() throws {
		// A shorter outer budget must not change the answer, because the steps it
		// removes are the ones the rule already declines to take.
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			Self.disc,
			.inequality(function: { v in 4.0 - v[0] }, gradient: nil)
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

		let long = try Self.optimizer(outer: 100).minimize(Self.objective, from: Self.start,
														   subjectTo: constraints)
		let short = try Self.optimizer(outer: 40).minimize(Self.objective, from: Self.start,
														   subjectTo: constraints)
		#expect(long.iterations == short.iterations,
				"the stop is driven by the schedule, not the budget: \(long.iterations) vs \(short.iterations)")
		let gap: Double = abs(long.constraintViolation - short.constraintViolation)
		#expect(gap < 1e-12, "violation differed by \(gap) between budgets")
	}

	// MARK: - The half that matters more

	@Test("Problems that converge are untouched by the stopping rule")
	func convergingProblemsAreUnchanged() throws {
		// None of these should ever reach a capped ρ, so the rule must be invisible to
		// them — same answer, and the same small number of outer steps as before it
		// existed. The iteration counts are the measured ones: 4 and 6.
		let root: [MultivariateConstraint<VectorN<Double>>] =
			[Self.disc] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)
		let bounded: [MultivariateConstraint<VectorN<Double>>] = [
			Self.disc,
			.inequality(function: { v in v[0] - 2.0 }, gradient: nil)
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

		let unbounded = try Self.optimizer().minimize(Self.objective, from: Self.start,
													  subjectTo: root)
		#expect(unbounded.converged, "the disc problem should converge")
		#expect(unbounded.iterations == 4, "took \(unbounded.iterations) outer steps, not 4")
		let radius: Double = 3.0 / 2.0.squareRoot()
		let solution = unbounded.solution.toArray()
		#expect(abs(solution[0] - radius) < 1e-4, "x is \(solution[0]), not \(radius)")
		#expect(abs(solution[1] - radius) < 1e-4, "y is \(solution[1]), not \(radius)")

		let capped = try Self.optimizer().minimize(Self.objective, from: Self.start,
												   subjectTo: bounded)
		#expect(capped.converged, "the bounded problem should converge")
		#expect(capped.iterations == 6, "took \(capped.iterations) outer steps, not 6")
		#expect(abs(capped.solution.toArray()[0] - 2.0) < 1e-5,
				"x is \(capped.solution.toArray()[0]), not pinned at its bound of 2")
	}

	@Test("A feasible problem is never cut short while its violation is still falling")
	func feasibleProgressIsNotInterrupted() throws {
		// `x ≥ 3` meets the disc at the single point (3, 0). The feasible set has
		// measure zero, so stationarity stalls while the violation keeps creeping down
		// — and an earlier version of this rule, which watched the whole KKT residual,
		// stopped here at a violation of 2.8e-6 that would have reached 1e-7. That
		// flipped a feasible node to infeasible and pruned a subtree that should have
		// been searched.
		//
		// The rule now tests the violation alone, which is the quantity the caller's
		// verdict is made of, so this case runs on. It is slower than it could be, and
		// that is the right trade: a degenerate node costing time is a cost, a correct
		// node being pruned is a wrong answer.
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			Self.disc,
			.inequality(function: { v in 3.0 - v[0] }, gradient: nil)
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

		let result = try Self.optimizer(inner: 40).minimize(Self.objective, from: Self.start,
															subjectTo: constraints)
		#expect(result.constraintViolation <= 1e-6,
				"violation is \(result.constraintViolation); the point (3, 0) is feasible and must read as such")
		let solution = result.solution.toArray()
		#expect(abs(solution[0] - 3.0) < 1e-4, "x is \(solution[0]), not 3")
		#expect(abs(solution[1]) < 1e-2, "y is \(solution[1]), not 0")
	}
}
