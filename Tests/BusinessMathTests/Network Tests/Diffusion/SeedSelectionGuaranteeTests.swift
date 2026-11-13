//
//  SeedSelectionGuaranteeTests.swift
//  BusinessMath
//
//  Three properties of the seed selector that the ported suites do not state directly:
//
//  1. Lazy (CELF) evaluation equals a plain-greedy oracle, exactly, over many seeded graphs
//     and both models (picks and gains compared with ==, never within a tolerance).
//  2. A model that does not declare submodular trials gets every candidate refreshed every
//     round (ADR-005); a model that does declare it is allowed to skip most of them. The
//     refresh count is observed through a model that counts the trials it is asked to run.
//  3. Greedy reaches at least (1 - 1/e) of the brute-force optimum under independent cascade,
//     judged on trials the selector never saw, with a tolerance derived from the standard
//     errors of the two estimates.
//
//  Every random number comes from a fixed seed; nothing here is unseeded.
//

import Foundation
import SwiftDeterminism
import Testing

@testable import BusinessMath

// MARK: - Plain greedy oracle

/// Plain greedy, written independently of the engine: every round every unchosen node is scored
/// on the same trials, the largest total wins, the lowest index breaks ties.
private func plainGreedyOracle(
	model: any DiffusionModel, graph: WeightedGraph<Int>, budget: Int, trials: Int, seed: UInt64
) -> [(node: Int, gain: Double)] {
	let flat = DiffusionGraph(graph)
	let streams = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }
	func total(_ seeds: [Int]) -> Int {
		var sum = 0
		for stream in streams { sum += model.simulate(on: flat, seeds: seeds, randomness: stream) }
		return sum
	}
	var chosen: [Int] = []
	var current = 0
	var picks: [(node: Int, gain: Double)] = []
	for _ in 0..<min(budget, flat.nodeCount) {
		var best = -1
		var bestTotal = Int.min
		for candidate in 0..<flat.nodeCount where !chosen.contains(candidate) {
			let value = total(chosen + [candidate])
			if value > bestTotal { best = candidate; bestTotal = value }
		}
		picks.append((node: best, gain: Double(bestTotal - current) / Double(trials)))
		chosen.append(best)
		current = bestTotal
	}
	return picks
}

/// A seeded random graph, weighted or not, with every node present.
private func seededGraph(nodes: Int, density: Double, seed: UInt64, weighted: Bool) throws -> WeightedGraph<Int> {
	var rng = SplitMix64(seed: seed)
	var edges: [(Int, Int, Double)] = []
	for a in 0..<nodes {
		for b in (a + 1)..<max(a + 1, nodes) where Double.random(in: 0..<1, using: &rng) < density {
			edges.append((a, b, weighted ? Double.random(in: 0.25...4, using: &rng) : 1))
		}
	}
	return try WeightedGraph(edges: edges, isolatedNodes: Array(0..<nodes))
}

@Suite("Seed selection: lazy greedy against a plain-greedy oracle")
struct LazySoundnessOracleTests {

	/// Every way the selection differs from the oracle; empty means identical, exactly.
	private func differences(
		_ selection: NodeSelection<Int>, _ oracle: [(node: Int, gain: Double)], _ label: String
	) -> [String] {
		var found: [String] = []
		if selection.picks.count != oracle.count { found.append("\(label): pick count") }
		for (position, pair) in zip(selection.picks, oracle).enumerated() {
			if pair.0.node != pair.1.node { found.append("\(label): pick \(position) node") }
			if pair.0.marginalGain != pair.1.gain { found.append("\(label): pick \(position) gain") }
		}
		return found
	}

