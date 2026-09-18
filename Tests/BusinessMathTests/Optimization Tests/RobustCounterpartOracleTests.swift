//
//  RobustCounterpartOracleTests.swift
//  BusinessMathTests
//
//  An independent answer for the robust counterpart, which had none.
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// `RobustOptimizer.optimize` checked against answers derived without it.
///
/// ## Why this suite exists
///
/// `linearRobustCounterpart` carries a cognitive complexity of 59 and does something
/// consequential: it detects that a robust problem is secretly a linear program, builds that
/// program — splitting free variables, lifting the epigraph, translating the caller's
/// `g(x) ≤ 0` into simplex rows — and solves it by a completely different route from the
/// general augmented-Lagrangian path. A caller cannot tell which route ran.
///
/// The existing suites check that it returns *something* and that the something is feasible.
/// Nothing said what the answer is. So this supplies two oracles that owe the implementation
/// nothing:
///
/// 1. **A hand-derived minimax.** Two affine scenarios on a simplex reduce to one variable, and
///    the minimax sits where the two lines cross. Pencil and paper, exact.
/// 2. **A grid.** The pointwise maximum of affine functions is convex, so a dense sweep of the
///    feasible box bounds the true optimum from above, tightly. The solver must not be worse
///    than a grid search, and — the check that actually bites — the value it *reports* must be
///    the value its *point* achieves.
///
/// The third is not an oracle but a consistency law: `worstCaseObjective` is the worst over the
/// sampled scenarios at `solution`, so recomputing it from the returned point must reproduce it.
/// A robust optimizer that reports a number its own answer does not attain is the fail-silent
/// case this library is not allowed to produce.
@Suite("The robust counterpart against an independent answer")
struct RobustCounterpartOracleTests {

	typealias Vec = VectorN<Double>

	/// `max` over scenarios at a point, computed here rather than asked for.
	static func worstCase(
		_ point: [Double],
		_ scenarios: [[Double]],
		minimising: Bool
	) -> Double {
		var worst = minimising ? -Double.infinity : Double.infinity
		for omega in scenarios {
			let value = zip(omega, point).reduce(0.0) { $0 + $1.0 * $1.1 }
			worst = minimising ? Swift.max(worst, value) : Swift.min(worst, value)
		}
		return worst
	}

	/// The objective every case here uses: a dot product, linear in `x` for each fixed `ω`.
	///
	/// Linear on purpose — that is the branch under test. A curved objective would be refused
	/// by `validateLinearModel` and routed to the general solver, testing something else.
	static let dotProduct: @Sendable (Vec, [Double]) -> Double = { x, omega in
		zip(omega, x.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 }
	}

	// MARK: - 1. The answer, by hand

	/// Two scenarios on the unit simplex, where the minimax is a crossing point.
	///
	/// Minimise `max(2x₀ + 6x₁, 8x₀ + 2x₁)` subject to `x₀ + x₁ = 1`, `x ≥ 0`.
	///
	/// Substituting `x₁ = 1 − x₀` collapses both scenarios to lines in one variable:
	///
	/// | scenario | as a function of `x₀` | at `x₀ = 0` | at `x₀ = 1` |
	/// |---|---|---|---|
	/// | `(2, 6)` | `6 − 4x₀` | 6 | 2 |
	/// | `(8, 2)` | `2 + 6x₀` | 2 | 8 |
	///
	/// One falls, one rises, so their maximum is minimised where they meet:
	/// `6 − 4x₀ = 2 + 6x₀` gives `x₀ = 0.4`, and both sides equal **4.4**.
	///
	/// No tolerance is chosen here beyond the solver's own: 4.4 is the answer, not an
	/// approximation of one, and the linear path solves it by the simplex method rather than by
	/// iterating toward it.
	@Test("A two-scenario minimax lands on the crossing point")
	func twoScenarioMinimaxIsTheCrossing() throws {
		let scenarios = [[2.0, 6.0], [8.0, 2.0]]
		let set = try DiscreteUncertaintySet(points: scenarios)
		let optimizer = RobustOptimizer<Vec>(uncertaintySet: set)

		let constraints: [MultivariateConstraint<Vec>] = [
			.linearEquality(coefficients: [1.0, 1.0], rhs: 1.0),
			.linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)
		]

