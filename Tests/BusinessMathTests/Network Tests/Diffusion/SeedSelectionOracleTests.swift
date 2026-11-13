//
//  SeedSelectionOracleTests.swift
//  BusinessMath
//
//  Seed-selection and sweep oracles. Ported from SwiftGraphMetrics's DiffusionTests.
//
//  Lazy selection is compared with a plain greedy written here; the stability summary of a
//  sweep with hand arithmetic and with set arithmetic.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

private typealias F = DiffusionFixtures

private func star(leaves: Int) -> WeightedGraph<String> { F.star(leaves: leaves) }
private func near(_ a: Double, _ b: Double) -> Bool { F.near(a, b) }
private func kite() -> WeightedGraph<String> { F.kite() }
private func karate() -> WeightedGraph<Int> { F.karate() }
private func randomGraph(nodes: Int, edgeProbability: Double, seed: UInt64) -> WeightedGraph<Int> {
	F.randomGraph(nodes: nodes, edgeProbability: edgeProbability, seed: seed)
}

private func randomWeightedGraph(
	nodes: Int, edgeProbability: Double, seed: UInt64, weighted: Bool
) throws -> WeightedGraph<Int> {
	try F.randomWeightedGraph(nodes: nodes, edgeProbability: edgeProbability, seed: seed, weighted: weighted)
}
private let oracleSeeds: [UInt64] = F.oracleSeeds

@Suite("Diffusion: seed selection oracles")
struct SeedSelectionOracleTests {

	/// Plain greedy with no laziness: every round evaluates every unchosen node, picks the
	/// largest total (lowest index on ties). By submodularity this is what CELF must equal.
	private func plainGreedy(
		_ model: some DiffusionModel, _ g: WeightedGraph<Int>, budget: Int, trials: Int, seed: UInt64
	) throws -> [(node: Int, gain: Double)] {
		let flat = DiffusionGraph(g)
		func total(_ seeds: [Int]) -> Int {
			(0..<trials).reduce(0) {
				$0 + model.simulate(on: flat, seeds: seeds, randomness: TrialRandomness(masterSeed: seed, trial: $1))
			}
		}
		var chosen: [Int] = []
		var current = 0
		var picks: [(Int, Double)] = []
		for _ in 0..<min(budget, g.nodeCount) {
			var best = -1
			var bestTotal = Int.min
			for candidate in 0..<g.nodeCount where !chosen.contains(candidate) {
				let value = total(chosen + [candidate])
				if value > bestTotal { bestTotal = value; best = candidate }
			}
			picks.append((g.nodes[best], Double(bestTotal - current) / Double(trials)))
			chosen.append(best)
			current = bestTotal
		}
		return picks
	}

	@Test("Lazy CELF selection equals plain greedy, node for node and gain for gain", .timeLimit(.minutes(5)),
		  arguments: oracleSeeds)
	func celfEqualsPlainGreedy(seed: UInt64) throws {
		let g = try randomWeightedGraph(nodes: 18, edgeProbability: 0.12, seed: seed, weighted: false)
		for p in [0.0, 0.15, 0.4, 1.0] {
			let model = try IndependentCascade(probability: p)
			for budget in [1, 4, 18, 25] {
				let selection = try SeedSelector<Int>(model: model, budget: budget, trials: 40, seed: seed).compute(on: g)
				let oracle = try plainGreedy(model, g, budget: budget, trials: 40, seed: seed)
				#expect(selection.nodes == oracle.map(\.node), "seed \(seed) p \(p) budget \(budget)")
				for (pick, want) in zip(selection.picks, oracle) {
					#expect(abs(pick.marginalGain - want.gain) < 1e-12, "seed \(seed) p \(p) budget \(budget)")
				}
				// Submodular: later picks never gain more than earlier ones.
				let gains = selection.picks.map(\.marginalGain)
				#expect(zip(gains, gains.dropFirst()).allSatisfy { $1 <= $0 + 1e-12 })
				#expect(Set(selection.nodes).count == selection.picks.count)
			}
		}
	}

