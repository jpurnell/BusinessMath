//
//  LinearProgrammingCertificateTests.swift
//  BusinessMath
//
//  An external oracle for the simplex solver — but not a fixture.
//
//  A linear program is one of the few numerical problems that **certifies its own
//  answer**. Given a claimed optimum the theory supplies a checklist that no wrong
//  answer can satisfy:
//
//    1. the point is feasible;
//    2. the reported objective is that point's objective;
//    3. the duals price the constraints at `y'b = c'x` — a zero duality gap;
//    4. complementary slackness — a constraint with slack has price zero, and a
//       variable at a positive value has zero reduced cost;
//    5. the reduced costs are non-negative, so no non-basic variable would improve
//       the objective if introduced.
//
//  Together those are *sufficient*: a feasible primal and a feasible dual with a
//  zero gap are both optimal. Nothing here has to trust another solver, and — the
//  reason this is preferable to a fixture — nothing imports another solver's
//  tie-breaking or degeneracy conventions. Two correct LP codes routinely return
//  different vertices of the same optimal face, so a fixture comparing solution
//  vectors would manufacture failures where there is no defect.
//
//  Two of the checks here owe nothing at all to duality theory:
//
//  - **Exhaustive vertex enumeration.** A bounded LP attains its optimum at a
//    vertex, and a vertex is where `n` linearly independent constraints hold with
//    equality. For the small problems below every such subset can be enumerated,
//    solved by Gaussian elimination and tested for feasibility. That is a complete
//    second LP solver that shares no line of code with the simplex.
//
//  - **Shadow prices against their own definition.** A dual value *is*
//    `d(objective)/d(rhs)`, so it can be measured by nudging the right-hand side and
//    re-solving. This is what found the defect these tests were written against.
//
//  ## Convention
//
//  `dualValues` is the plain derivative `d(objective)/d(rhs_i)` — positive when
//  raising the right-hand side raises the objective, whichever way the problem is
//  being optimised. That is the convention under which `y'b = c'x` holds, which is
//  why it is the one worth having: it is checkable.
//
//  `reducedCosts` is the amount the objective would **worsen** per unit of a
//  non-basic variable introduced, so it is non-negative at an optimum in both
//  senses. The two conventions meet at the identity in
//  `reducedCostsAgreeWithTheDuals`.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Linear programming — optimality certificates")
struct LinearProgrammingCertificateTests {

	// MARK: - Corpus

	/// A bounded linear program with everything needed to check an answer against
	/// the definitions rather than against a stored number.
	private struct Problem: Sendable {
		let name: String
		let note: String
		let objective: [Double]
		let constraints: [SimplexConstraint]
		let maximize: Bool
		/// Whether the optimal basis is unique enough for the shadow prices to be
		/// determined.
		///
		/// A degenerate LP has more than one optimal dual solution — the objective's
		/// one-sided derivatives with respect to a right-hand side genuinely differ,
		/// so there is no single number for a dual to be. Every such problem is still
		/// held to feasibility, the duality gap and complementary slackness, which do
		/// not require uniqueness; only the finite-difference comparison is skipped,
		/// and skipping it is the honest reading rather than a loosened tolerance.
		let dualsAreDetermined: Bool
	}

	private static func leq(_ c: [Double], _ b: Double) -> SimplexConstraint {
		SimplexConstraint(coefficients: c, relation: .lessOrEqual, rhs: b)
	}
	private static func geq(_ c: [Double], _ b: Double) -> SimplexConstraint {
		SimplexConstraint(coefficients: c, relation: .greaterOrEqual, rhs: b)
	}
	private static func eq(_ c: [Double], _ b: Double) -> SimplexConstraint {
		SimplexConstraint(coefficients: c, relation: .equal, rhs: b)
	}

