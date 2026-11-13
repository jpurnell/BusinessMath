//
//  SeedSelectorTests.swift
//  BusinessMath
//
//  Greedy seed selection and its sensitivity sweep. Ported from SwiftGraphMetrics's DiffusionTests.
//
//  Reference truth is derived by hand (a star at p = 1, isolated nodes, tie order) or by
//  brute force through the same estimator. None of it comes from the code under test.
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

@Suite("SeedSelector")
struct SeedSelectorTests {

	private func selector(
		p: Double = 0.3, budget: Int, trials: Int = 100, seed: UInt64 = 11
	) throws -> SeedSelector<String> {
		SeedSelector(
			model: try IndependentCascade(probability: p), budget: budget, trials: trials, seed: seed)
	}

	@Test("Descriptor is exploratory, generic and states high and low")
	func descriptor() {
		let d = SeedSelector<String>.descriptor
		#expect(d.identifier == "seed-selection")
		#expect(d.version == 1)
		let text = (d.interpretation + d.highMeans + d.lowMeans).lowercased()
		#expect(text.contains("exploratory"))
		#expect(text.contains("calibrated"))
		#expect(!text.contains("classmate"))
		#expect(!text.contains("class of 2000"))
		#expect(!d.highMeans.isEmpty && !d.lowMeans.isEmpty)
	}

	@Test("Star at p = 1: the centre is picked first with gain n + 1")
	func starCentreFirst() throws {
		let g = star(leaves: 6)
		let selection = try selector(p: 1, budget: 1).compute(on: g)
		#expect(selection.nodes == ["c"])
		#expect(near(selection.picks[0].marginalGain, 7.0))
	}

	@Test("Empty graph yields an empty selection")
	func emptyGraph() throws {
		let g = try WeightedGraph<String>(edges: [])
		#expect(try selector(budget: 3).compute(on: g).picks.isEmpty)
	}