	@Test("Weight-scaled cascades select like plain greedy too", .timeLimit(.minutes(5)), arguments: [1, 2, 3] as [UInt64])
	func weightScaledSelection(seed: UInt64) throws {
		let g = try randomWeightedGraph(nodes: 14, edgeProbability: 0.2, seed: seed, weighted: true)
		let model = try IndependentCascade(weightScaledProbability: 0.7)
		let selection = try SeedSelector<Int>(model: model, budget: 5, trials: 40, seed: seed).compute(on: g)
		#expect(selection.nodes == (try plainGreedy(model, g, budget: 5, trials: 40, seed: seed)).map(\.node))
	}

	/// Linear threshold is submodular only in expectation, not trial by trial, so lazy and
	/// plain greedy are not guaranteed to agree under it. They did on 40 of 40 random graphs
	/// when probed on 2026-11-11, so this asserts it on three fixed seeds: a regression in
	/// the refresh logic would show here. If a future change legitimately breaks the equality,
	/// re-derive whether the difference is the model's or the code's before touching this.
	@Test("Lazy selection equals plain greedy under linear threshold on three fixed seeds",
		  .timeLimit(.minutes(5)), arguments: [1, 2, 3] as [UInt64])
	func linearThresholdSelection(seed: UInt64) throws {
		let g = try randomWeightedGraph(nodes: 16, edgeProbability: 0.2, seed: seed, weighted: true)
		let selection = try SeedSelector<Int>(model: LinearThreshold(), budget: 5, trials: 40, seed: seed).compute(on: g)
		let oracle = try plainGreedy(LinearThreshold(), g, budget: 5, trials: 40, seed: seed)
		#expect(selection.nodes == oracle.map(\.node))
		for (pick, want) in zip(selection.picks, oracle) { #expect(abs(pick.marginalGain - want.gain) < 1e-12) }
	}

	@Test("Marginal gains telescope to the spread of the chosen set, for both models", .timeLimit(.minutes(5)),
		  arguments: [1, 2, 3] as [UInt64])
	func gainsTelescope(seed: UInt64) throws {
		let g = try randomWeightedGraph(nodes: 16, edgeProbability: 0.18, seed: seed, weighted: true)
		let models: [any DiffusionModel] = [try IndependentCascade(probability: 0.3), LinearThreshold()]
		for model in models {
			let selection = try SeedSelector<Int>(model: model, budget: 4, trials: 50, seed: seed).compute(on: g)
			let spread = try SpreadEstimator(trials: 50, seed: seed)
				.estimate(model: model, on: g, seeds: selection.nodes.compactMap { g.indexOf[$0] }).mean
			#expect(abs(selection.totalGain - spread) < 1e-9)
			// The first pick is the best single node.
			let singles = try (0..<16).map {
				try SpreadEstimator(trials: 50, seed: seed).estimate(model: model, on: g, seeds: [$0]).mean
			}
			let bestSingle = try #require(singles.max())
			#expect(abs(selection.picks[0].marginalGain - bestSingle) < 1e-9)
			#expect(g.indexOf[selection.nodes[0]] == singles.firstIndex(of: bestSingle))
		}
	}

	@Test("The linear threshold selection is deterministic and no worse than the worst-connected nodes")
	func linearThresholdBeatsPeripheral() throws {
		let g = karate()
		let selection = try SeedSelector<Int>(model: LinearThreshold(), budget: 3, trials: 100, seed: 8).compute(on: g)
		let estimator = try SpreadEstimator(trials: 100, seed: 8)
		let degrees = (0..<g.nodeCount).map { g.neighbourCount($0) }
		let peripheral = (0..<g.nodeCount).sorted { (degrees[$0], $0) < (degrees[$1], $1) }.prefix(3)
		let chosen = estimator.estimate(
			model: LinearThreshold(), on: g, seeds: selection.nodes.compactMap { g.indexOf[$0] }).mean
		let weak = estimator.estimate(model: LinearThreshold(), on: g, seeds: Array(peripheral)).mean
		// Measured on 2026-11-11 (seed 8, 100 trials): chosen 25.6, peripheral 6.08. Both come
		// from the same trials, so this is a comparison, not an estimate; the bar of one node
		// only says "clearly more" and has a factor of about 19 of headroom.
		#expect(chosen > weak + 1, "chosen \(chosen) vs peripheral \(weak)")
	}

	@Test("Ties resolve to the lowest node index; zero probability picks nodes in order")
	func tieOrder() throws {
		let g = WeightedGraph(unweightedEdges: [("m", "n")], isolatedNodes: ["a", "z", "q"])
		let selection = try SeedSelector<String>(
			model: try IndependentCascade(probability: 0), budget: 5, trials: 7, seed: 1).compute(on: g)
		#expect(selection.nodes == ["a", "m", "n", "q", "z"])
		#expect(selection.picks.allSatisfy { near($0.marginalGain, 1) })
		#expect(near(selection.totalGain, 5))
	}

	@Test("Marginal gain is zero for a node already reached with certainty")
	func redundantNode() throws {
		// Path a-b-c at p = 1: after seeding anything the rest is already reached.
		let g = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		let selection = try SeedSelector<String>(
			model: try IndependentCascade(probability: 1), budget: 3, trials: 5, seed: 1).compute(on: g)
		#expect(selection.nodes == ["a", "b", "c"])
		#expect(selection.picks.map(\.marginalGain) == [3, 0, 0])
	}

	@Test("The async selection equals the dispatch selection on random graphs", .timeLimit(.minutes(5)), arguments: [1, 2, 3] as [UInt64])
	func asyncEqualsSync(seed: UInt64) async throws {
		let g = try randomWeightedGraph(nodes: 20, edgeProbability: 0.1, seed: seed, weighted: true)
		let selector = SeedSelector<Int>(model: try IndependentCascade(probability: 0.3), budget: 6, trials: 30, seed: seed)
		#expect(try selector.compute(on: g) == (try await selector.computeAsync(on: g)))
		let empty = try WeightedGraph<Int>(edges: [])
		#expect(try await selector.computeAsync(on: empty).picks.isEmpty)
		let bad = SeedSelector<Int>(model: try IndependentCascade(probability: 0.3), budget: -2, trials: 30, seed: 1)
		await #expect(throws: DiffusionError.invalidBudget(-2)) { try await bad.computeAsync(on: g) }
		let none = SeedSelector<Int>(model: try IndependentCascade(probability: 0.3), budget: 2, trials: 0, seed: 1)
		await #expect(throws: DiffusionError.invalidTrialCount(0)) { try await none.computeAsync(on: g) }
		// Trials are validated before the budget.
		let both = SeedSelector<Int>(model: try IndependentCascade(probability: 0.3), budget: -1, trials: -1, seed: 1)
		await #expect(throws: DiffusionError.invalidTrialCount(-1)) { try await both.computeAsync(on: g) }
	}

	@Test("NodeSelection round-trips through JSON and its envelope, for seeded arbitrary picks",
		  arguments: [1, 2, 3, 4] as [UInt64])
	func nodeSelectionRoundTrip(seed: UInt64) throws {
		var rng = SplitMix64(seed: seed)
		let picks = (0..<Int.random(in: 0...12, using: &rng)).map { _ in
			NodeSelection<Int>.Pick(
				node: Int.random(in: -50...50, using: &rng),
				marginalGain: Double.random(in: 0...1e5, using: &rng))
		}
		let original = NodeSelection(picks)
		let back = try JSONDecoder().decode(NodeSelection<Int>.self, from: try JSONEncoder().encode(original))
		#expect(back == original)
		#expect(try MetricEnvelope(original).value(as: NodeSelection<Int>.self) == original)
		#expect(NodeSelection<Int>.kind == "selection")
		#expect(original.nodes == picks.map(\.node))
		#expect(abs(original.totalGain - picks.reduce(0) { $0 + $1.marginalGain }) < 1e-6)
		#expect(NodeSelection<Int>(picks: picks.map { ($0.node, $0.marginalGain) }) == original)
	}
}

@Suite("Diffusion: sweep")
struct SweepOracleTests {

