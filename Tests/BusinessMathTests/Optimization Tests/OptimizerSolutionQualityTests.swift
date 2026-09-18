import Testing
import Foundation
@testable import BusinessMath

/// Does each optimizer actually solve problems whose answers are known?
///
/// ## Why this suite exists
///
/// Every heuristic here already had eighteen to twenty-one tests, and several of them asserted
/// something about the solution. They did not catch `SimulatedAnnealing` returning a mean
/// objective of **7.34** on `min ‖x‖²` against an optimum of **0**, because the tolerances they
/// asserted against included 3.0, 5.0, 10.0, 30.0, 50.0 and 100. A tolerance of 50 on a solution
/// component is not a quality assertion; it is a smoke test wearing one.
///
/// So this suite does the one thing those could not: it runs every optimizer against benchmarks
/// with **published, exactly known optima**, and holds each to a bar taken from measurement.
///
/// ## Where the bars come from
///
/// Measured, not chosen. Each optimizer was run on every benchmark across five seeds, and the
/// bar is set above the observed **worst** case with headroom — never trimmed to make a run
/// pass. Where an optimizer genuinely cannot reach an optimum, that is recorded as a number in
/// this file rather than absorbed into a wider tolerance, because the number is the finding.
///
/// The measured table, mean over five seeds, as of 2026-09-17:
///
/// | benchmark | NelderMead | SimAnnealing | DiffEvolution | ParticleSwarm | GeneticAlg | IslandModel |
/// |---|---|---|---|---|---|---|
/// | sphere (3d) | 9.0e-14 | 4.0e-5 | 2.8e-3 | 5.2e-6 | 6.2e-5 | 2.9e-5 |
/// | matyas | 2.3e-15 | 1.9e-4 | 2.1e-7 | 4.2e-6 | 2.7e-3 | 4.5e-4 |
/// | booth | 6.4e-14 | 7.1e-4 | 4.1e-3 | 6.5e-4 | 7.2e-2 | 2.1e-3 |
/// | beale | 3.7e-14 | 3.6e-3 | 7.8e-5 | 9.3e-5 | 9.3e-3 | 2.0e-3 |
/// | three-hump camel | **2.99e-1** | 3.5e-4 | 5.3e-5 | 2.1e-5 | 5.0e-4 | 2.7e-5 |
/// | rosenbrock | 3.9e-14 | 5.1e-3 | 1.2e-2 | 5.8e-4 | 2.0e-2 | 3.4e-3 |
/// | rastrigin | 0.0 | 5.3e-1 | 9.0e-1 | 5.1e-2 | 5.5e-1 | 3.3e-2 |
/// | ackley | 4.4e-16 | 2.9e-3 | 2.7e-4 | 3.6e-2 | 1.3e-1 | 1.1e-2 |
///
/// Two things that table says out loud:
///
/// - **Nelder-Mead is a local method and the three-hump camel entry is it behaving correctly.**
///   Started at (2, 2) it descends into the local minimum near (1.7, −0.8), whose value is
///   0.2986. A direct-search method is entitled to that; asserting it should find the global
///   minimum would be asserting that it is a different algorithm. It is held to the local
///   minimum instead, and that is stated rather than hidden.
/// - **`GeneticAlgorithm` is the weakest by orders of magnitude.** On matyas it averages 1.3e-2
///   where differential evolution averages 2.1e-7 — a factor of 60,000 on a smooth convex
///   quadratic, which is not a problem that should separate two population methods. Its bars
///   below are correspondingly loose, and that looseness is the point: they record what it does
///   rather than what it should do. It is the same shape simulated annealing had before its
///   inner Markov chain and temperature-scaled step were restored, and it is the next thing to
///   look at.
///
///   `IslandModel` sharpened the case. It *is* several genetic algorithms run in parallel with
///   the best result taken, so it inherits every weakness of the algorithm underneath — and it
///   still beat plain GA by roughly tenfold on every row. Taking the best of a handful of runs
///   should not recover an order of magnitude from a healthy optimizer; that it did said the
///   run-to-run variance was the problem, not the search.
///
///   **Both were fixed on 2026-09-17** and the table above is the result. The genetic algorithm
///   had the same two defects annealing did — a mutation width that never narrowed, and a
///   stagnation check that fired during ordinary operation and ended the run at generation 10 of
///   a configured 100. Sphere improved 700-fold, booth 78-fold, three-hump camel 310-fold, and
///   `IslandModel` inherited all of it.
///
///   **The schedule's shape was chosen against an existing test, not against this table.** The
///   first attempt decayed the mutation width to a hundredth across `config.generations`, which
///   is a *fraction of the configured run* — so a thirty-generation run narrowed exactly as fast
///   as a sixteen-hundred-generation one. It scored better here (sphere 1.2e-5, booth 4.9e-3) and
///   failed the ten-dimensional benchmark in `GeneticAlgorithmTests`, which starts at
///   `‖x‖² = 250` with thirty generations to cross it: 17.4 against a bar of 5.0.
///
///   A half-life in generations replaced it, so the depth of the decay follows the length of the
///   run. That costs sharpness on the easy unimodal problems and buys back Rosenbrock, whose
///   narrow curved valley rewards sustained travel — 6.6e-2 under the fraction schedule against
///   2.0e-2 here. Every benchmark still improves on the original: sphere by 137-fold, three-hump
///   camel by 30, booth by 5, Rosenbrock by nearly 2. No existing bar was loosened to get there.
@Suite("Optimizer solution quality")
struct OptimizerSolutionQualityTests {

