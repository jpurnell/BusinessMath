import Testing
import Foundation
@testable import BusinessMath

/// The solver's choices do not depend on `Set` iteration order.
///
/// ## What was wrong
///
/// `IntegerProgramSpecification.allIntegerVariables` is a `Set<Int>`, and Swift randomises set
/// iteration order **per process** — the hash seed differs between runs of the same binary. Four
/// places iterated one of these sets and let the order decide something:
///
/// - `mostFractionalVariable` keeps the best candidate with a strict `>`, so on a tie the
///   first-encountered variable wins.
/// - Pseudo-cost branching does the same with its scores.
/// - `solveRelaxation` appends a bound constraint per binary variable, so the **row order of the
///   LP** varied between processes — and with it the pivots, the vertex chosen among ties, and
///   everything downstream.
/// - The feasibility reporter assembled its violation messages in set order.
///
/// Ties are ordinary in integer programming: symmetric variables, equal fractionality, equal
/// pseudo-cost scores. So the same problem, solved twice in two processes, explored a different
/// tree and reported a different node count.
///
/// ## How it surfaced
///
/// Not from a test. `doc-run` reports an article as non-reproducible when two runs of the same
/// binary print different output, and `5.8d-LinearFunctionAPI.md` prints `nodesExplored` on seven
/// lines. It failed roughly one run in three, with three to six of those lines differing — and it
/// had been doing so before any of this session's changes.
///
/// ## What is asserted here
///
/// Order-independence cannot be tested by running twice in one process, because the hash seed is
/// fixed for the life of a process. What *can* be tested is the rule that replaces it: ties break
/// toward the **lowest variable index**, deterministically, which is what iterating in sorted
/// order gives.
@Suite("Branching determinism")
struct BranchingDeterminismTests {

	/// Two variables equally fractional: the lower index wins, every time.
	///
	/// Under set iteration this was a coin flip decided by the process's hash seed.
	@Test("A tie in fractionality breaks toward the lower index")
	func fractionalTieBreaksLow() throws {
		let spec = IntegerProgramSpecification(
			integerVariables: Set([0, 1, 2, 3]),
			binaryVariables: []
		)
		// Variables 1 and 3 are both exactly 0.5 fractional — a perfect tie. Variables 0 and 2
		// are integral and must not be chosen at all.
		let solution = VectorN<Double>([2.0, 1.5, 7.0, 4.5])

		let chosen = spec.mostFractionalVariable(solution)
		#expect(chosen == 1,
				"expected the lower of the tied indices (1 and 3), got \(String(describing: chosen))")
	}

	/// The same claim with the tie spread across more candidates.
	@Test("A three-way tie also breaks toward the lowest index")
	func threeWayTieBreaksLowest() throws {
		let spec = IntegerProgramSpecification(
			integerVariables: Set([0, 1, 2, 3, 4]),
			binaryVariables: []
		)
		let solution = VectorN<Double>([0.0, 3.5, 1.0, 8.5, 2.5])

		let chosen = spec.mostFractionalVariable(solution)
		#expect(chosen == 1,
				"expected 1, the lowest of the tied indices 1, 3 and 4; got \(String(describing: chosen))")
	}

	/// Repeating the call inside one process must of course agree with itself.
	///
	/// Weak on its own — a fixed hash seed makes it pass either way — but it is the claim a
	/// reader expects to see, and it fails loudly if the selection ever acquires real randomness.
	@Test("Repeated selection agrees with itself")
	func repeatedSelectionIsStable() throws {
		let spec = IntegerProgramSpecification(
			integerVariables: Set(0..<12),
			binaryVariables: []
		)
		let solution = VectorN<Double>((0..<12).map { Double($0) + 0.5 })

		let first = spec.mostFractionalVariable(solution)
		for _ in 0..<50 {
			#expect(spec.mostFractionalVariable(solution) == first,
					"selection changed within a single process")
		}
	}

	/// The same problem gives the same answer and the same tree, twice over.
	///
	/// In-process this cannot vary, so it is a regression guard rather than a proof — the proof
	/// is that the iteration is sorted. What it does catch is a future change that introduces
	/// genuine randomness into branching.
	@Test("A solve is reproducible in its node count")
	func solveReportsTheSameTreeTwice() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let a = point.toArray()
			return 4 * a[0] + 3 * a[1] + 3 * a[2]
		}
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.linearInequality(coefficients: [4, 2, 1], rhs: 10, sense: .lessOrEqual),
			.linearInequality(coefficients: [1, 4, 2], rhs: 12, sense: .lessOrEqual),
			.linearInequality(coefficients: [1, 1, 5], rhs: 15, sense: .lessOrEqual)
		]
		let spec = IntegerProgramSpecification(integerVariables: Set(0..<3), binaryVariables: [])

		func solve() throws -> (Double, Int) {
			let solver = BranchAndBoundSolver<VectorN<Double>>(branchingRule: .pseudoCost)
			let result = try solver.solve(
				objective: objective,
				from: VectorN([1.0, 1.0, 1.0]),
				subjectTo: constraints,
				integerSpec: spec,
				minimize: false
			)
			return (result.objectiveValue, result.nodesExplored)
		}

		let first = try solve()
		let second = try solve()
		#expect(first.1 == second.1,
				"explored \(first.1) nodes then \(second.1) — the same problem took a different path")
		let gap: Double = abs(first.0 - second.0)
		#expect(gap < 1e-12, "objective \(first.0) then \(second.0)")
	}
}