	private func point(_ p: Double, _ nodes: [Int]) -> SweepPoint<Int> {
		SweepPoint(probability: p, selection: NodeSelection(picks: nodes.map { ($0, 1.0) }))
	}

	@Test("Hand-checked stability summary: partial overlaps, the always-picked set, an empty pick")
	func handChecked() throws {
		// Sets {1,2}, {2,3}, {3}: J01 = 1/3, J02 = 0, J12 = 1/2. Mean = (1/3 + 0 + 1/2) / 3 = 5/18.
		let sweep = SeedSweep(results: [point(0.1, [1, 2]), point(0.2, [2, 3]), point(0.3, [3])])
		#expect(near(sweep.pairwiseJaccard[0][1], 1.0 / 3))
		#expect(near(sweep.pairwiseJaccard[1][0], 1.0 / 3))
		#expect(near(sweep.pairwiseJaccard[0][2], 0))
		#expect(near(sweep.pairwiseJaccard[1][2], 0.5))
		#expect(near(sweep.pairwiseJaccard[2][1], 0.5))
		#expect((0..<3).allSatisfy { near(sweep.pairwiseJaccard[$0][$0], 1) })
		#expect(near(sweep.meanPairwiseJaccard, 5.0 / 18))
		let third: Double = 1.0 / 3
		let twoThirds: Double = 2.0 / 3
		let expectedFrequency: [Int: Double] = [1: third, 2: twoThirds, 3: twoThirds]
		#expect(sweep.topKFrequency.count == 3)
		for (node, want) in expectedFrequency {
			let got = try #require(sweep.topKFrequency[node])
			#expect(near(got, want))
		}
		#expect(sweep.alwaysPicked.isEmpty)
		#expect(sweep.results.map(\.probability).elementsEqual([0.1, 0.2, 0.3]) { $0.isEqual(to: $1) })

		let steady = SeedSweep(results: [point(0.1, [5, 1, 9]), point(0.2, [9, 5]), point(0.3, [1, 5, 9, 4])])
		#expect(steady.alwaysPicked == [5, 9])
		let four = try #require(steady.topKFrequency[4])
		#expect(near(four, 1.0 / 3))

		// Two empty sets are identical; an empty set and a non-empty one share nothing.
		let empties = SeedSweep(results: [point(0, []), point(1, []), point(2, [7])])
		#expect(near(empties.pairwiseJaccard[0][1], 1))
		#expect(near(empties.pairwiseJaccard[0][2], 0))
		#expect(near(empties.meanPairwiseJaccard, 1.0 / 3))
	}

