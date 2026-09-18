//
//  SolveResultInvariantsTests.swift
//  BusinessMathTests
//
//  What a result must say when the search found nothing.
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// Laws every ``IntegerOptimizationResult`` from ``BranchAndBoundSolver/solve(objective:from:subjectTo:integerSpec:minimize:)``
/// must satisfy, whatever happened during the search.
///
/// ## Why this suite exists
///
/// `solve` carries a cognitive complexity of 160 and constructs its result in **five** separate
/// places — the root's unbounded relaxation, the node limit, the time limit, the gap
/// termination, and the two ordinary exits. Four of those can be reached with no incumbent, and
/// each chose its own answer to "what is the objective value when nothing was found".
///
/// They did not agree, and three of them were wrong in the direction that matters. Every
/// no-incumbent exit reported `objectiveValue: .infinity` regardless of sense, so a
/// **maximisation** that found nothing reported the best conceivable value. A caller writing the
/// obvious thing —
///
/// ```swift
/// if result.objectiveValue > bestSoFar { adopt(result) }
/// ```
///
/// — adopts a solve that explored one node, found nothing, and returned the initial guess.
///
/// The contradiction is visible without knowing the right answer: for that same maximisation the
/// result reported `objectiveValue: +∞` alongside `bestBound: -∞`. An incumbent cannot beat the
/// bound that was supposed to dominate it, so a result claiming both is internally inconsistent
/// whatever the convention.
///
/// ## The convention, which was already settled elsewhere
///
/// ``SimplexRelaxationSolver`` has answered this since it was written, and its tests pin it:
/// **infeasible takes the worst value for the sense, unbounded takes the best.** Minimising, an
/// infeasible relaxation reports `+∞`. `solve` used the *unbounded* convention while reporting
/// `status: .infeasible`, so the status and the number disagreed.
@Suite("What a solve result must say when it found nothing")
struct SolveResultInvariantsTests {

	typealias Vec = VectorN<Double>

	/// A linear objective, so nothing here depends on how the objective is evaluated.
	static func dot(_ coefficients: [Double]) -> @Sendable (Vec) -> Double {
		{ v in zip(coefficients, v.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 } }
	}

	static let twoIntegers = IntegerProgramSpecification(
		integerVariables: Set(0..<2),
		binaryVariables: []
	)

	/// `x₀ + x₁ ≥ 5` and `x₀ + x₁ ≤ 2` at once. No point satisfies both.
	static let contradictory: [MultivariateConstraint<Vec>] = [
		.linearInequality(coefficients: [1, 1], rhs: 5, sense: .greaterOrEqual),
		.linearInequality(coefficients: [1, 1], rhs: 2, sense: .lessOrEqual),
		.linearInequality(coefficients: [1, 0], rhs: 0, sense: .greaterOrEqual),
		.linearInequality(coefficients: [0, 1], rhs: 0, sense: .greaterOrEqual)
	]

	/// An ordinary bounded feasible region, used where the *budget* is what stops the search.
	static let bounded: [MultivariateConstraint<Vec>] = [
		.linearInequality(coefficients: [3, 2], rhs: 11.5, sense: .lessOrEqual),
		.linearInequality(coefficients: [1, 0], rhs: 0, sense: .greaterOrEqual),
		.linearInequality(coefficients: [0, 1], rhs: 0, sense: .greaterOrEqual)
	]

	/// The value a result must carry when the search found no integer solution.
	///
	/// The worst value for the sense, so that a caller comparing results never prefers a solve
	/// that found nothing to one that found something.
	static func nothingFound(minimising: Bool) -> Double {
		minimising ? .infinity : -.infinity
	}

	// MARK: - 1. The sentinel