		let result = try optimizer.optimize(
			objective: Self.dotProduct,
			nominalParameters: [5.0, 4.0],
			initialSolution: Vec([0.5, 0.5]),
			constraints: constraints,
			minimize: true
		)

		let x = result.solution.toArray()
		#expect(x.count == 2, "expected two components, got \(x.count)")

		// The point, then the value. Both are stated, because either alone can be right while
		// the other is wrong: the correct value at the wrong point means the reported number
		// was not measured at the answer.
		let tolerance = 1e-4
		#expect(abs(x[0] - 0.4) < tolerance, "x₀ is 0.4 at the crossing, got \(x[0])")
		#expect(abs(x[1] - 0.6) < tolerance, "x₁ is 0.6 at the crossing, got \(x[1])")
		#expect(abs(result.worstCaseObjective - 4.4) < tolerance,
				"the minimax value is 4.4, got \(result.worstCaseObjective)")

		// The simplex row for the equality, satisfied at the point actually returned.
		let budget = x[0] + x[1]
		#expect(abs(budget - 1.0) < 1e-6, "the weights must sum to 1, they sum to \(budget)")
	}

	/// The same problem with the sense reversed: maximise the *best* case.
	///
	/// Maximising turns the epigraph the other way — `t − f(x, ωₖ) ≤ 0` with objective `−t` —
	/// and that sign flip runs through the row builder, the objective vector and the extraction.
	/// It is a separate code path with a separate chance to be wrong, so it gets its own answer.
	///
	/// `max_x min(2x₀ + 6x₁, 8x₀ + 2x₁)` on the same simplex is the same crossing by the same
	/// argument, read the other way up: below `x₀ = 0.4` the lower line is `2 + 6x₀`, rising;
	/// above it the lower line is `6 − 4x₀`, falling. The maximum of the minimum is again
	/// **4.4** at `x₀ = 0.4`.
	@Test("Maximising the best case finds the same crossing")
	func maximisingTheBestCaseIsTheSameCrossing() throws {
		let scenarios = [[2.0, 6.0], [8.0, 2.0]]
		let set = try DiscreteUncertaintySet(points: scenarios)
		let optimizer = RobustOptimizer<Vec>(uncertaintySet: set)

		let constraints: [MultivariateConstraint<Vec>] = [
			.linearEquality(coefficients: [1.0, 1.0], rhs: 1.0),
			.linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)
		]

		let result = try optimizer.optimize(
			objective: Self.dotProduct,
			nominalParameters: [5.0, 4.0],
			initialSolution: Vec([0.5, 0.5]),
			constraints: constraints,
			minimize: false
		)

		let x = result.solution.toArray()
		let tolerance = 1e-4
		#expect(abs(x[0] - 0.4) < tolerance, "x₀ is 0.4 at the crossing, got \(x[0])")
		#expect(abs(result.worstCaseObjective - 4.4) < tolerance,
				"the maximin value is 4.4, got \(result.worstCaseObjective)")
	}

	// MARK: - 2. The answer, by hand and by exhaustion at once

	/// Three scenarios on a budget, where the answer is derivable and a grid confirms it.
	///
	/// Minimise `max(3x₀ + x₁, x₀ + 4x₁, 2x₀ + 2x₁)` subject to `x ≥ 0` and `1 ≤ x₀ + x₁ ≤ 2`.
	///
	/// Every scenario has positive coefficients, so shrinking `x` reduces all three at once and
	/// the budget **floor** is active: the optimum lies on `x₀ + x₁ = 1`. Substituting
	/// `x₁ = 1 − x₀` leaves three functions of one variable:
	///
	/// | scenario | on the floor | at `x₀ = 0` | at `x₀ = 1` |
	/// |---|---|---|---|
	/// | `(3, 1)` | `1 + 2x₀` | 1 | 3 |
	/// | `(1, 4)` | `4 − 3x₀` | 4 | 1 |
	/// | `(2, 2)` | `2` | 2 | 2 |
	///
	/// The third is flat at 2 and never the maximum near the crossing, so the answer is where
	/// the rising and falling lines meet: `1 + 2x₀ = 4 − 3x₀` gives `x₀ = 0.6`, and both equal
	/// **2.2**. The optimum is `(0.6, 0.4)`, value 2.2.
	///
	/// The grid is kept as a second opinion on that derivation rather than as the assertion. The
	/// pointwise maximum of affine functions is convex, so a sweep at spacing `h` overshoots by
	/// at most `L·h`; with `L ≤ 5` and `h = 0.005` it is good to about 0.025. Two independent
	/// routes to 2.2 is the point — an arithmetic slip in the table above would show up as the
	/// grid and the hand derivation disagreeing, before either is compared to the solver.
	@Test("A three-scenario budget problem, derived and confirmed by exhaustion")
	func threeScenarioBudgetHasADerivableAnswer() throws {
		let scenarios = [[3.0, 1.0], [1.0, 4.0], [2.0, 2.0]]
		let set = try DiscreteUncertaintySet(points: scenarios)
		let optimizer = RobustOptimizer<Vec>(uncertaintySet: set)

		let constraints: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1.0, 1.0], rhs: 2.0, sense: .lessOrEqual),
			.linearInequality(coefficients: [1.0, 1.0], rhs: 1.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)
		]

		// Exhaustion first, so the hand derivation is checked before the solver is.
		let steps = 400
		let span = 2.0
		var gridBest = Double.infinity
		for i in 0...steps {
			let x0 = span * Double(i) / Double(steps)
			for j in 0...steps {
				let x1 = span * Double(j) / Double(steps)
				let sum = x0 + x1
				guard sum <= 2.0, sum >= 1.0 else { continue }
				let value = Self.worstCase([x0, x1], scenarios, minimising: true)
				if value < gridBest { gridBest = value }
			}
		}
		let derived = 2.2
		let gridResolution = 0.03
		#expect(abs(gridBest - derived) < gridResolution,
				"the table says \(derived); exhaustion says \(gridBest)")

		let result = try optimizer.optimize(
			objective: Self.dotProduct,
			nominalParameters: [2.0, 2.0],
			initialSolution: Vec([1.0, 1.0]),
			constraints: constraints,
			minimize: true
		)

		let x = result.solution.toArray()
		let tolerance = 1e-4
		#expect(abs(x[0] - 0.6) < tolerance, "the crossing is at x₀ = 0.6, the solve found \(x[0])")
		#expect(abs(x[1] - 0.4) < tolerance, "the crossing is at x₁ = 0.4, the solve found \(x[1])")
		#expect(abs(result.worstCaseObjective - derived) < tolerance,
				"the minimax value is \(derived), the solve reports \(result.worstCaseObjective)")

		// The budget floor is where the argument above said the optimum must sit. If the solve
		// lands anywhere else the derivation and the answer disagree, whatever the value says.
		let spend = x[0] + x[1]
		#expect(abs(spend - 1.0) < 1e-5,
				"the floor is active at the optimum, but the answer spends \(spend)")
	}

	// MARK: - 2b. The two routes, on one model

	/// The linear shortcut and the general solver must answer the same question.
	///
	/// `optimize` silently picks between two entirely separate algorithms: a simplex solve of the
	/// epigraph LP when everything linearises, and an augmented-Lagrangian outer loop when it does
	/// not. The caller is told nothing about which ran. So the two must agree, and the only way to
	/// ask is to hand them a model that differs by less than the answer does.
	///
	/// Here that is a curvature of `10⁻³·x₀²` added to a linear objective. It is far above
	/// `validateLinearModel`'s probe margin — at the probe point `x₀ = 3` the term is `9×10⁻³`
	/// against a margin near `10⁻⁶` — so the detector must decline and the general path must run.
	/// It moves the true optimum by about `10⁻⁴`, so the two answers must still meet.
	///
	/// Confirmed by instrumentation rather than inferred: with a `print` on the linear route's
	/// success return, the first model fires it and the second does not. Iteration count does
	/// **not** separate them — both finish in six or seven — so that is not the signal to read.
	@Test("The linear shortcut and the general solver agree on the same model")
	func bothRoutesReachTheSameAnswer() throws {
		let scenarios = [[2.0, 6.0], [8.0, 2.0]]
		let set = try DiscreteUncertaintySet(points: scenarios)
		let optimizer = RobustOptimizer<Vec>(uncertaintySet: set)

		let constraints: [MultivariateConstraint<Vec>] = [
			.linearEquality(coefficients: [1.0, 1.0], rhs: 1.0),
			.linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)
		]

		// Linear: the shortcut takes it.
		let linear = try optimizer.optimize(
			objective: Self.dotProduct,
			nominalParameters: [5.0, 4.0],
			initialSolution: Vec([0.5, 0.5]),
			constraints: constraints,
			minimize: true
		)

		// Barely curved: the shortcut refuses it, and the general solver runs.
		let curvature = 1e-3
		let curved = try optimizer.optimize(
			objective: { x, omega in
				let components = x.toArray()
				let linearPart = zip(omega, components).reduce(0.0) { $0 + $1.0 * $1.1 }
				return linearPart + curvature * components[0] * components[0]
			},
			nominalParameters: [5.0, 4.0],
			initialSolution: Vec([0.5, 0.5]),
			constraints: constraints,
			minimize: true
		)

		let straight = linear.solution.toArray()
		let bent = curved.solution.toArray()

		// The curvature is worth about 1.6e-4 in the objective and about 1.4e-6 in the argument;
		// 1e-2 leaves room for the general solver's own convergence without admitting a
		// disagreement that would mean the two routes solve different problems.
		let agreement = 1e-2
		#expect(abs(straight[0] - bent[0]) < agreement,
				"the routes place x₀ at \(straight[0]) and \(bent[0])")
		#expect(abs(linear.worstCaseObjective - curved.worstCaseObjective) < agreement,
				"""
				the routes value the optimum at \(linear.worstCaseObjective) and \
				\(curved.worstCaseObjective)
				""")
	}

	// MARK: - 3. The reported value is the value of the reported point

	/// `worstCaseObjective` must be what `solution` actually achieves.
	///
	/// This is not an oracle for the optimum — it is the law that makes the other two meaningful.
	/// A result carrying a value measured somewhere other than at its own point cannot be checked
	/// by anything, because every comparison then tests a number with no location.
	///
	/// Run across four models so that a single lucky case cannot carry it, including one whose
	/// scenarios differ in sign, where "worst" changes which `ω` attains it as `x` moves.
	@Test("The reported worst case is attained at the reported point", arguments: [
		[[1.0, 2.0], [2.0, 1.0]],
		[[3.0, -1.0], [-1.0, 3.0]],
		[[5.0, 0.0], [0.0, 5.0], [2.5, 2.5]],
		[[1.0, 1.0], [1.0, 1.0]]
	])
	func reportedValueIsAttainedAtTheReportedPoint(scenarios: [[Double]]) throws {
		let set = try DiscreteUncertaintySet(points: scenarios)
		let optimizer = RobustOptimizer<Vec>(uncertaintySet: set)

		let constraints: [MultivariateConstraint<Vec>] = [
			.linearEquality(coefficients: [1.0, 1.0], rhs: 1.0),
			.linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual)
		]

		let result = try optimizer.optimize(
			objective: Self.dotProduct,
			nominalParameters: [1.0, 1.0],
			initialSolution: Vec([0.5, 0.5]),
			constraints: constraints,
			minimize: true
		)

		let recomputed = Self.worstCase(result.solution.toArray(), scenarios, minimising: true)
		#expect(abs(recomputed - result.worstCaseObjective) < 1e-6,
				"""
				reported \(result.worstCaseObjective) but \(result.solution.toArray()) \
				attains \(recomputed) over \(scenarios)
				""")

		// The worst-case parameters must be one of the scenarios, and must be the one that
		// attains it — a plausible vector from the wrong scenario would go unnoticed otherwise.
		let attained = zip(result.worstCaseParameters, result.solution.toArray())
			.reduce(0.0) { $0 + $1.0 * $1.1 }
		#expect(abs(attained - recomputed) < 1e-6,
				"""
				the reported worst-case parameters \(result.worstCaseParameters) give \(attained), \
				not the worst case \(recomputed)
				""")
	}
}