	@Test("Degenerate sweeps: no points, one point")
	func degenerate() {
		let none = SeedSweep<Int>(results: [])
		#expect(none.topKFrequency.isEmpty && none.pairwiseJaccard.isEmpty && none.alwaysPicked.isEmpty)
		#expect(near(none.meanPairwiseJaccard, 1))
		let one = SeedSweep(results: [point(0.5, [4, 2])])
		#expect(one.pairwiseJaccard == [[1.0]])
		#expect(near(one.meanPairwiseJaccard, 1))
		#expect(one.alwaysPicked == [2, 4])
	}

	@Test("Jaccard matrix: symmetric, unit diagonal, in [0, 1], equal to set arithmetic, for seeded random picks",
		  arguments: [1, 2, 3, 4, 5, 6] as [UInt64])
	func jaccardProperties(seed: UInt64) {
		var rng = SplitMix64(seed: seed)
		let sets = (0..<Int.random(in: 2...7, using: &rng)).map { _ in
			Array(Set((0..<Int.random(in: 0...6, using: &rng)).map { _ in Int.random(in: 0..<9, using: &rng) }))
		}
		let sweep = SeedSweep(results: sets.enumerated().map { point(Double($0), $1) })
		var total = 0.0
		var pairs = 0
		for i in sets.indices {
			#expect(near(sweep.pairwiseJaccard[i][i], 1))
			for j in sets.indices where j != i {
				#expect(sweep.pairwiseJaccard[i][j] == sweep.pairwiseJaccard[j][i])
				let a = Set(sets[i]), b = Set(sets[j])
				let union = a.union(b).count
				let want = union == 0 ? 1.0 : Double(a.intersection(b).count) / Double(union)
				#expect(near(sweep.pairwiseJaccard[i][j], want))
				#expect((0.0...1.0).contains(sweep.pairwiseJaccard[i][j]))
				if j > i { total += want; pairs += 1 }
			}
		}
		#expect(near(sweep.meanPairwiseJaccard, total / Double(pairs)))
		for (node, frequency) in sweep.topKFrequency {
			#expect(near(frequency, Double(sets.filter { $0.contains(node) }.count) / Double(sets.count)))
		}
		#expect(sweep.alwaysPicked == sweep.topKFrequency.filter { $0.value == 1 }.keys.sorted())
		#expect(sweep.alwaysPicked == sweep.alwaysPicked.sorted())
	}