	private static let corpus: [Problem] = [
		Problem(name: "wyndorGlass",
				note: """
					Hillier & Lieberman's product-mix example. All ≤, maximisation — the shape
					under which the extraction happened to be correct, kept so a fix cannot
					regress it. Optimum (2, 6) = 36, duals (0, 1.5, 1).
					""",
				objective: [3, 5],
				constraints: [leq([1, 0], 4), leq([0, 2], 12), leq([3, 2], 18)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "dietAllGreater",
				note: """
					All ≥, minimisation — the other shape that was already correct, and
					correct for a compensating reason: the surplus column's sign and the
					negation inside `minimize` cancelled.
					""",
				objective: [2, 3],
				constraints: [geq([1, 1], 4), geq([1, 3], 6), leq([1, 0], 50)],
				maximize: false, dualsAreDetermined: true),

		Problem(name: "minimiseWithBindingUpperBound",
				note: """
					Minimisation whose binding row is ≤. Raising that bound lowers the
					objective, so the shadow price is negative — a sign the extraction cannot
					produce by reading an unsigned slack column.
					""",
				objective: [-1, -2],
				constraints: [leq([1, 0], 3), leq([0, 1], 5), leq([1, 1], 7)],
				maximize: false, dualsAreDetermined: true),

		Problem(name: "minimiseMixedRelations",
				note: """
					≥ and ≤ in one model. The added columns are grouped by type rather than
					laid out in row order, so a row-indexed read lands on another row's column
					and reports one constraint's price against another.
					""",
				objective: [2, 3],
				constraints: [geq([1, 1], 4), leq([1, 0], 3), leq([0, 1], 9)],
				maximize: false, dualsAreDetermined: true),

		Problem(name: "maximiseWithLowerBound",
				note: """
					Maximisation with a binding ≥ row: a floor that costs something to hold,
					so its price is negative.
					""",
				objective: [3, 1],
				constraints: [leq([1, 1], 6), geq([0, 1], 2)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "equalityAndUpperBound",
				note: """
					An equality row has neither slack nor surplus, so a row-indexed read finds
					no column to price it and reports zero. Strong duality then fails by the
					whole objective value while every number in the result still looks
					ordinary.
					""",
				objective: [2, 3],
				constraints: [eq([1, 1], 4), leq([1, 0], 3)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "equalityOnly",
				note: """
					The same fault with nothing else in the model to mask it: the single price
					carries the entire objective.
					""",
				objective: [2, 3],
				constraints: [eq([1, 1], 5)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "blendingThreeVariables",
				note: """
					Three variables and every relation at once, which is where a type-grouped
					column layout and a row-ordered read diverge most.
					""",
				objective: [4, 5, 3],
				constraints: [eq([1, 1, 1], 10), geq([1, 0, 0], 2), leq([0, 1, 0], 5),
							  leq([2, 1, 3], 24)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "negativeRightHandSide",
				note: """
					A row the solver rewrites before it starts: a negative right-hand side is
					normalised by negating the row, which flips the relation. The price must
					still be quoted against the constraint as written.
					""",
				objective: [1, 1],
				constraints: [geq([-1, -1], -6), leq([1, 0], 4), leq([0, 1], 4)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "wideScaleSpread",
				note: """
					Coefficients four orders of magnitude apart, so the solver's row
					equilibration is active. A price is owed on the constraint the caller
					wrote, not on the one the solver found convenient.
					""",
				objective: [1, 1],
				constraints: [leq([10000, 1], 20000), leq([1, 1], 3)],
				maximize: true, dualsAreDetermined: true),

		Problem(name: "degenerateVertex",
				note: """
					Three constraints meeting at one point in two dimensions. More constraints
					bind than there are variables, so several dual solutions are optimal and
					the objective's one-sided derivatives differ. Held to the gap and to
					complementary slackness, which do not need a unique dual; not to a
					measured derivative, which here does not exist.
					""",
				objective: [1, 1],
				constraints: [leq([1, 1], 4), leq([1, 0], 2), leq([0, 1], 2)],
				maximize: true, dualsAreDetermined: false),

		Problem(name: "multipleOptima",
				note: """
					An objective parallel to a binding edge: every point of that edge is
					optimal. The optimal *value* is unique and is what the vertex enumeration
					compares; the vertex reached is a tie-break, and asserting one would be
					asserting a convention.
					""",
				objective: [1, 1],
				constraints: [leq([1, 1], 5), leq([1, 0], 4), leq([0, 1], 4)],
				maximize: true, dualsAreDetermined: false),
	]

	// MARK: - An independent LP solver: exhaustive vertex enumeration

	/// Solves `A x = b` by Gaussian elimination with partial pivoting.
	///
	/// Deliberately written out here rather than taken from the package: an oracle
	/// that shared the package's linear algebra could agree with the simplex through
	/// a fault they both inherit.
	private static func solveSquare(_ a: [[Double]], _ b: [Double]) -> [Double]? {
		let n = b.count
		guard a.count == n, a.allSatisfy({ $0.count == n }) else { return nil }
		var m = a
		var rhs = b

		for col in 0..<n {
			var pivotRow = col
			var best = abs(m[col][col])
			for row in (col + 1)..<n where abs(m[row][col]) > best {
				best = abs(m[row][col])
				pivotRow = row
			}
			// Singular to working precision: these n hyperplanes do not meet in a
			// point, so this subset defines no vertex.
			guard best > 1e-9 else { return nil }
			m.swapAt(col, pivotRow)
			rhs.swapAt(col, pivotRow)

			let pivot = m[col][col]
			for row in 0..<n where row != col {
				let factor = m[row][col] / pivot
				guard factor != 0 else { continue }
				for k in col..<n {
					m[row][k] -= factor * m[col][k]
				}
				rhs[row] -= factor * rhs[col]
			}
		}

		var out = [Double](repeating: 0, count: n)
		for i in 0..<n {
			out[i] = rhs[i] / m[i][i]
		}
		return out
	}

	/// Every way to choose `k` items from `0..<n`.
	private static func combinations(_ n: Int, _ k: Int) -> [[Int]] {
		guard k > 0, k <= n else { return k == 0 ? [[]] : [] }
		var out: [[Int]] = []
		var current = [Int]()

		func recurse(_ start: Int) {
			// The base case: a full selection is recorded and the branch ends. Every
			// other path advances `start`, so the recursion is bounded by `n`.
			if current.count == k {
				out.append(current)
				return
			}
			guard start < n else { return }
			for next in start..<n {
				current.append(next)
				recurse(next + 1)
				current.removeLast()
			}
		}
		recurse(0)
		return out
	}

	private static func isFeasible(_ x: [Double], _ problem: Problem, tolerance: Double) -> Bool {
		guard x.allSatisfy({ $0 >= -tolerance }) else { return false }
		for constraint in problem.constraints {
			var lhs = 0.0
			for (j, coefficient) in constraint.coefficients.enumerated() {
				lhs += coefficient * x[j]
			}
			let slack = lhs - constraint.rhs
			let bound = tolerance * Swift.max(1.0, abs(constraint.rhs))
			switch constraint.relation {
			case .lessOrEqual: if slack > bound { return false }
			case .greaterOrEqual: if slack < -bound { return false }
			case .equal: if abs(slack) > bound { return false }
			}
		}
		return true
	}

	private static func objectiveValue(_ x: [Double], _ problem: Problem) -> Double {
		var total = 0.0
		for (j, coefficient) in problem.objective.enumerated() {
			total += coefficient * x[j]
		}
		return total
	}

	/// The optimal objective value, found by enumerating every vertex of the
	/// feasible region.
	///
	/// A bounded linear program attains its optimum at a vertex, and a vertex in `n`
	/// dimensions is a point where `n` linearly independent constraints — structural
	/// rows or the non-negativity bounds — hold with equality. Enumerating all
	/// `C(m + n, n)` subsets is hopeless in general and trivial at this size.
	private static func bruteForceOptimum(_ problem: Problem) -> Double? {
		let n = problem.objective.count
		var planes: [(normal: [Double], rhs: Double)] = problem.constraints.map {
			(normal: $0.coefficients, rhs: $0.rhs)
		}
		for j in 0..<n {
			var normal = [Double](repeating: 0, count: n)
			normal[j] = 1
			planes.append((normal: normal, rhs: 0))
		}

		var best: Double?
		for subset in combinations(planes.count, n) {
			let a = subset.map { planes[$0].normal }
			let b = subset.map { planes[$0].rhs }
			guard let x = solveSquare(a, b) else { continue }
			guard isFeasible(x, problem, tolerance: 1e-7) else { continue }
			let value = objectiveValue(x, problem)
			if let incumbent = best {
				best = problem.maximize ? Swift.max(incumbent, value) : Swift.min(incumbent, value)
			} else {
				best = value
			}
		}
		return best
	}

	// MARK: - Helpers

	private static func solve(_ problem: Problem) throws -> SimplexResult {
		let solver = SimplexSolver()
		if problem.maximize {
			return try solver.maximize(objective: problem.objective, subjectTo: problem.constraints)
		}
		return try solver.minimize(objective: problem.objective, subjectTo: problem.constraints)
	}

	/// `d(objective)/d(rhs_i)`, by central difference — the definition of a shadow
	/// price, evaluated without reference to the tableau.
	private static func measuredShadowPrice(_ problem: Problem, row: Int) throws -> Double {
		let step = 1e-5 * Swift.max(1.0, abs(problem.constraints[row].rhs))

		func objective(at rhs: Double) throws -> Double {
			var perturbed = problem.constraints
			perturbed[row] = SimplexConstraint(coefficients: problem.constraints[row].coefficients,
											   relation: problem.constraints[row].relation,
											   rhs: rhs)
			var nudged = problem
			nudged = Problem(name: problem.name, note: problem.note, objective: problem.objective,
							 constraints: perturbed, maximize: problem.maximize,
							 dualsAreDetermined: problem.dualsAreDetermined)
			return try solve(nudged).objectiveValue
		}

		let base = problem.constraints[row].rhs
		let high = try objective(at: base + step)
		let low = try objective(at: base - step)
		let difference: Double = high - low
		return difference / (2 * step)
	}

	// MARK: - The corpus itself

	@Test("The corpus covers every relation, both senses, and the awkward shapes")
	func corpusIsRepresentative() {
		let problems = Self.corpus
		#expect(problems.count >= 12, "only \(problems.count) problems")
		#expect(problems.contains { $0.maximize })
		#expect(problems.contains { !$0.maximize })

		func has(_ relation: ConstraintRelation, maximising: Bool) -> Bool {
			problems.contains { problem in
				problem.maximize == maximising && problem.constraints.contains { constraint in
					if case relation = constraint.relation { return true }
					return false
				}
			}
		}
		// Every relation in both senses. The defect this file was written against
		// only appeared away from all-≤ maximisation and all-≥ minimisation, which
		// is exactly the pair a small corpus tends to consist of.
		for maximising in [true, false] {
			#expect(has(.lessOrEqual, maximising: maximising), "no ≤ row, maximise=\(maximising)")
			#expect(has(.greaterOrEqual, maximising: maximising), "no ≥ row, maximise=\(maximising)")
		}
		#expect(problems.contains { $0.constraints.contains { if case .equal = $0.relation { return true }; return false } },
				"no equality row")
		#expect(problems.contains { $0.constraints.contains { $0.rhs < 0 } }, "no negative right-hand side")
		#expect(problems.contains { !$0.dualsAreDetermined }, "no degenerate problem")
		#expect(problems.contains { $0.objective.count >= 3 }, "nothing beyond two variables")
	}

	// MARK: - 1. The point is feasible and the value is its value

	@Test("Every reported optimum is a feasible point")
	func reportedSolutionIsFeasible() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			#expect(result.status == .optimal, "\(problem.name): status \(result.status)")
			guard result.status == .optimal else { continue }
			#expect(result.solution.count == problem.objective.count,
					"\(problem.name): \(result.solution.count) values for \(problem.objective.count) variables")
			#expect(Self.isFeasible(result.solution, problem, tolerance: 1e-7),
					"\(problem.name): \(result.solution) violates its own constraints")
		}
	}

	@Test("The reported objective is the objective of the reported point")
	func objectiveMatchesTheSolution() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let recomputed = Self.objectiveValue(result.solution, problem)
			let scale = Swift.max(1.0, abs(recomputed))
			#expect(abs(result.objectiveValue - recomputed) < 1e-8 * scale,
					"\(problem.name): reported \(result.objectiveValue), c'x is \(recomputed)")
		}
	}

	// MARK: - 2. An independent solver agrees on the value

	@Test("The optimal value matches exhaustive vertex enumeration")
	func optimumMatchesVertexEnumeration() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else {
				Issue.record("\(problem.name): status \(result.status)"); continue
			}
			guard let reference = Self.bruteForceOptimum(problem) else {
				Issue.record("\(problem.name): enumeration found no feasible vertex"); continue
			}
			let scale = Swift.max(1.0, abs(reference))
			// The optimal *value* is unique even where the optimal point is not, so
			// this is the strongest thing that can be asserted across the corpus.
			#expect(abs(result.objectiveValue - reference) < 1e-7 * scale,
					"\(problem.name): simplex \(result.objectiveValue), enumeration \(reference)")
		}
	}

	// MARK: - 3. The duals price the constraints

	@Test("Shadow prices match their own definition, d(objective)/d(rhs)")
	func shadowPricesMatchTheDefinition() throws {
		for problem in Self.corpus where problem.dualsAreDetermined {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let duals = try #require(result.dualValues, "\(problem.name): no duals")
			#expect(duals.count == problem.constraints.count,
					"\(problem.name): \(duals.count) duals for \(problem.constraints.count) constraints")
			guard duals.count == problem.constraints.count else { continue }

			for row in 0..<duals.count {
				let measured = try Self.measuredShadowPrice(problem, row: row)
				let scale = Swift.max(1.0, abs(measured))
				// A central difference on a piecewise-linear function is exact away
				// from a breakpoint, so this bound is about the re-solve's own
				// arithmetic, not about the differencing.
				#expect(abs(duals[row] - measured) < 1e-6 * scale,
						"\(problem.name) row \(row): reported \(duals[row]), measured \(measured)")
			}
		}
	}

	@Test("The duality gap is zero: y'b equals c'x")
	func strongDualityHolds() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let duals = try #require(result.dualValues, "\(problem.name): no duals")
			guard duals.count == problem.constraints.count else {
				Issue.record("\(problem.name): \(duals.count) duals for \(problem.constraints.count) rows")
				continue
			}
			var priced = 0.0
			for (row, constraint) in problem.constraints.enumerated() {
				priced += duals[row] * constraint.rhs
			}
			let scale = Swift.max(1.0, abs(result.objectiveValue))
			// Holds for degenerate problems too: any optimal dual solution closes the
			// gap, which is why this check needs no uniqueness.
			#expect(abs(priced - result.objectiveValue) < 1e-7 * scale,
					"\(problem.name): y'b = \(priced), c'x = \(result.objectiveValue)")
		}
	}

	@Test("Complementary slackness: a constraint with slack has no price")
	func complementarySlacknessHolds() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let duals = try #require(result.dualValues, "\(problem.name): no duals")
			guard duals.count == problem.constraints.count else { continue }

			for (row, constraint) in problem.constraints.enumerated() {
				// An equality row is always tight, so it says nothing here.
				if case .equal = constraint.relation { continue }
				var lhs = 0.0
				for (j, coefficient) in constraint.coefficients.enumerated() {
					lhs += coefficient * result.solution[j]
				}
				let slack = abs(lhs - constraint.rhs)
				let bound = 1e-7 * Swift.max(1.0, abs(constraint.rhs))
				guard slack > bound else { continue }
				// Not binding, so relaxing it cannot change anything: its price is zero.
				// This check is free of every sign convention, which is what makes it
				// worth having alongside the signed ones.
				#expect(abs(duals[row]) < 1e-7,
						"\(problem.name) row \(row): slack \(slack) yet priced at \(duals[row])")
			}
		}
	}

	// MARK: - 4. The reduced costs

	@Test("Reduced costs are non-negative, and zero wherever a variable is used")
	func reducedCostsAreNonNegativeAndComplementary() throws {
		for problem in Self.corpus {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let costs = try #require(result.reducedCosts, "\(problem.name): no reduced costs")
			#expect(costs.count == problem.objective.count,
					"\(problem.name): \(costs.count) reduced costs for \(problem.objective.count) variables")
			guard costs.count == problem.objective.count else { continue }

			for j in 0..<costs.count {
				// The documented meaning is "how much the objective would worsen",
				// which at an optimum cannot be negative in either sense — a negative
				// value would name an improving move the solver failed to take.
				#expect(costs[j] > -1e-7,
						"\(problem.name) variable \(j): reduced cost \(costs[j]) claims an unclaimed improvement")
				// And a variable already in use has nothing to pay to enter.
				if result.solution[j] > 1e-7 {
					#expect(abs(costs[j]) < 1e-7,
							"\(problem.name) variable \(j): value \(result.solution[j]) but reduced cost \(costs[j])")
				}
			}
		}
	}

	@Test("Reduced costs agree with the duals")
	func reducedCostsAgreeWithTheDuals() throws {
		for problem in Self.corpus where problem.dualsAreDetermined {
			let result = try Self.solve(problem)
			guard result.status == .optimal else { continue }
			let duals = try #require(result.dualValues)
			let costs = try #require(result.reducedCosts)
			guard duals.count == problem.constraints.count,
				  costs.count == problem.objective.count else { continue }

			for j in 0..<costs.count {
				var priced = 0.0
				for (row, constraint) in problem.constraints.enumerated() {
					priced += duals[row] * constraint.coefficients[j]
				}
				// `y'A_j - c_j` is the rate at which the objective falls per unit of
				// variable j introduced; "worsen" is that when maximising and its
				// negation when minimising. Linking the two conventions is what makes
				// each of them checkable rather than merely self-consistent.
				let gap: Double = priced - problem.objective[j]
				let expected: Double = problem.maximize ? gap : -gap
				let scale = Swift.max(1.0, abs(expected))
				#expect(abs(costs[j] - expected) < 1e-7 * scale,
						"\(problem.name) variable \(j): reduced cost \(costs[j]), y'A_j - c_j gives \(expected)")
			}
		}
	}
}
