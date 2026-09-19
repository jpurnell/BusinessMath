//
//  VariableShiftExtractionTests.swift
//  BusinessMathTests
//
//  Which constraints count as a lower bound, and what happens to the ones that do not.
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// What ``extractVariableShift(from:dimension:)`` recovers, and what it must not depend on.
///
/// ## Why this suite exists
///
/// The simplex method assumes `x ≥ 0`. A variable whose lower bound is negative therefore has to
/// be translated before the relaxation is solved at all, and `extractVariableShift` is what finds
/// the translation. When it misses a bound, nothing reports an error — the implicit `x ≥ 0`
/// simply truncates the feasible region, and the solver answers a different question.
///
/// That has already cost this file one defect. A bound written as a closure used to be skipped
/// "because a closure is opaque", and `minimize x subject to x ≥ -3` returned **0** — the same
/// bound spelled `.linearInequality` returned −3, so the answer depended on how the caller wrote
/// it. The comment recording that fix is still in the source.
///
/// This suite is the generalisation of that lesson: **a bound is a bound however it is spelled,
/// and the extractor's answer must not depend on the spelling or on the order.** Every case below
/// is a different way of writing the same restriction.
@Suite("Which constraints are lower bounds, and in what order")
struct VariableShiftExtractionTests {

	typealias Vec = VectorN<Double>

	static func dot(_ coefficients: [Double]) -> @Sendable (Vec) -> Double {
		{ v in zip(coefficients, v.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 } }
	}

	// MARK: - 1. An equality is a bound