	@Test("Each sweep point is the selector run at that probability with the same master seed")
	func pointsAreSelectorRuns() throws {
		let g = try randomWeightedGraph(nodes: 15, edgeProbability: 0.15, seed: 6, weighted: false)
		let probabilities = [0.05, 0.3, 0.7]
		let sweep = try SeedSelector<Int>.sweep(on: g, probabilities: probabilities, budget: 3, trials: 40, seed: 13)
		#expect(sweep.results.map(\.probability).elementsEqual(probabilities) { $0.isEqual(to: $1) })
		for (point, p) in zip(sweep.results, probabilities) {
			let direct = try SeedSelector<Int>(
				model: try IndependentCascade(probability: p), budget: 3, trials: 40, seed: 13).compute(on: g)
			#expect(point.selection == direct, "p \(p)")
		}
	}

	@Test("A custom model builder is used at every probability: each point equals the selector run with that model")
	func customModelBuilder() throws {
		let g = try randomWeightedGraph(nodes: 15, edgeProbability: 0.15, seed: 6, weighted: true)
		let probabilities = [0.2, 0.6]
		let sweep = try SeedSelector<Int>.sweep(
			on: g, probabilities: probabilities, budget: 2, trials: 30, seed: 3,
			model: { try IndependentCascade(weightScaledProbability: $0) })
		for (point, p) in zip(sweep.results, probabilities) {
			let direct = try SeedSelector<Int>(
				model: try IndependentCascade(weightScaledProbability: p), budget: 2, trials: 30, seed: 3).compute(on: g)
			#expect(point.selection == direct)
		}
		#expect(throws: DiffusionError.invalidProbability(3)) {
			try SeedSelector<Int>.sweep(
				on: g, probabilities: [0.1, 3], budget: 1, trials: 5, seed: 1,
				model: { try IndependentCascade(weightScaledProbability: $0) })
		}
		#expect(throws: DiffusionError.invalidBudget(-1)) {
			try SeedSelector<Int>.sweep(on: g, probabilities: [0.1], budget: -1, trials: 5, seed: 1)
		}
	}
}

@Suite("Diffusion: seed selection boundaries")
struct SeedSelectionBoundaryTests {

	@Test("A single trial is a valid trial count for the selector, the estimator and the sweep")
	func oneTrial() throws {
		let g = karate()
		let model = try IndependentCascade(probability: 0.3)
		let selection = try SeedSelector<Int>(model: model, budget: 3, trials: 1, seed: 5).compute(on: g)
		#expect(selection.picks.count == 3)
		// One trial: every gain is a whole number of nodes.
		#expect(selection.picks.allSatisfy { $0.marginalGain.rounded() == $0.marginalGain && $0.marginalGain >= 0 })
		let seeds = selection.nodes.compactMap { g.indexOf[$0] }
		let spread = try SpreadEstimator(trials: 1, seed: 5).estimate(model: model, on: g, seeds: seeds)
		#expect(abs(selection.totalGain - spread.mean) < 1e-12)
		let sweep = try SeedSelector<Int>.sweep(on: g, probabilities: [0.1, 0.4], budget: 2, trials: 1, seed: 5)
		#expect(sweep.results.count == 2)
		#expect(sweep.results.allSatisfy { $0.selection.picks.count == 2 })
	}
}