	typealias Vec = VectorN<Double>

	// MARK: - Benchmarks with known optima

	struct Benchmark: Sendable {
		let name: String
		let objective: @Sendable (Vec) -> Double
		let dimension: Int
		let lower: Double
		let upper: Double
		/// The published global minimum of the objective.
		let optimum: Double
		/// Where the local methods start from.
		let start: [Double]
		/// Whether the landscape has minima other than the global one.
		let multimodal: Bool
	}

	static let sphere = Benchmark(
		name: "sphere", objective: { $0.toArray().reduce(0) { $0 + $1 * $1 } },
		dimension: 3, lower: -5.12, upper: 5.12, optimum: 0, start: [3, 3, 3], multimodal: false
	)

	static let matyas = Benchmark(
		name: "matyas",
		objective: { point in
			let a = point.toArray()
			let quadratic: Double = 0.26 * (a[0] * a[0] + a[1] * a[1])
			let cross: Double = 0.48 * a[0] * a[1]
			return quadratic - cross
		},
		dimension: 2, lower: -10, upper: 10, optimum: 0, start: [5, 5], multimodal: false
	)

	static let booth = Benchmark(
		name: "booth",
		objective: { point in
			let a = point.toArray()
			let first: Double = a[0] + 2 * a[1] - 7
			let second: Double = 2 * a[0] + a[1] - 5
			return first * first + second * second
		},
		dimension: 2, lower: -10, upper: 10, optimum: 0, start: [0, 0], multimodal: false
	)

	static let beale = Benchmark(
		name: "beale",
		objective: { point in
			let a = point.toArray()
			let first: Double = 1.5 - a[0] + a[0] * a[1]
			let second: Double = 2.25 - a[0] + a[0] * a[1] * a[1]
			let third: Double = 2.625 - a[0] + a[0] * a[1] * a[1] * a[1]
			return first * first + second * second + third * third
		},
		dimension: 2, lower: -4.5, upper: 4.5, optimum: 0, start: [1, 1], multimodal: false
	)

	/// Three-hump camel: global minimum 0 at the origin, with two other local minima.
	static let threeHump = Benchmark(
		name: "three-hump camel",
		objective: { point in
			let a = point.toArray()
			let x = a[0], y = a[1]
			let squared: Double = 2 * x * x
			let quartic: Double = 1.05 * x * x * x * x
			let sextic: Double = x * x * x * x * x * x / 6
			return squared - quartic + sextic + x * y + y * y
		},
		dimension: 2, lower: -5, upper: 5, optimum: 0, start: [2, 2], multimodal: true
	)

	/// Rosenbrock: a narrow curved valley, the classic test of a method's ability to follow one.
	static let rosenbrock = Benchmark(
		name: "rosenbrock",
		objective: { point in
			let a = point.toArray()
			let curve: Double = a[1] - a[0] * a[0]
			let offset: Double = 1 - a[0]
			return 100 * curve * curve + offset * offset
		},
		dimension: 2, lower: -2, upper: 2, optimum: 0, start: [-1.2, 1.0], multimodal: false
	)

	/// Rastrigin: a paraboloid covered in regularly spaced local minima.
	static let rastrigin = Benchmark(
		name: "rastrigin",
		objective: { point in
			let a = point.toArray()
			var total: Double = 10 * Double(a.count)
			for x in a {
				let wave: Double = 10 * Foundation.cos(2 * Double.pi * x)
				total += x * x - wave
			}
			return total
		},
		dimension: 2, lower: -5.12, upper: 5.12, optimum: 0, start: [3, 3], multimodal: true
	)

