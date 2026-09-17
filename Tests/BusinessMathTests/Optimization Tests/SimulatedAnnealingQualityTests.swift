import Testing
import Foundation
@testable import BusinessMath

/// Simulated annealing has to actually anneal.
///
/// ## What was wrong
///
/// Three of the algorithm's defining features were missing, and the result was a search that
/// spent about a hundred function evaluations and stopped. On `min ‖x‖²` from (5, 5, 5) over
/// `[-20, 20]³` — convex, three-dimensional, no local minima to escape — it returned a mean
/// objective of **7.34** across five seeds against an optimum of **0**. Nelder-Mead reaches
/// 5.5e-14 on the same problem.
///
/// ### The stagnation check ended the run during exploration, and called it convergence
///
/// It terminated when `bestEnergy` had not improved by 1e-6 over 100 proposals. But
/// `bestEnergy` is monotone, and at high temperature an annealing walker is *supposed* to
/// wander without improving on the best — that is the exploration the method exists for.
/// Measured with the shipped defaults: **105 evaluations, temperature still at 0.48** against a
/// target of 0.001, `converged == true`, objective 11.94. With a slow schedule it was worse and
/// clearer — 223 evaluations with the temperature at **97.8 out of an initial 100**, a run that
/// had not meaningfully begun, reported as converged.
///
/// ### One proposal per temperature is not a Markov chain
///
/// The loop generated a single neighbour and immediately cooled. Annealing works by letting the
/// walker approach equilibrium *at* each temperature before the temperature drops; with one
/// sample per level there is no equilibrium to approach. Even discounting the stagnation exit,
/// the schedule allowed only about 224 proposals in total.
///
/// ### A constant step cannot both travel and refine
///
/// Neighbours were drawn at `perturbationScale × range` regardless of temperature, so the late
/// phase — where the method should be polishing — was still proposing jumps of 8 units in a
/// 40-unit space. Sweeping the scale shows the U-shape that a fixed step always produces:
///
/// | `perturbationScale` | 0.2 | 0.05 | 0.01 | 0.002 |
/// |---|---|---|---|---|
/// | mean objective | 8.42 | 0.64 | **0.025** | 34.78 |
///
/// Too coarse to refine at one end, too fine to travel at the other, and the sweet spot depends
/// on the problem. Scaling the step with temperature is what removes the tuning problem.
@Suite("Simulated annealing quality")
struct SimulatedAnnealingQualityTests {

	typealias Vec = VectorN<Double>

	static let space: [(lower: Double, upper: Double)] = Array(
		repeating: (lower: -20.0, upper: 20.0), count: 3
	)

	static let sphere: @Sendable (Vec) -> Double = { point in
		point.toArray().reduce(0) { $0 + $1 * $1 }
	}

	static let start = Vec([5.0, 5.0, 5.0])

	private static func anneal(seed: UInt64) -> SimulatedAnnealingResult<Vec> {
		let optimizer = SimulatedAnnealing<Vec>(
			config: SimulatedAnnealingConfig(seed: seed),
			searchSpace: space
		)
		return optimizer.optimizeDetailed(objective: sphere, initialSolution: start)
	}

	/// The bar is deliberately far below what a good method reaches and far above what the old
	/// one did.
	///
	/// Nelder-Mead gets 5.5e-14 here and the old annealer averaged 7.34. Requiring 0.05 asks for
	/// two orders of improvement while leaving three orders of slack against a deterministic
	/// local method — which is the right shape for a stochastic global search on a problem that
	/// has nothing global about it.
	@Test("Annealing solves a convex problem it has no excuse to miss", arguments: [1, 2, 3, 4, 5])
	func annealingSolvesTheSphere(_ seed: Int) throws {
		let result = Self.anneal(seed: UInt64(seed))
		#expect(result.fitness < 0.05,
				"seed \(seed): objective \(result.fitness) at \(result.solution.toArray()), optimum is 0")
	}

	/// A run that stops after a hundred evaluations has not annealed, whatever it reports.
	///
	/// Not a performance assertion — it is what separates annealing from a short random walk. The
	/// shipped defaults allow 1,000 iterations and a schedule of roughly 224 temperature levels,
	/// so a few hundred evaluations means the loop left almost all of its budget unspent.
	@Test("Annealing spends its budget rather than quitting early", arguments: [1, 2, 3, 4, 5])
	func annealingSpendsItsBudget(_ seed: Int) throws {
		let result = Self.anneal(seed: UInt64(seed))
		#expect(result.evaluations > 1_000,
				"seed \(seed): \(result.evaluations) evaluations, ending at temperature \(result.finalTemperature)")
	}

	/// Convergence means the schedule finished, not that the walker had a quiet spell.
	///
	/// The clearest symptom of the old check: a run reported `converged` with its temperature at
	/// 97.8 out of an initial 100. Whatever that run was, it was not a completed anneal.
	@Test("A converged run has actually cooled", arguments: [1, 2, 3, 4, 5])
	func convergedRunsHaveCooled(_ seed: Int) throws {
		let result = Self.anneal(seed: UInt64(seed))
		guard result.converged else { return }

		let initial: Double = SimulatedAnnealingConfig.default.initialTemperature
		let ratio: Double = result.finalTemperature / initial
		#expect(ratio < 0.1,
				"seed \(seed): reported converged at temperature \(result.finalTemperature) of an initial \(initial) — \(result.convergenceReason)")
	}

	/// The reported objective is the objective at the reported point.
	///
	/// Cheap, and the class of defect it catches — a result whose value and solution disagree —
	/// has already been found twice in this package.
	@Test("The reported fitness is the objective at the reported solution", arguments: [1, 2, 3, 4, 5])
	func reportedFitnessMatchesSolution(_ seed: Int) throws {
		let result = Self.anneal(seed: UInt64(seed))
		let recomputed: Double = Self.sphere(result.solution)
		let discrepancy: Double = abs(result.fitness - recomputed)
		#expect(discrepancy < 1e-12,
				"seed \(seed): reported \(result.fitness), objective at the point is \(recomputed)")
	}
}