	@Test("Both models, several budgets (including over-budget) and refresh batches: exact pick and gain equality",
		  .timeLimit(.minutes(5)), arguments: Array(0..<48 as Range<UInt64>))
	func exactAgreement(seed: UInt64) throws {
		let nodes = 8 + Int(seed % 9)
		let graph = try seededGraph(
			nodes: nodes, density: 0.1 + Double(seed % 4) * 0.07, seed: seed &+ 500, weighted: seed % 2 == 0)
		let trials = 1 + Int(seed % 11)
		let models: [any DiffusionModel] = [
			try IndependentCascade(probability: 0.35),
			try IndependentCascade(weightScaledProbability: 0.6),
			LinearThreshold(),
		]
		for model in models {
			for budget in [1, 3, nodes, nodes + 3] {
				let oracle = plainGreedyOracle(model: model, graph: graph, budget: budget, trials: trials, seed: seed)
				for batch in [nil, 1, 2, 5] as [Int?] {
					let selector = SeedSelector<Int>(
						model: model, budget: budget, trials: trials, seed: seed, lazyRefreshBatch: batch)
					let found = differences(
						try selector.compute(on: graph), oracle,
						"\(type(of: model)) seed \(seed) budget \(budget) batch \(String(describing: batch))")
					#expect(found.isEmpty, "\(found)")
				}
			}
		}
	}
}

// MARK: - The submodularity gate (ADR-005), observed

/// Counts the trials a model is asked to run.
// Justification: every access to `value` is serialised by `lock`.
private final class TrialCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var value = 0

	func increment() {
		lock.lock()
		defer { lock.unlock() }
		value += 1
	}

	var count: Int {
		lock.lock()
		defer { lock.unlock() }
		return value
	}
}

/// A model that behaves exactly like its base but counts every trial, and declares whatever
/// it is told about submodularity.
private struct CountingModel: DiffusionModel {
	let base: any DiffusionModel
	let declaresSubmodular: Bool
	let counter: TrialCounter

	var hasSubmodularTrials: Bool { declaresSubmodular }

	func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
		counter.increment()
		return base.simulate(on: graph, seeds: seeds, randomness: randomness)
	}
}

@Suite("Seed selection: the submodularity gate (ADR-005)")
struct SubmodularityGateTests {

	/// Trials run by a selector that re-scores every candidate every round: the first pass
	/// scores all `n` nodes; each later round refreshes every node not yet chosen.
	private func exhaustiveCount(nodes: Int, picks: Int, trials: Int) -> Int {
		var evaluations = nodes
		if picks > 1 {
			for round in 1..<picks { evaluations += nodes - round }
		}
		return evaluations * trials
	}

	private func run(
		declaring: Bool, base: any DiffusionModel, graph: WeightedGraph<Int>, budget: Int, trials: Int,
		seed: UInt64, batch: Int?
	) throws -> (selection: NodeSelection<Int>, trialsRun: Int) {
		let counter = TrialCounter()
		let model = CountingModel(base: base, declaresSubmodular: declaring, counter: counter)
		let selection = try SeedSelector<Int>(
			model: model, budget: budget, trials: trials, seed: seed, lazyRefreshBatch: batch)
			.compute(on: graph)
		return (selection, counter.count)
	}

	@Test("A model that does not declare submodular trials has every candidate refreshed every round, however lazy the batch",
		  .timeLimit(.minutes(5)), arguments: [0, 1, 2, 3, 4, 5] as [UInt64])
	func undeclaredRefreshesEverything(seed: UInt64) throws {
		let graph = try seededGraph(nodes: 14, density: 0.15, seed: seed, weighted: true)
		let trials = 6
		for budget in [1, 2, 4, 14, 20] {
			for batch in [nil, 1, 3] as [Int?] {
				let result = try run(
					declaring: false, base: try IndependentCascade(probability: 0.4), graph: graph,
					budget: budget, trials: trials, seed: seed, batch: batch)
				let expected = exhaustiveCount(nodes: 14, picks: min(budget, 14), trials: trials)
				#expect(result.trialsRun == expected, "seed \(seed) budget \(budget) batch \(String(describing: batch))")
				let oracle = plainGreedyOracle(
					model: try IndependentCascade(probability: 0.4), graph: graph, budget: budget,
					trials: trials, seed: seed)
				#expect(result.selection.nodes == oracle.map(\.node))
			}
		}
	}