	/// Ackley: a nearly flat outer region around a narrow global basin.
	static let ackley = Benchmark(
		name: "ackley",
		objective: { point in
			let a = point.toArray()
			let n = Double(a.count)
			let meanSquare: Double = a.reduce(0) { $0 + $1 * $1 } / n
			let meanCosine: Double = a.reduce(0) { $0 + Foundation.cos(2 * Double.pi * $1) } / n
			let firstTerm: Double = -20 * Foundation.exp(-0.2 * meanSquare.squareRoot())
			let secondTerm: Double = Foundation.exp(meanCosine)
			return firstTerm - secondTerm + 20 + M_E
		},
		dimension: 2, lower: -5, upper: 5, optimum: 0, start: [2, 2], multimodal: true
	)

	static let benchmarks: [Benchmark] = [
		sphere, matyas, booth, beale, threeHump, rosenbrock, rastrigin, ackley
	]

	// MARK: - The optimizers, and the bars they are held to

	enum Optimizer: String, CaseIterable, Sendable {
		case nelderMead
		case simulatedAnnealing
		case differentialEvolution
		case particleSwarm
		case geneticAlgorithm
		case islandModel

		/// The bar on a landscape with one minimum, set above the measured worst case.
		var unimodalBar: Double {
			switch self {
			case .nelderMead: return 1e-10            // measured 9.0e-14
			case .simulatedAnnealing: return 3e-2      // measured worst 8.3e-3
			case .differentialEvolution: return 1e-1   // measured worst 3.8e-2
			case .particleSwarm: return 1e-2           // measured worst 1.9e-3
			case .geneticAlgorithm: return 1.0         // measured worst 3.2e-1 (booth)
			case .islandModel: return 3e-2             // measured worst 7.5e-3 (rosenbrock)
			}
		}

		/// The bar on a landscape with many minima, where a stochastic method may land in the
		/// wrong basin and a local one almost certainly will.
		var multimodalBar: Double {
			switch self {
			case .nelderMead: return 3.1e-1            // the three-hump local minimum, 0.2986
			case .simulatedAnnealing: return 3.0
			case .differentialEvolution: return 6.0
			case .particleSwarm: return 1.0
			case .geneticAlgorithm: return 4.0         // measured worst 1.3 (rastrigin)
			case .islandModel: return 5e-1             // measured worst 1.4e-1 (rastrigin)
			}
		}
	}

	private static func space(_ benchmark: Benchmark) -> [(lower: Double, upper: Double)] {
		Array(repeating: (lower: benchmark.lower, upper: benchmark.upper), count: benchmark.dimension)
	}

	/// One run, returning the objective the optimizer reports.
	private static func solve(
		_ optimizer: Optimizer, _ benchmark: Benchmark, seed: UInt64
	) throws -> (value: Double, solution: Vec) {
		let bounds = space(benchmark)
		let start = Vec(benchmark.start)

		switch optimizer {
		case .nelderMead:
			let result = NelderMead<Vec>().optimizeDetailed(
				objective: benchmark.objective, initialGuess: start)
			return (result.value, result.solution)
		case .simulatedAnnealing:
			let result = SimulatedAnnealing<Vec>(config: .init(seed: seed), searchSpace: bounds)
				.optimizeDetailed(objective: benchmark.objective, initialSolution: start)
			return (result.fitness, result.solution)
		case .differentialEvolution:
			let result = try DifferentialEvolution<Vec>(config: .init(seed: seed), searchSpace: bounds)
				.optimizeDetailed(objective: benchmark.objective)
			return (result.fitness, result.solution)
		case .particleSwarm:
			let result = try ParticleSwarmOptimization<Vec>(config: .init(seed: seed), searchSpace: bounds)
				.optimizeDetailed(objective: benchmark.objective)
			return (result.fitness, result.solution)
		case .geneticAlgorithm:
			let result = try GeneticAlgorithm<Vec>(config: .init(seed: seed), searchSpace: bounds)
				.optimizeDetailed(objective: benchmark.objective)
			return (result.fitness, result.solution)
		case .islandModel:
			let result = IslandModel<Vec>(
				gaConfig: .init(seed: seed),
				islandConfig: IslandModelConfig(),
				searchSpace: bounds
			).optimizeDetailed(objective: benchmark.objective)
			return (result.bestFitness, result.solution)
		}
	}

