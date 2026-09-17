import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// What the cutting-plane loop's two termination guards actually do.
///
/// ## What this suite used to be
///
/// Seven tests named for stagnation and cycling detection, every one of which solved a
/// two-to-four variable problem with a single `x₁ + x₂ ≤ c` constraint and then asserted
/// that the answer was feasible. Measured on all seven fixtures:
///
/// ```
/// totalCutsGenerated = 0    cuttingRounds = 0
/// ```
///
/// **No cut was generated, so the cutting-plane loop was never entered, so neither guard
/// ever ran.** One of them said so in a comment — *"statistics should show fewer than 10
/// cutting rounds"* — directly above an assertion about the solution instead. Seven tests
/// that passed identically with both features deleted.
///
/// ## What the rewrite found
///
/// Given a fixture that does generate cuts, cycling detection turned out to be inert for a
/// second reason: its `break` was written inside the `for` loop that scans the history, so
/// it exited the scan rather than the round loop it was meant to stop. Detection fired and
/// cutting carried on. See ``cyclingDetectionEndsTheRoundLoop``.
@Suite("Degeneracy and Cycling Protection")
struct DegeneracyProtectionTests {

	// MARK: - A fixture that generates cuts

	/// `max 4a + 3b + 3c` subject to three knapsack rows, all variables integer.
	///
	/// Chosen by measurement, not by eye. The fractional LP vertex is cut, re-solved and cut
	/// again for as many rounds as the budget allows — twenty at a single node — which is what
	/// makes a window-based guard observable at all. The problems this suite used before
	/// converged to an integral vertex immediately and generated nothing.
	///
	/// Integer optimum **14**, attained at `(2, 0, 2)`, verified by exhaustive enumeration
	/// over the box the constraints imply.
	private static let objectiveCoefficients: [Double] = [4.0, 3.0, 3.0]

	private static let rows: [([Double], Double)] = [
		([4.0, 2.0, 1.0], 10.0),
		([1.0, 4.0, 2.0], 12.0),
		([1.0, 1.0, 5.0], 15.0)
	]

	/// The integer optimum, for asserting that a termination guard changes cost and not answer.
	private static let integerOptimum: Double = 14.0

	/// Solve the fixture under one configuration of the two guards.
	///
	/// - Parameters:
	///   - detectStagnation: Stop when the LP bound stops improving.
	///   - detectCycling: Stop when the LP vertex repeats one seen inside the window.
	///   - cyclingWindowSize: How many recent vertices the cycling check compares against.
	///   - tolerance: Serves both guards — the bound-improvement floor for stagnation and,
	///     because the implementation reuses the same parameter, the componentwise equality
	///     tolerance for cycling. At `1e-9` the vertices this fixture visits are all distinct
	///     to machine precision and no cycle is ever declared; the coarser value used below
	///     is what makes the guard reachable.
	///   - maxRounds: The per-node cutting budget.
	/// - Returns: The objective value reached and the cut statistics.
	private func solveFixture(
		detectStagnation: Bool,
		detectCycling: Bool,
		cyclingWindowSize: Int = 4,
		tolerance: Double = 1e-9,
		maxRounds: Int = 20
	) throws -> (objective: Double, stats: CuttingPlaneStats) {
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			enableCuttingPlanes: true,
			maxCuttingRounds: maxRounds,
			detectStagnation: detectStagnation,
			stagnationTolerance: tolerance,
			detectCycling: detectCycling,
			cyclingWindowSize: cyclingWindowSize,
			enableCutAging: true,
			cutAgingLimit: 1
		)

		let coefficients = Self.objectiveCoefficients
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			var total: Double = 0.0
			for index in 0..<Swift.min(values.count, coefficients.count) {
				total += values[index] * coefficients[index]
			}
			return total
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = Self.rows.map { row in
			.linearInequality(coefficients: row.0, rhs: row.1, sense: .lessOrEqual)
		}