	@Test("The same model declared submodular is allowed to skip: it runs fewer trials, and picks the same nodes")
	func declaredSkips() throws {
		// A sparse graph with many isolated and low-gain nodes: after the first pick most
		// stale bounds are already below the leader, so a lazy pass refreshes only a few.
		let graph = try seededGraph(nodes: 40, density: 0.05, seed: 9, weighted: false)
		let trials = 8
		let base = try IndependentCascade(probability: 0.4)
		let lazy = try run(
			declaring: true, base: base, graph: graph, budget: 6, trials: trials, seed: 9, batch: 1)
		let eager = try run(
			declaring: false, base: base, graph: graph, budget: 6, trials: trials, seed: 9, batch: 1)
		#expect(lazy.selection == eager.selection)
		let exhaustive = exhaustiveCount(nodes: 40, picks: 6, trials: trials)
		#expect(eager.trialsRun == exhaustive)
		#expect(lazy.trialsRun < exhaustive)
		// The first pass always scores every node once.
		#expect(lazy.trialsRun >= 40 * trials)
	}

	/// Trials a lazy selector must run, from a reference that replays the refresh rule on the exact
	/// totals: take the `batch` best unchosen candidates by (gain descending, index ascending); if the
	/// best is current, pick it; otherwise re-score every stale one in that front and look again.
	private func lazyTrialCount(
		graph: WeightedGraph<Int>, model: any DiffusionModel, budget: Int, trials: Int, seed: UInt64, batch: Int
	) -> Int {
		let flat = DiffusionGraph(graph)
		let streams = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }
		func total(_ seeds: [Int]) -> Int {
			var sum = 0
			for stream in streams { sum += model.simulate(on: flat, seeds: seeds, randomness: stream) }
			return sum
		}
		let n = flat.nodeCount
		var gain = (0..<n).map { total([$0]) }
		var stamp = [Int](repeating: 0, count: n)
		var chosen = Set<Int>()
		var seeds: [Int] = []
		var current = 0
		var evaluations = n
		for pick in 0..<min(budget, n) {
			// Every pass refreshes at least the front-runner, so n + 1 passes always suffice.
			for _ in 0...n {
				let open = (0..<n).filter { !chosen.contains($0) }
				let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 < $1 }
				let front = Array(ordered.prefix(batch))
				guard let best = front.first else { break }
				if stamp[best] == pick {
					seeds.append(best)
					chosen.insert(best)
					current += gain[best]
					break
				}
				for candidate in front where stamp[candidate] != pick {
					gain[candidate] = total(seeds + [candidate]) - current
					stamp[candidate] = pick
					evaluations += 1
				}
			}
		}
		return evaluations * trials
	}

	@Test("A declared model's refresh work is exactly the lazy rule's, at every batch size",
		  .timeLimit(.minutes(5)), arguments: [1, 2, 3, 7] as [Int])
	func declaredWorkMatchesReference(batch: Int) throws {
		for seed in [3, 9, 12] as [UInt64] {
			let graph = try seededGraph(nodes: 36, density: 0.07, seed: seed, weighted: false)
			let base = try IndependentCascade(probability: 0.4)
			let result = try run(
				declaring: true, base: base, graph: graph, budget: 6, trials: 5, seed: seed, batch: batch)
			let expected = lazyTrialCount(
				graph: graph, model: base, budget: 6, trials: 5, seed: seed, batch: batch)
			#expect(result.trialsRun == expected, "seed \(seed) batch \(batch)")
		}
	}

	@Test("A declared model is refreshed in batches no larger than the batch asked for")
	func declaredBatchBound() throws {
		let graph = try seededGraph(nodes: 30, density: 0.08, seed: 4, weighted: false)
		let trials = 5
		let base = try IndependentCascade(probability: 0.5)
		let one = try run(declaring: true, base: base, graph: graph, budget: 5, trials: trials, seed: 4, batch: 1)
		let wide = try run(declaring: true, base: base, graph: graph, budget: 5, trials: trials, seed: 4, batch: 30)
		// A batch as wide as the graph refreshes every stale candidate at once, which is the
		// exhaustive count; a batch of one never does more work than that.
		#expect(wide.trialsRun == exhaustiveCount(nodes: 30, picks: 5, trials: trials))
		#expect(one.trialsRun <= wide.trialsRun)
		#expect(one.selection == wide.selection)
	}
}

// MARK: - Greedy against the brute-force optimum

@Suite("Seed selection: the (1 - 1/e) guarantee under independent cascade")
struct GreedyGuaranteeTests {