	static let seeds: [UInt64] = [1, 2, 3, 4, 5]

	// MARK: - The claims

	/// Every optimizer reaches its measured bar on every benchmark, at every seed.
	///
	/// Stated per seed rather than on the mean, because a mean lets one good run pay for four bad
	/// ones — and a caller gets a single run, not an average of five.
	@Test("Each optimizer reaches its measured bar",
		  arguments: Optimizer.allCases, benchmarks.indices)
	func optimizerReachesItsBar(_ optimizer: Optimizer, _ index: Int) throws {
		let benchmark = Self.benchmarks[index]
		let bar: Double = benchmark.multimodal ? optimizer.multimodalBar : optimizer.unimodalBar

		for seed in Self.seeds {
			let run = try Self.solve(optimizer, benchmark, seed: seed)
			let excess: Double = run.value - benchmark.optimum
			#expect(excess < bar,
					"\(optimizer.rawValue) on \(benchmark.name), seed \(seed): reached \(run.value) at \(run.solution.toArray()), optimum \(benchmark.optimum), bar \(bar)")
		}
	}

	/// No optimizer reports a value below the benchmark's published optimum.
	///
	/// A minimiser that returns less than the true minimum has not found a better answer — it has
	/// found a bug, and the two have been confused twice already in this package. Branch-and-cut
	/// reported 8.8227 for a constrained problem whose optimum was 9 because it was standing
	/// outside the feasible set, and the constrained heuristics did the same thing for the same
	/// reason.
	@Test("No optimizer beats the published optimum",
		  arguments: Optimizer.allCases, benchmarks.indices)
	func noOptimizerBeatsTheOptimum(_ optimizer: Optimizer, _ index: Int) throws {
		let benchmark = Self.benchmarks[index]
		// One part in 10^9 of slack for the arithmetic, and not a part more.
		let slack: Double = 1e-9 * Swift.max(1.0, Swift.abs(benchmark.optimum))

		for seed in Self.seeds {
			let run = try Self.solve(optimizer, benchmark, seed: seed)
			let shortfall: Double = benchmark.optimum - run.value
			#expect(shortfall < slack,
					"\(optimizer.rawValue) on \(benchmark.name), seed \(seed): reported \(run.value), below the optimum \(benchmark.optimum) by \(shortfall)")
		}
	}

	/// The reported objective is the objective at the reported point.
	///
	/// Cheap, universal, and the class of defect it catches has been found three times in this
	/// package — most recently where an integer solution of (2, 0, 2) was reported alongside a
	/// value of 14.000000085 for an objective that is exactly 14 there.
	@Test("The reported value is the objective at the reported point",
		  arguments: Optimizer.allCases, benchmarks.indices)
	func reportedValueMatchesTheSolution(_ optimizer: Optimizer, _ index: Int) throws {
		let benchmark = Self.benchmarks[index]

		for seed in Self.seeds {
			let run = try Self.solve(optimizer, benchmark, seed: seed)
			let recomputed: Double = benchmark.objective(run.solution)
			let scale: Double = Swift.max(1.0, Swift.abs(recomputed))
			let discrepancy: Double = abs(run.value - recomputed)
			#expect(discrepancy < 1e-9 * scale,
					"\(optimizer.rawValue) on \(benchmark.name), seed \(seed): reported \(run.value), objective at the point is \(recomputed)")
		}
	}

	/// The returned point lies inside the search space it was given.
	///
	/// Only the bounded methods make this promise — Nelder-Mead takes a starting point rather
	/// than a box, and is free to leave.
	@Test("A bounded optimizer stays inside its search space",
		  arguments: Optimizer.allCases.filter { $0 != .nelderMead }, benchmarks.indices)
	func boundedOptimizersRespectTheirSpace(_ optimizer: Optimizer, _ index: Int) throws {
		let benchmark = Self.benchmarks[index]

		for seed in Self.seeds {
			let run = try Self.solve(optimizer, benchmark, seed: seed)
			for (axis, value) in run.solution.toArray().enumerated() {
				let belowFloor: Bool = value < benchmark.lower - 1e-9
				let aboveCeiling: Bool = value > benchmark.upper + 1e-9
				#expect(!belowFloor && !aboveCeiling,
						"\(optimizer.rawValue) on \(benchmark.name), seed \(seed): component \(axis) is \(value), outside [\(benchmark.lower), \(benchmark.upper)]")
			}
		}
	}
}