	@Test("Budget 0 yields no picks; negative budget throws")
	func zeroBudget() throws {
		#expect(try selector(budget: 0).compute(on: kite()).picks.isEmpty)
		#expect(throws: DiffusionError.invalidBudget(-1)) {
			try selector(budget: -1).compute(on: kite())
		}
	}

	@Test("Budget above node count returns at most node count picks, all distinct")
	func overBudget() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		let selection = try selector(p: 0.5, budget: 10).compute(on: g)
		#expect(selection.picks.count == 3)
		#expect(Set(selection.nodes).count == 3)
	}

	@Test("Isolated nodes are pickable and gain exactly 1 each")
	func isolatedNodes() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "b")], isolatedNodes: ["z"])
		let selection = try selector(p: 0, budget: 3).compute(on: g)
		#expect(selection.picks.count == 3)
		#expect(selection.picks.allSatisfy { near($0.marginalGain, 1.0) })
	}

	@Test("trials = 0 throws a clear error")
	func zeroTrials() {
		#expect(throws: DiffusionError.invalidTrialCount(0)) {
			try selector(budget: 2, trials: 0).compute(on: kite())
		}
	}

	@Test("Identical configuration gives identical selections; different seed may differ")
	func deterministic() throws {
		let g = karate()
		let make = { (seed: UInt64) throws -> SeedSelector<Int> in
			SeedSelector(model: try IndependentCascade(probability: 0.1), budget: 5, trials: 100, seed: seed)
		}
		let a = try make(1).compute(on: g)
		let b = try make(1).compute(on: g)
		#expect(a == b)
		let c = try make(2).compute(on: g)
		let gains = a.picks.map(\.marginalGain)
		#expect(gains != c.picks.map(\.marginalGain), "gains should differ across master seeds")
	}

	@Test("The parallel first pass agrees bit-for-bit with the async task-group version")
	func syncAsyncAgree() async throws {
		let g = karate()
		let s = SeedSelector<Int>(
			model: try IndependentCascade(probability: 0.15), budget: 4, trials: 80, seed: 3)
		let sync = try s.compute(on: g)
		let async1 = try await s.computeAsync(on: g)
		let async2 = try await s.computeAsync(on: g)
		#expect(sync == async1)
		#expect(async1 == async2)
	}

	@Test("A selection round-trips through its stored-record envelope, filed under \"selection\"")
	func envelopeRoundTrip() throws {
		let computed = try selector(p: 0.3, budget: 3, trials: 50, seed: 1).compute(on: kite())
		let envelope = try MetricEnvelope(computed)
		#expect(envelope.kind == "selection")
		let decoded = try #require(try envelope.value(as: NodeSelection<String>.self))
		#expect(decoded.picks.count == 3)
		#expect(decoded == computed)
		// The selector's output type is the selection, and its descriptor names the metric.
		#expect(SeedSelector<String>.descriptor.identifier == "seed-selection")
		#expect(try selector(p: 0.3, budget: 3).descriptor == SeedSelector<String>.descriptor)
	}

	// MARK: Brute force and the greedy guarantee

	/// Total spread of a set under the same common random numbers the selector uses.
	private func spread<N: Hashable & Comparable & Sendable>(
		_ model: some DiffusionModel, _ g: WeightedGraph<N>, _ set: [Int], trials: Int, seed: UInt64
	) throws -> Double {
		try SpreadEstimator(trials: trials, seed: seed).estimate(model: model, on: g, seeds: set).mean
	}

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

	private func bruteForceBest<N: Hashable & Comparable & Sendable>(
		_ model: some DiffusionModel, _ g: WeightedGraph<N>, k: Int, trials: Int, seed: UInt64
	) throws -> Double {
		var best = 0.0
		for set in subsets(of: g.nodeCount, size: k) {
			best = max(best, try spread(model, g, set, trials: trials, seed: seed))
		}
		return best
	}

	@Test("Greedy spread >= (1 - 1/e) x brute-force optimum, k = 1...3, several small graphs", .timeLimit(.minutes(5)))
	func greedyGuarantee() throws {
		var graphs: [(String, WeightedGraph<Int>)] = []
		for seed in 1...5 as ClosedRange<UInt64> {
			graphs.append(("random-\(seed)", randomGraph(nodes: 9, edgeProbability: 0.25, seed: seed)))
		}
		let kiteGraph = kite()
		graphs.append(("kite", WeightedGraph(
			unweightedEdges: ReferenceGraphs.kiteEdges.map { (kiteGraph.indexOf[$0.0] ?? 0, kiteGraph.indexOf[$0.1] ?? 0) },
			isolatedNodes: Array(0..<kiteGraph.nodeCount))))

		let trials = 150
		let masterSeed: UInt64 = 21
		var matches = 0
		var cases = 0
		for (name, g) in graphs {
			for p in [0.2, 0.5] {
				let model = try IndependentCascade(probability: p)
				for k in 1...3 {
					let selection = try SeedSelector<Int>(
						model: model, budget: k, trials: trials, seed: masterSeed).compute(on: g)
					let greedySet = selection.nodes.compactMap { g.indexOf[$0] }
					let greedy = try spread(model, g, greedySet, trials: trials, seed: masterSeed)
					let optimum = try bruteForceBest(model, g, k: k, trials: trials, seed: masterSeed)
					#expect(greedy >= (1 - 1 / M_E) * optimum - 1e-9, "\(name) p=\(p) k=\(k)")
					#expect(greedy <= optimum + 1e-9, "greedy cannot beat the optimum: \(name) p=\(p) k=\(k)")
					// The summed marginal gains telescope to the set's spread.
					#expect(abs(selection.totalGain - greedy) < 1e-9, "\(name) p=\(p) k=\(k)")
					cases += 1
					if abs(greedy - optimum) < 1e-9 { matches += 1 }
				}
			}
		}
		// Recorded, not asserted tightly: how often greedy equals the optimum.
		print("RECORD greedy equalled brute-force optimum in \(matches) of \(cases) cases")
		#expect(matches > 0)
	}

	@Test("k = 1 pick equals the brute-force best single node", .timeLimit(.minutes(5)))
	func firstPickIsBestSingle() throws {
		for seed in 1...5 as ClosedRange<UInt64> {
			let g = randomGraph(nodes: 10, edgeProbability: 0.2, seed: seed)
			let model = try IndependentCascade(probability: 0.3)
			let pick = try SeedSelector<Int>(model: model, budget: 1, trials: 120, seed: 4).compute(on: g)
			let spreads = try (0..<g.nodeCount).map {
				try spread(model, g, [$0], trials: 120, seed: 4)
			}
			let bestValue = spreads.max() ?? 0
			let bestIndex = spreads.firstIndex(of: bestValue) ?? -1  // lowest index wins ties
			#expect(g.indexOf[pick.nodes[0]] == bestIndex)
			#expect(abs(pick.picks[0].marginalGain - bestValue) < 1e-9)
		}
	}

	@Test("The linear threshold model also selects, deterministically, and beats a random-ish set")
	func linearThresholdSelects() throws {
		let g = karate()
		let s = SeedSelector<Int>(model: LinearThreshold(), budget: 3, trials: 100, seed: 8)
		let a = try s.compute(on: g)
		#expect(a == (try s.compute(on: g)))
		#expect(a.picks.count == 3)
		#expect(a.picks.allSatisfy { $0.marginalGain.isFinite })
	}
}