	/// An infeasible program reports the worst value for its sense, not `+∞` both ways.
	@Test("An infeasible program reports the worst value for its sense", arguments: [true, false])
	func infeasibleReportsTheWorstValue(minimising: Bool) throws {
		let solver = BranchAndBoundSolver<Vec>()
		let result = try solver.solve(
			objective: Self.dot([1, 1]),
			from: Vec([0, 0]),
			subjectTo: Self.contradictory,
			integerSpec: Self.twoIntegers,
			minimize: minimising
		)

		#expect(result.status == .infeasible, "the program has no feasible point, got \(result.status)")
		let expected = Self.nothingFound(minimising: minimising)
		#expect(result.objectiveValue.isEqual(to: expected),
				"""
				nothing was found, so the value must be \(expected) for \
				minimize: \(minimising); got \(result.objectiveValue)
				""")
	}

	/// Exhausting the node budget before finding anything reports the same way.
	///
	/// One node is not enough to find an integer point here, so the incumbent is absent and the
	/// node-limit exit has to answer the same question the infeasible exit does. It answered it
	/// differently, which is what made this a real defect rather than a naming quibble.
	@Test("A node limit hit with no incumbent reports the worst value", arguments: [true, false])
	func nodeLimitWithNoIncumbentReportsTheWorstValue(minimising: Bool) throws {
		let solver = BranchAndBoundSolver<Vec>(maxNodes: 1)
		let result = try solver.solve(
			objective: Self.dot([-1, -1]),
			from: Vec([0, 0]),
			subjectTo: Self.bounded,
			integerSpec: Self.twoIntegers,
			minimize: minimising
		)

		try #require(result.status == .nodeLimit, "expected the budget to bind, got \(result.status)")
		let expected = Self.nothingFound(minimising: minimising)
		#expect(result.objectiveValue.isEqual(to: expected),
				"""
				the budget ran out before anything was found, so the value must be \(expected) \
				for minimize: \(minimising); got \(result.objectiveValue)
				""")
	}

	/// And a time limit, which is a third copy of the same exit.
	///
	/// `.zero` expires at the first check by design — the source records why that is the right
	/// behaviour rather than a bug — which makes it the cheapest way to reach this branch.
	@Test("A time limit hit with no incumbent reports the worst value", arguments: [true, false])
	func timeLimitWithNoIncumbentReportsTheWorstValue(minimising: Bool) throws {
		let solver = BranchAndBoundSolver<Vec>(timeLimit: .zero)
		let result = try solver.solve(
			objective: Self.dot([-1, -1]),
			from: Vec([0, 0]),
			subjectTo: Self.bounded,
			integerSpec: Self.twoIntegers,
			minimize: minimising
		)

		try #require(result.status == .timeLimit, "expected the clock to bind, got \(result.status)")
		let expected = Self.nothingFound(minimising: minimising)
		#expect(result.objectiveValue.isEqual(to: expected),
				"""
				the clock ran out before anything was found, so the value must be \(expected) \
				for minimize: \(minimising); got \(result.objectiveValue)
				""")
	}

	// MARK: - 1b. The point returned when there is nothing to return

	/// A failed solve hands back the caller's own starting point, unmoved.
	///
	/// ## The defect this was written for
	///
	/// When the caller's variables have negative lower bounds, `solve` shifts the whole problem
	/// into the non-negative orthant, searches there, and maps the answer back. The no-incumbent
	/// exit applied that inverse map to `initialGuess` — which was **never shifted**. The search
	/// runs on `shiftedInitialGuess`; the caller's own vector stays in the caller's own
	/// coordinates throughout.
	///
	/// So a solve started `from: [0, 0]` on a problem with lower bounds at `-5` returned
	/// `[-5, -5]`: a point the caller never named, on a run that found nothing, differing from
	/// the same solve with shifting switched off.
	///
	/// The two configurations are compared against each other rather than against a literal.
	/// Whether shifting is enabled is an internal optimisation, and an internal optimisation that
	/// changes the answer is the defect, whatever the answer is.
	@Test("Variable shifting does not move the point a failed solve returns")
	func shiftingDoesNotMoveTheReturnedStartingPoint() throws {
		// Lower bounds at −5 force a shift; the sum constraints contradict each other, so there
		// is nothing to find and the no-incumbent exit is the one taken.
		let constraints: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1, 0], rhs: -5, sense: .greaterOrEqual),
			.linearInequality(coefficients: [0, 1], rhs: -5, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1, 1], rhs: 20, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1, 1], rhs: 2, sense: .lessOrEqual)
		]

		// The shift is real, not assumed — if this stopped being true the test would pass for
		// the wrong reason.
		let shift = try extractVariableShift(from: constraints, dimension: 2)
		try #require(shift.needsShift, "this problem is here because it needs a shift")

		let start = Vec([0, 0])
		var returned: [Bool: [Double]] = [:]
		for shifting in [true, false] {
			let solver = BranchAndBoundSolver<Vec>(enableVariableShifting: shifting)
			let result = try solver.solve(
				objective: Self.dot([1, 1]),
				from: start,
				subjectTo: constraints,
				integerSpec: Self.twoIntegers,
				minimize: true
			)
			try #require(result.status == .infeasible,
						 "shifting: \(shifting) — expected no solution, got \(result.status)")
			returned[shifting] = result.solution.toArray()
		}

		let withShift = try #require(returned[true])
		let withoutShift = try #require(returned[false])
		#expect(withShift == withoutShift,
				"""
				shifting changed the answer: \(withShift) with it, \(withoutShift) without
				""")
		#expect(withShift == start.toArray(),
				"the caller started at \(start.toArray()) and got back \(withShift)")
	}

	// MARK: - 2. The law underneath it

	/// A reported answer can never be better than the bound that was supposed to dominate it.
	///
	/// This is the invariant the sentinel bug violated, and it is worth asserting separately
	/// because it does not depend on agreeing what "nothing found" should be called. Minimising,
	/// `bestBound` is a *lower* bound on every feasible objective value, so any incumbent sits at
	/// or above it. Maximising, it is an upper bound and the incumbent sits at or below.
	///
	/// A result that breaks this is telling the caller two incompatible things, and one of them
	/// is wrong whatever convention is adopted for the other.
	///
	/// Run across the three ways a search ends without an answer, both senses, plus two ordinary
	/// solves so the law is shown holding where it always did.
	@Test("The reported value never beats the bound", arguments: [
		("infeasible", 0), ("nodeLimit", 1), ("timeLimit", 2), ("solved", 3)
	], [true, false])
	func theReportedValueNeverBeatsTheBound(scenario: (String, Int), minimising: Bool) throws {
		let solver: BranchAndBoundSolver<Vec>
		let constraints: [MultivariateConstraint<Vec>]
		switch scenario.1 {
		case 0: solver = BranchAndBoundSolver<Vec>();               constraints = Self.contradictory
		case 1: solver = BranchAndBoundSolver<Vec>(maxNodes: 1);    constraints = Self.bounded
		case 2: solver = BranchAndBoundSolver<Vec>(timeLimit: .zero); constraints = Self.bounded
		default: solver = BranchAndBoundSolver<Vec>();              constraints = Self.bounded
		}

		let result = try solver.solve(
			objective: Self.dot([-1, -1]),
			from: Vec([0, 0]),
			subjectTo: constraints,
			integerSpec: Self.twoIntegers,
			minimize: minimising
		)

		let value = result.objectiveValue
		let bound = result.bestBound

		// A bound that was never established is `±∞` in the direction that proves nothing, and
		// the relation still has to hold against it.
		let holds = minimising ? (value >= bound) : (value <= bound)
		#expect(holds,
				"""
				\(scenario.0), minimize: \(minimising) — reported \(value) against a bound of \
				\(bound), so the answer beats the bound it was supposed to be dominated by
				""")
	}
}