		let result = try solver.solve(
			objective: objective,
			from: VectorN([1.0, 1.0, 1.0]),
			subjectTo: constraints,
			integerSpec: IntegerProgramSpecification(integerVariables: Set(0..<3), binaryVariables: []),
			minimize: false
		)

		let stats = try #require(result.cuttingPlaneStats,
								 "cutting planes were enabled, so statistics must exist")
		return (result.objectiveValue, stats)
	}

	/// Everything below is conditional on this: a guard cannot be observed in a solve that
	/// never enters the loop it guards.
	@Test("The fixture generates cuts and fills the cycling window")
	func fixtureReachesTheCuttingLoop() throws {
		let run = try solveFixture(detectStagnation: false, detectCycling: false)
		let generated: Int = run.stats.totalCutsGenerated
		let atOneNode: Int = run.stats.maxRoundsAtNode

		#expect(generated > 0, "no cuts generated, so no guard can run; got \(generated)")
		#expect(atOneNode > 4,
				"a window of 4 needs more than 4 rounds at one node to be compared against; got \(atOneNode)")
	}

	// MARK: - Cycling

	/// The defect: `break` exited the history scan, not the round loop.
	///
	/// Written as a comparison rather than an absolute count because the absolute number is a
	/// property of the LP, not of the guard. What the guard owes is that turning it on does
	/// less work than leaving it off — and before the fix the two were identical to the
	/// integer, on every fixture tried: 32 rounds, 74 cuts, 20 rounds at the deepest node,
	/// with detection on and with detection off alike.
	@Test("Cycling detection ends the round loop, not just the history scan")
	func cyclingDetectionEndsTheRoundLoop() throws {
		let coarse: Double = 0.25
		let off = try solveFixture(detectStagnation: false, detectCycling: false, tolerance: coarse)
		let on = try solveFixture(detectStagnation: false, detectCycling: true, tolerance: coarse)

		let roundsOff: Int = off.stats.cuttingRounds
		let roundsOn: Int = on.stats.cuttingRounds
		#expect(roundsOn < roundsOff,
				"detection on ran \(roundsOn) rounds, off ran \(roundsOff) — equal means the break missed its loop")

		let deepestOff: Int = off.stats.maxRoundsAtNode
		let deepestOn: Int = on.stats.maxRoundsAtNode
		#expect(deepestOn < deepestOff,
				"deepest node: \(deepestOn) rounds with detection, \(deepestOff) without")
	}

	/// Stopping early is allowed to cost cuts. It is not allowed to cost accuracy.
	///
	/// ## What this used to record
	///
	/// This assertion was a known issue, because branch-and-cut reported a different "optimal"
	/// value for almost every cutting budget — 14 at budgets 0 to 2, then 12, 10, 7, 9 — with
	/// the guards disabled entirely. The guards entered only by changing how many rounds ran,
	/// which changed which wrong answer came back.
	///
	/// The cause was cut validity, not the guards: the cutting loop derived Gomory **fractional**
	/// cuts from tableaux that contained its own earlier cuts, and that derivation's rounding
	/// step is unjustified once a non-integral column is present. Replacing it with the
	/// mixed-integer form, which carries no such premise, made every budget agree. The
	/// assertion below is an ordinary expectation again.
	///
	/// See `GomoryMixedIntegerCutTests` for the derivation and its enumeration oracle, and
	/// ``BranchAndCutBudgetIndependenceTests`` for the property stated directly.
	@Test("Neither guard changes the integer optimum")
	func guardsDoNotChangeTheAnswer() throws {
		let coarse: Double = 0.25
		let neither = try solveFixture(detectStagnation: false, detectCycling: false, tolerance: coarse)
		let cycling = try solveFixture(detectStagnation: false, detectCycling: true, tolerance: coarse)
		let stagnating = try solveFixture(detectStagnation: true, detectCycling: false, tolerance: 0.5)
		let both = try solveFixture(detectStagnation: true, detectCycling: true, tolerance: 0.5)

		// Compared against a tolerance rather than exactly, and the reason is itself worth
		// recording: `objectiveValue` is the objective evaluated at the **relaxation** point
		// that passed the integrality test, not at the integer solution the result reports.
		// A point accepted as integral within `integralityTolerance` sits a little off the
		// lattice, so a solve that returns `integerSolution == [2, 0, 2]` — whose objective is
		// exactly 14 — reports 14.000000085084594. The gap is bounded by the integrality
		// tolerance times the objective's coefficient sum, and for a minimisation it falls on
		// the optimistic side, which also feeds the gap test that decides termination.
		let expected: Double = Self.integerOptimum
		let epsilon: Double = 1e-6
		let neitherError: Double = abs(neither.objective - expected)
		let stagnatingError: Double = abs(stagnating.objective - expected)
		#expect(neitherError < epsilon, "no guards: \(neither.objective)")
		#expect(stagnatingError < epsilon, "stagnation only: \(stagnating.objective)")

		let cyclingError: Double = abs(cycling.objective - expected)
		let bothError: Double = abs(both.objective - expected)
		#expect(cyclingError < epsilon, "cycling only: \(cycling.objective)")
		#expect(bothError < epsilon, "both guards: \(both.objective)")
	}

	/// A tolerance fine enough that no two vertices compare equal declares no cycle.
	///
	/// The companion to ``cyclingDetectionEndsTheRoundLoop``: that test shows the guard can
	/// fire, this one shows it does not fire at random. Together they are what distinguishes
	/// a working guard from one wired to `true`.
	@Test("A tolerance below the vertex spacing declares no cycle")
	func fineToleranceDeclaresNoCycle() throws {
		let off = try solveFixture(detectStagnation: false, detectCycling: false, tolerance: 1e-9)
		let on = try solveFixture(detectStagnation: false, detectCycling: true, tolerance: 1e-9)

		let roundsOff: Int = off.stats.cuttingRounds
		let roundsOn: Int = on.stats.cuttingRounds
		#expect(roundsOn == roundsOff,
				"at 1e-9 no two vertices are equal, so detection should change nothing; \(roundsOn) vs \(roundsOff)")
	}

	// MARK: - Stagnation

	/// Stagnation's `break` was placed correctly; this is the test that says so.
	///
	/// A coarse tolerance makes "the bound stopped improving" true early, so the guard has
	/// something to catch. The threshold is **0.5** rather than the 0.25 cycling uses, and the
	/// difference is the point: this fixture's LP bound improves by more than a quarter every
	/// round, so at 0.25 stagnation is never true and a test written there would have failed
	/// against working code. Swept before it was chosen — 32 rounds unguarded, 32 at 0.25, 28
	/// at 0.5, 6 at 1.0. The claim is the same one cycling owes: on is cheaper than off.
	@Test("Stagnation detection ends the round loop")
	func stagnationDetectionEndsTheRoundLoop() throws {
		let coarse: Double = 0.5
		let off = try solveFixture(detectStagnation: false, detectCycling: false, tolerance: coarse)
		let on = try solveFixture(detectStagnation: true, detectCycling: false, tolerance: coarse)

		let roundsOff: Int = off.stats.cuttingRounds
		let roundsOn: Int = on.stats.cuttingRounds
		#expect(roundsOn < roundsOff,
				"stagnation on ran \(roundsOn) rounds, off ran \(roundsOff)")
	}

	/// With both guards off the loop runs to its configured budget, which is what makes the
	/// comparisons above meaningful: the baseline is the budget, not an early exit for some
	/// third reason.
	@Test("With both guards off the loop spends its whole budget")
	func budgetIsSpentWhenUnguarded() throws {
		let budget: Int = 12
		let run = try solveFixture(detectStagnation: false, detectCycling: false, maxRounds: budget)
		let deepest: Int = run.stats.maxRoundsAtNode

		#expect(deepest == budget,
				"unguarded, the deepest node should exhaust the \(budget)-round budget; got \(deepest)")
	}
}