	/// A variable pinned to a negative value has a negative lower bound.
	///
	/// ## The defect this was written for
	///
	/// Both equality spellings were skipped, on the reasoning that an equality "pins a variable
	/// rather than bounding it from below". Pinning it at −3 bounds it below by −3; that is what
	/// the word means. With no shift, the simplex's implicit `x ≥ 0` contradicts `x = -3`, and
	/// the solver reported a perfectly feasible program **infeasible**.
	///
	/// `.linearEquality` and `.linearInequality(sense: .equal)` are both affected, and
	/// `ConstraintSense.equal` is documented on `linearInequality` as one of its three senses —
	/// it fell through both branches of the sense test without a `default`.
	@Test("An equality pinning a variable negative is a lower bound", arguments: [
		"linearEquality", "linearInequality(sense: .equal)"
	])
	func anEqualityIsALowerBound(spelling: String) throws {
		let pin: MultivariateConstraint<Vec> = spelling == "linearEquality"
			? .linearEquality(coefficients: [1, 0], rhs: -3)
			: .linearInequality(coefficients: [1, 0], rhs: -3, sense: .equal)

		let shift = try extractVariableShift(from: [pin], dimension: 2)
		#expect(shift.needsShift, "\(spelling): x = -3 needs a shift, and none was reported")
		#expect(shift.shifts[0] == -3.0,
				"\(spelling): the bound is -3, the extractor found \(shift.shifts[0])")
		#expect(shift.shifts[1] == 0.0,
				"\(spelling): the second variable is unconstrained here, got \(shift.shifts[1])")
	}

	/// And the solve it broke: a feasible program was reported infeasible.
	///
	/// `minimize x subject to x = -3, 0 ≤ y ≤ 5` has one answer, `x = -3`, and the objective is
	/// −3. The solver returned `.infeasible` for both spellings.
	///
	/// `enableVariableShifting` is **opt-in and defaults to `false`**, so this asks for it
	/// explicitly. That default is its own hazard and is pinned separately below; here the
	/// question is whether the machinery works when it is switched on, which it did not.
	@Test("A program pinned to a negative value is solved, not refused", arguments: [
		"linearEquality", "linearInequality(sense: .equal)"
	])
	func aNegativePinIsSolvedRatherThanRefused(spelling: String) throws {
		let pin: MultivariateConstraint<Vec> = spelling == "linearEquality"
			? .linearEquality(coefficients: [1, 0], rhs: -3)
			: .linearInequality(coefficients: [1, 0], rhs: -3, sense: .equal)

		let constraints: [MultivariateConstraint<Vec>] = [
			pin,
			.linearInequality(coefficients: [0, 1], rhs: 0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0, 1], rhs: 5, sense: .lessOrEqual)
		]
		let spec = IntegerProgramSpecification(integerVariables: Set(0..<2), binaryVariables: [])

		// Shifting is opt-in — see the note on the test.
		let solver = BranchAndBoundSolver<Vec>(enableVariableShifting: true)
		let result = try solver.solve(
			objective: Self.dot([1, 0]),
			from: Vec([0, 0]),
			subjectTo: constraints,
			integerSpec: spec,
			minimize: true
		)

		#expect(result.status != .infeasible,
				"\(spelling): x = -3 with 0 ≤ y ≤ 5 has a solution, and the solver refused it")
		#expect(abs(result.solution.toArray()[0] - (-3.0)) < 1e-6,
				"\(spelling): x is pinned at -3, the solve returned \(result.solution.toArray()[0])")
		#expect(abs(result.objectiveValue - (-3.0)) < 1e-6,
				"\(spelling): the objective at x = -3 is -3, got \(result.objectiveValue)")
	}

	// MARK: - 2. The order of the constraints is not information

	/// Two lower bounds on one variable give the same shift in either order.
	///
	/// The linear branches wrote `shifts[i] = lowerBound` — plain assignment — so the **last**
	/// constraint mentioning a variable decided its shift. `[x ≥ -10, x ≥ -3]` gave −3 and the
	/// reverse gave −10.
	///
	/// Neither breaks feasibility: any value at or below the binding bound translates the
	/// variable to something non-negative. What it breaks is that the shift feeds the LP's
	/// coefficients, so the tableau, the pivots, the vertex chosen among ties and the node count
	/// all depend on the order the caller happened to write the constraints in. That is the same
	/// class of defect as the `Set` iteration order fixed in `BranchAndBoundSolver` — an answer
	/// that varies with something that carries no information.
	@Test("Two bounds on one variable give the same shift in either order")
	func theShiftDoesNotDependOnConstraintOrder() throws {
		let forward: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1], rhs: -10, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1], rhs: -3, sense: .greaterOrEqual)
		]
		let reversed: [MultivariateConstraint<Vec>] = forward.reversed()

		let a = try extractVariableShift(from: forward, dimension: 1).shifts
		let b = try extractVariableShift(from: reversed, dimension: 1).shifts
		#expect(a == b, "the same constraints in the other order gave \(a) and \(b)")

		// And the value is the binding bound — the greatest of them — which is the tightest
		// translation that still lands the variable on or above zero.
		#expect(a == [-3.0], "x ≥ -10 and x ≥ -3 bind at -3, the extractor chose \(a)")
	}

	/// The same bound written two ways gives the same shift.
	///
	/// The closure branch already took the *minimum* over the bounds it found while the linear
	/// branches assigned, so a variable bounded once in each style got an answer that depended on
	/// which style was read last. Both now take the binding bound, so the spelling stops
	/// mattering — which is the property the closure fix was about in the first place.
	@Test("A bound spelled as a closure and one spelled linearly agree")
	func theShiftDoesNotDependOnTheSpelling() throws {
		// x ≥ -3 declaratively, x ≥ -10 as a closure: `-10 - x ≤ 0`.
		let mixed: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1], rhs: -3, sense: .greaterOrEqual),
			.inequality { v in -10.0 - v[0] }
		]
		// Both declaratively.
		let linear: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1], rhs: -3, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1], rhs: -10, sense: .greaterOrEqual)
		]

		let mixedShift = try extractVariableShift(from: mixed, dimension: 1).shifts
		let linearShift = try extractVariableShift(from: linear, dimension: 1).shifts
		#expect(mixedShift == linearShift,
				"the same two bounds gave \(mixedShift) mixed and \(linearShift) linear")
		#expect(mixedShift == [-3.0], "the bounds bind at -3, the extractor chose \(mixedShift)")
	}

	// MARK: - 2b. The default has to be the correct one

	/// A default-constructed solver answers a negatively-bounded model correctly.
	///
	/// ## Why the default was the defect
	///
	/// `enableVariableShifting` defaulted to `false`, and the flag is the only thing standing
	/// between `SimplexSolver`'s implicit `x ≥ 0` and a model that says otherwise. With it off,
	/// the feasible region is silently truncated at zero and the solver answers a different
	/// question without saying so:
	///
	/// | model | shifting off | shifting on | truth |
	/// |---|---|---|---|
	/// | `x ≥ -3`, minimise `x` | **0.0, status `.optimal`** | −3 | −3 |
	/// | `x = -3`, minimise `x` | `.infeasible` | −3 | −3 |
	/// | `-5 ≤ x ≤ -1`, minimise `x` | `.infeasible` | −5 | −5 |
	///
	/// The first row is the one that forced the change. `0.0` is a plausible number returned
	/// under a claim of proven optimality, which is precisely what this package's fail-silent
	/// principle forbids — the other two at least refuse.
	///
	/// Turning it on cannot make any model worse: `extractVariableShift` reports
	/// `needsShift == false` when no variable has a negative lower bound, so a model that was
	/// already correct is untouched, and the only models affected are the ones that were wrong.
	@Test("The default solver answers a negatively-bounded model correctly", arguments: [
		("a lower bound", [MultivariateConstraint<Vec>.linearInequality(coefficients: [1], rhs: -3, sense: .greaterOrEqual)], -3.0),
		("a negative pin", [MultivariateConstraint<Vec>.linearEquality(coefficients: [1], rhs: -3)], -3.0),
		("a wholly negative range", [
			MultivariateConstraint<Vec>.linearInequality(coefficients: [1], rhs: -5, sense: .greaterOrEqual),
			MultivariateConstraint<Vec>.linearInequality(coefficients: [1], rhs: -1, sense: .lessOrEqual)
		], -5.0)
	])
	func theDefaultSolverHandlesNegativeBounds(
		named: String,
		constraints: [MultivariateConstraint<Vec>],
		expected: Double
	) throws {
		let spec = IntegerProgramSpecification(integerVariables: Set(0..<1), binaryVariables: [])

		// Default-constructed on purpose: the point is what a caller gets without asking.
		let solver = BranchAndBoundSolver<Vec>()
		let result = try solver.solve(
			objective: Self.dot([1]),
			from: Vec([0]),
			subjectTo: constraints,
			integerSpec: spec,
			minimize: true
		)

		let x = result.solution.toArray()[0]
		#expect(abs(x - expected) < 1e-6,
				"\(named): minimising x gives \(expected), the default solver returned \(x)")
		#expect(abs(result.objectiveValue - expected) < 1e-6,
				"\(named): the objective is \(expected), got \(result.objectiveValue)")
	}

	/// And a model that never goes negative is not disturbed by the new default.
	///
	/// The flag only does something when `needsShift` is true, so this is the other half of the
	/// argument for turning it on: no shift is computed, no coefficient moves, and the answer is
	/// the one it always was.
	@Test("A non-negative model is untouched by shifting being on")
	func aNonNegativeModelIsUnaffected() throws {
		let constraints: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1, 1], rhs: 7.5, sense: .lessOrEqual),
			.linearInequality(coefficients: [1, 0], rhs: 0, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0, 1], rhs: 0, sense: .greaterOrEqual)
		]
		let shift = try extractVariableShift(from: constraints, dimension: 2)
		#expect(!shift.needsShift, "nothing here is negative, but a shift of \(shift.shifts) was found")

		let spec = IntegerProgramSpecification(integerVariables: Set(0..<2), binaryVariables: [])
		let onResult = try BranchAndBoundSolver<Vec>(enableVariableShifting: true).solve(
			objective: Self.dot([-1, -1]), from: Vec([0, 0]),
			subjectTo: constraints, integerSpec: spec, minimize: true)
		let offResult = try BranchAndBoundSolver<Vec>(enableVariableShifting: false).solve(
			objective: Self.dot([-1, -1]), from: Vec([0, 0]),
			subjectTo: constraints, integerSpec: spec, minimize: true)

		#expect(onResult.solution.toArray() == offResult.solution.toArray(),
				"""
				shifting changed a model that needs no shift: \(onResult.solution.toArray()) on, \
				\(offResult.solution.toArray()) off
				""")
		#expect(onResult.nodesExplored == offResult.nodesExplored,
				"the search itself differed: \(onResult.nodesExplored) nodes on, \(offResult.nodesExplored) off")
	}

	// MARK: - 3. The law the shift exists to satisfy

	/// Whatever shift is chosen, it must translate the variable to somewhere non-negative.
	///
	/// This is the whole point of the machinery, and it is checkable without agreeing on which
	/// bound to pick: the shift must sit at or below the binding lower bound, so that every
	/// feasible `x` maps to a `y = x - shift` the simplex will accept.
	///
	/// Run over bounds that bind in different places, including one where the tighter bound comes
	/// first and one where it comes last, so a rule that reads only the last constraint fails
	/// here regardless of which direction it errs in.
	@Test("The shift lands every feasible point at or above zero", arguments: [
		([-10.0, -3.0], -3.0),
		([-3.0, -10.0], -3.0),
		([-7.5], -7.5),
		([-1.0, -1.0], -1.0),
		([2.0, -4.0], 2.0)       // -4 is real but not binding, so nothing needs translating
	])
	func everyFeasiblePointTranslatesToNonNegative(bounds: [Double], binding: Double) throws {
		let constraints: [MultivariateConstraint<Vec>] = bounds.map {
			.linearInequality(coefficients: [1], rhs: $0, sense: .greaterOrEqual)
		}
		let shift = try extractVariableShift(from: constraints, dimension: 1)

		// The binding bound is the greatest of them; a point sitting exactly on it is feasible.
		let tightest = bounds.max() ?? 0
		#expect(abs(tightest - binding) < 1e-12,
				"the case says \(binding) binds but the bounds are \(bounds)")

		// A binding bound at or above zero needs no translation at all.
		if binding >= 0 {
			#expect(!shift.needsShift,
					"x ≥ \(binding) is already non-negative, but a shift of \(shift.shifts[0]) was applied")
		}

		let translated = shift.shiftPoint(VectorN([tightest])).toArray()[0]
		#expect(translated >= -1e-12,
				"""
				x = \(tightest) is feasible, but shifting by \(shift.shifts[0]) puts it at \
				\(translated), which the simplex will discard
				""")

		// And the round trip has to be exact, or the answer comes back in the wrong place.
		let restored = shift.unshiftPoint(VectorN([translated])).toArray()[0]
		#expect(abs(restored - tightest) < 1e-12,
				"shifting and unshifting \(tightest) returned \(restored)")
	}
}