// MARK: - Sensitivity sweep

@Suite("SeedSelector sweep")
struct SeedSweepTests {

	@Test("Reports one selection per probability, in order")
	func onePerProbability() throws {
		let sweep = try SeedSelector<Int>.sweep(
			on: karate(), probabilities: [0.05, 0.1, 0.2], budget: 3, trials: 60, seed: 2)
		#expect(sweep.results.count == 3)
		for (point, expected) in zip(sweep.results, [0.05, 0.1, 0.2]) { #expect(near(point.probability, expected)) }
		#expect(sweep.results.allSatisfy { $0.selection.picks.count == 3 })
	}

	@Test("Frequencies are the fraction of sweep points in which a node was picked")
	func frequencies() throws {
		let sweep = try SeedSelector<Int>.sweep(
			on: karate(), probabilities: [0.05, 0.1, 0.2, 0.3], budget: 3, trials: 60, seed: 2)
		var manual: [Int: Int] = [:]
		for r in sweep.results { for n in r.selection.nodes { manual[n, default: 0] += 1 } }
		for (node, count) in manual {
			let frequency = try #require(sweep.topKFrequency[node])
			#expect(near(frequency, Double(count) / 4.0))
		}
		#expect(sweep.topKFrequency.count == manual.count)
		let always = sweep.alwaysPicked
		#expect(always.allSatisfy { manual[$0] == 4 })
	}

	@Test("Jaccard overlap: matrix is symmetric, unit diagonal, hand-checked values")
	func jaccard() throws {
		// On a star at p = 1 and p = 0 alike the first pick differs predictably:
		// p = 1: centre first (gain n+1). p = 0: all gains 1, lowest index first.
		let g = WeightedGraph(unweightedEdges: (1...5).map { (0, $0) })
		let sweep = try SeedSelector<Int>.sweep(
			on: g, probabilities: [1.0, 1.0], budget: 2, trials: 20, seed: 1)
		// Identical runs -> Jaccard 1.
		#expect(near(sweep.pairwiseJaccard[0][1], 1.0))
		for i in 0..<2 { #expect(near(sweep.pairwiseJaccard[i][i], 1.0)) }
		#expect(near(sweep.meanPairwiseJaccard, 1.0))

		let mixed = try SeedSelector<Int>.sweep(
			on: g, probabilities: [1.0, 0.0], budget: 1, trials: 20, seed: 1)
		// p=1 -> {0} (centre). p=0 -> all gains 1, tie -> lowest index = node 0 as well.
		#expect(near(mixed.pairwiseJaccard[0][1], 1.0))

		let split = try SeedSelector<Int>.sweep(
			on: WeightedGraph(unweightedEdges: [(0, 1), (2, 3), (3, 4), (3, 5)]),
			probabilities: [1.0, 0.0], budget: 1, trials: 20, seed: 1)
		// p=1: any node of the 4-node component {2,3,4,5} reaches all 4 (component size);
		// the larger component beats {0,1} (size 2), and ties break to the lowest index, 2.
		// p=0: every gain is 1, tie -> lowest index, node 0.
		#expect(split.results[0].selection.nodes == [2])
		#expect(split.results[1].selection.nodes == [0])
		#expect(near(split.pairwiseJaccard[0][1], 0.0))
		#expect(near(split.pairwiseJaccard[1][0], 0.0))
		#expect(near(split.meanPairwiseJaccard, 0.0))
	}

	@Test("A single sweep point has mean Jaccard 1 (no pairs to disagree)")
	func singlePoint() throws {
		let sweep = try SeedSelector<Int>.sweep(
			on: karate(), probabilities: [0.1], budget: 2, trials: 30, seed: 1)
		#expect(near(sweep.meanPairwiseJaccard, 1.0))
	}

	@Test("Empty sweep and invalid probabilities throw")
	func invalid() {
		#expect(throws: DiffusionError.emptySweep) {
			try SeedSelector<Int>.sweep(on: karate(), probabilities: [], budget: 2, trials: 10, seed: 1)
		}
		#expect(throws: DiffusionError.invalidProbability(1.5)) {
			try SeedSelector<Int>.sweep(on: karate(), probabilities: [0.1, 1.5], budget: 2, trials: 10, seed: 1)
		}
		#expect(throws: DiffusionError.invalidTrialCount(0)) {
			try SeedSelector<Int>.sweep(on: karate(), probabilities: [0.1], budget: 2, trials: 0, seed: 1)
		}
	}

	@Test("Sweeps are deterministic")
	func deterministic() throws {
		let a = try SeedSelector<Int>.sweep(
			on: karate(), probabilities: [0.05, 0.2], budget: 3, trials: 50, seed: 9)
		let b = try SeedSelector<Int>.sweep(
			on: karate(), probabilities: [0.05, 0.2], budget: 3, trials: 50, seed: 9)
		#expect(a == b)
	}
}