	private func subsets(of n: Int, size k: Int) -> [[Int]] {
		var out: [[Int]] = []
		var current: [Int] = []
		func go(_ start: Int) {
			if current.count == k { out.append(current); return }
			guard start < n else { return }
			for i in start..<n {
				current.append(i)
				go(i + 1)
				current.removeLast()
			}
		}
		go(0)
		return out
	}

	/// What a set's spread is, estimated on trials the selector never saw.
	private func evaluate(
		_ set: [Int], model: some DiffusionModel, graph: WeightedGraph<Int>, trials: Int, seed: UInt64
	) throws -> SpreadEstimate {
		try SpreadEstimator(trials: trials, seed: seed).estimate(model: model, on: graph, seeds: set)
	}

	/// The selector picks on stream `selectionSeed` with 100 trials; greedy and the best set
	/// over every k-subset are then both measured on stream `evaluationSeed` with 4,000 trials,
	/// which neither saw. The bar is
	///
	///     greedy >= (1 - 1/e) * best - 4 * (seGreedy + seBest)
	///
	/// where each se is the estimator's standard error of that set's mean. The two means are
	/// computed on the same trials, so their errors are positively correlated and the sum of the
	/// standard errors over-states the standard error of the difference: the tolerance is wider
	/// than a 4-sigma test needs, which makes a failure meaningful. Taking the best of many
	/// noisy subset estimates biases the optimum upward, which also only widens the margin.
	@Test("Greedy is within (1 - 1/e) of the brute-force optimum on unseen trials, up to 4 standard errors, k = 1...3",
		  .timeLimit(.minutes(5)), arguments: Array(1...6 as ClosedRange<UInt64>))
	func guarantee(seed: UInt64) throws {
		let graph = try seededGraph(nodes: 9, density: 0.25, seed: seed, weighted: false)
		let selectionSeed: UInt64 = 21 &+ seed
		let evaluationSeed: UInt64 = 7_000 &+ seed
		let selectionTrials = 100
		let evaluationTrials = 4_000
		let factor: Double = 1 - 1 / M_E
		for p in [0.2, 0.5] {
			let model = try IndependentCascade(probability: p)
			for k in 1...3 {
				let selection = try SeedSelector<Int>(
					model: model, budget: k, trials: selectionTrials, seed: selectionSeed).compute(on: graph)
				let greedySet = selection.nodes.compactMap { graph.indexOf[$0] }
				let greedy = try evaluate(
					greedySet, model: model, graph: graph, trials: evaluationTrials, seed: evaluationSeed)
				var best = try evaluate(
					[], model: model, graph: graph, trials: evaluationTrials, seed: evaluationSeed)
				for set in subsets(of: graph.nodeCount, size: k) {
					let candidate = try evaluate(
						set, model: model, graph: graph, trials: evaluationTrials, seed: evaluationSeed)
					if candidate.mean > best.mean { best = candidate }
				}
				let tolerance: Double = 4 * (greedy.standardError + best.standardError)
				let bar: Double = factor * best.mean - tolerance
				#expect(selection.picks.count == k)
				#expect(greedy.mean >= bar, "seed \(seed) p \(p) k \(k): greedy \(greedy.mean) bar \(bar)")
				// Sanity on the other side: greedy cannot beat the best set by more than noise.
				#expect(greedy.mean <= best.mean + tolerance, "seed \(seed) p \(p) k \(k)")
			}
		}
	}

	@Test("The guarantee is not vacuous: on a graph with one hub, greedy keeps most of the optimum, not just 63%")
	func hubGraph() throws {
		// A star at p = 1: the centre alone reaches everything, so the optimum for k = 1 is n + 1
		// and greedy must find it exactly; 63% of it would be a failure.
		let edges: [(Int, Int)] = (1...8).map { (0, $0) }
		let graph = WeightedGraph(unweightedEdges: edges)
		let model = try IndependentCascade(probability: 1)
		let selection = try SeedSelector<Int>(model: model, budget: 1, trials: 20, seed: 3).compute(on: graph)
		let spread = try evaluate(
			selection.nodes.compactMap { graph.indexOf[$0] }, model: model, graph: graph, trials: 50, seed: 8)
		#expect(spread.mean == 9)
		#expect(spread.standardError == 0)
	}
}