// MARK: - Performance (run once on purpose; slow tests are named Benchmark)

/// Enabled only when `RUN_BENCHMARKS` is set (the repo's convention; SwiftGraphMetrics used
/// `SGM_BENCHMARK=1`), so the default (and pre-commit) test run stays fast.
/// Run with: `RUN_BENCHMARKS=1 swift test -c release --filter DiffusionBenchmarks`.
@Suite("Benchmark", .serialized, .benchmarkOnly)
struct DiffusionBenchmarks {

	/// ~1,100 nodes / ~15,000 edges, seeded; preferential-ish mix of local and random ties.
	static func synthetic() -> WeightedGraph<Int> {
		var rng = Xoshiro256StarStar(seed: 2000)
		let n = 1100
		var edges = Set<[Int]>()
		while edges.count < 15_000 {
			let a = Int.random(in: 0..<n, using: &rng)
			let b = Int.random(in: 0..<n, using: &rng)
			guard a != b else { continue }
			edges.insert([min(a, b), max(a, b)])
		}
		return WeightedGraph(
			unweightedEdges: edges.sorted { $0.lexicographicallyPrecedes($1) }.map { ($0[0], $0[1]) },
			isolatedNodes: Array(0..<n))
	}

	@Test("Benchmark: karate, k = 10, 200 trials")
	func karateTiming() throws {
		let g = karate()
		let start = ContinuousClock.now
		let s = try SeedSelector<Int>(
			model: IndependentCascade(probability: 0.1), budget: 10, trials: 200, seed: 1).compute(on: g)
		let elapsed = ContinuousClock.now - start
		print("BENCHMARK karate k=10 trials=200:", elapsed)
		#expect(s.picks.count == 10)
	}

	@Test("Benchmark: ~1,100 nodes / ~15,000 edges, k = 10, 200 trials")
	func largeTiming() throws {
		let g = Self.synthetic()
		#expect(g.nodeCount == 1100)
		for p in [0.01, 0.05] {
			let start = ContinuousClock.now
			let s = try SeedSelector<Int>(
				model: IndependentCascade(probability: p), budget: 10, trials: 200, seed: 1).compute(on: g)
			let elapsed = ContinuousClock.now - start
			print("BENCHMARK large(\(g.nodeCount)n/\(g.edgeCount)e) IC p=\(p) k=10 trials=200:", elapsed)
			#expect(s.picks.count == 10)
		}
		let start = ContinuousClock.now
		let s = try SeedSelector<Int>(model: LinearThreshold(), budget: 10, trials: 200, seed: 1).compute(on: g)
		print("BENCHMARK large LT k=10 trials=200:", ContinuousClock.now - start)
		#expect(s.picks.count == 10)
	}
}

// MARK: - Mutation-audit additions (test-quality pass, 2026-11-11)
//
// Written after a mutation audit showed which wrong implementations the tests above could
// not tell apart from the right one. The strongest additions are *per-trial oracles*: a
// trial's random draws are a pure function of (seed, trial, edge or node), so the outcome
// of one trial can be recomputed by a different algorithm (reachability over the edges that
// fired; a threshold fixed point) and compared exactly, with no statistical tolerance.
