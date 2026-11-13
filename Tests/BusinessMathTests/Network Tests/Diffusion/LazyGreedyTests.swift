//
//  LazyGreedyTests.swift
//  BusinessMath
//
//  Lazy (CELF) greedy against plain greedy: exact pick and gain equality. Ported from
//  SwiftGraphMetrics's LazyGreedyTests.
//
//  Lazy evaluation is sound only if a node's marginal gain can never grow as seeds are added.
//  That holds per trial for independent cascade (a trial is a fixed set of live edges, and
//  reachability is submodular) and does NOT hold per trial for linear threshold (thresholds
//  are fixed per trial, and two half-weight neighbours can jointly activate a node that
//  neither does alone). These tests pin both halves of that argument and then check the
//  consequence on seeded graphs.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

/// Plain greedy, written independently of the engine: every round, every unchosen node is
/// scored on the same trials, and the best wins, the lowest index breaking ties.
private func plainGreedy(
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

private func randomGraph(nodes: Int, density: Double, seed: UInt64) throws -> WeightedGraph<Int> {
	var rng = SplitMix64(seed: seed)
	var edges: [(Int, Int, Double)] = []
	for a in 0..<nodes {
		for b in (a + 1)..<max(a + 1, nodes) where Double.random(in: 0..<1, using: &rng) < density {
			edges.append((a, b, Double.random(in: 0.25...4, using: &rng)))
		}
	}
	return try WeightedGraph(edges: edges, isolatedNodes: Array(0..<nodes))
}

@Suite("Lazy greedy: the soundness argument")
struct LazyGreedyArgumentTests {

	/// Spread of a seed set in one trial.
	private func spread(_ model: some DiffusionModel, _ graph: DiffusionGraph, _ seeds: [Int], trial: Int, seed: UInt64) -> Int {
		model.simulate(on: graph, seeds: seeds, randomness: TrialRandomness(masterSeed: seed, trial: trial))
	}

	@Test("Independent cascade is submodular in every single trial: gains never grow with the seed set",
		  arguments: Array(0..<25 as Range<UInt64>))
	func cascadeTrialsAreSubmodular(seed: UInt64) throws {
		let graph = DiffusionGraph(try randomGraph(nodes: 7, density: 0.3, seed: seed))
		let model = try IndependentCascade(weightScaledProbability: 0.6)
		var rng = SplitMix64(seed: seed &+ 1000)
		for trial in 0..<6 {
			for _ in 0..<12 {
				let big = (0..<graph.nodeCount).filter { _ in Bool.random(using: &rng) }
				let small = big.filter { _ in Bool.random(using: &rng) }
				guard let extra = (0..<graph.nodeCount).first(where: { !big.contains($0) }) else { continue }
				let gainSmall = spread(model, graph, small + [extra], trial: trial, seed: seed)
					- spread(model, graph, small, trial: trial, seed: seed)
				let gainBig = spread(model, graph, big + [extra], trial: trial, seed: seed)
					- spread(model, graph, big, trial: trial, seed: seed)
				#expect(gainBig <= gainSmall, "S=\(small) T=\(big) x=\(extra) trial \(trial)")
			}
		}
	}

	@Test("Linear threshold is NOT submodular in a single trial: two half-weight neighbours can jointly activate a node neither does alone")
	func thresholdTrialIsNotSubmodular() throws {
		// a - v - b with equal weights: each seed alone gives v a share of 1/2.
		let graph = DiffusionGraph(try WeightedGraph(edges: [("a", "v", 1.0), ("b", "v", 1.0)]))
		let model = LinearThreshold()
		// Nodes sorted: a = 0, b = 1, v = 2. Find a trial whose threshold for v lies in (1/2, 1].
		var witnessed = 0
		for trial in 0..<200 {
			let randomness = TrialRandomness(masterSeed: 1, trial: trial)
			guard randomness.uniform(forNode: 2) > 0.5 + 1e-9 else { continue }
			let alone = model.simulate(on: graph, seeds: [1], randomness: randomness)      // b only
			let afterA = model.simulate(on: graph, seeds: [0, 1], randomness: randomness)  // a and b
			let aOnly = model.simulate(on: graph, seeds: [0], randomness: randomness)
			// b adds 1 node on its own, but 2 (itself and v) once a is already seeded.
			#expect(alone == 1 && aOnly == 1 && afterA == 3)
			#expect(afterA - aOnly > alone - 0, "gain of b grew from \(alone) to \(afterA - aOnly)")
			witnessed += 1
		}
		#expect(witnessed > 0)
	}
}

@Suite("Lazy greedy: exact agreement with plain greedy")
struct LazyGreedyAgreementTests {

	/// Every way the selection differs from the reference; empty means identical. Picks and
	/// gains must match exactly, not closely: both are integer totals over the same trials.
	private func differences(
		_ selection: NodeSelection<Int>, _ reference: [(node: Int, gain: Double)], _ label: String
	) -> [String] {
		var found: [String] = []
		if selection.picks.count != reference.count { found.append("\(label): pick count") }
		for (position, pair) in zip(selection.picks, reference).enumerated() {
			if pair.0.node != pair.1.node { found.append("\(label): pick \(position) node \(pair.0.node) vs \(pair.1.node)") }
			if pair.0.marginalGain != pair.1.gain { found.append("\(label): pick \(position) gain \(pair.0.marginalGain) vs \(pair.1.gain)") }
		}
		return found
	}

	/// Batch 1 is the most lazy a selector can be (one stale candidate refreshed at a time), so
	/// it is where a lazy bound that is not a bound shows up first.
	@Test("Linear threshold: the selector equals plain greedy even with the laziest refresh batch, over many seeded graphs",
		  arguments: Array(0..<120 as Range<UInt64>))
	func thresholdMatchesPlainGreedy(seed: UInt64) throws {
		let graph = try randomGraph(nodes: 10 + Int(seed % 14), density: 0.12 + Double(seed % 5) * 0.05, seed: seed)
		let trials = 4 + Int(seed % 9)
		let selector = SeedSelector<Int>(
			model: LinearThreshold(), budget: 4, trials: trials, seed: seed, lazyRefreshBatch: 1)
		let found = differences(
			try selector.compute(on: graph),
			plainGreedy(model: LinearThreshold(), graph: graph, budget: 4, trials: trials, seed: seed),
			"LT seed \(seed)")
		#expect(found.isEmpty, "\(found)")
	}

	@Test("Independent cascade: lazy evaluation is exact at every refresh batch size",
		  arguments: Array(0..<60 as Range<UInt64>))
	func cascadeMatchesPlainGreedy(seed: UInt64) throws {
		let graph = try randomGraph(nodes: 10 + Int(seed % 14), density: 0.12 + Double(seed % 5) * 0.05, seed: seed)
		let model = try IndependentCascade(weightScaledProbability: 0.5)
		let reference = plainGreedy(model: model, graph: graph, budget: 4, trials: 8, seed: seed)
		for batch in [1, 2, 3, 7] {
			let selector = SeedSelector<Int>(model: model, budget: 4, trials: 8, seed: seed, lazyRefreshBatch: batch)
			let found = differences(try selector.compute(on: graph), reference, "IC seed \(seed) batch \(batch)")
			#expect(found.isEmpty, "\(found)")
		}
	}

	@Test("At its default batch size the selector equals plain greedy on graphs bigger than the batch, for both models")
	func defaultBatchOnLargerGraphs() throws {
		for seed in 0..<6 as Range<UInt64> {
			let graph = try randomGraph(nodes: 70, density: 0.06, seed: seed)
			for model: any DiffusionModel in [LinearThreshold(), try IndependentCascade(weightScaledProbability: 0.4)] {
				let selector = SeedSelector<Int>(model: model, budget: 5, trials: 6, seed: seed)
				let found = differences(
					try selector.compute(on: graph),
					plainGreedy(model: model, graph: graph, budget: 5, trials: 6, seed: seed),
					"\(type(of: model)) seed \(seed)")
				#expect(found.isEmpty, "\(found)")
			}
		}
	}
}

@Suite("DiffusionModel.hasSubmodularTrials")
struct SubmodularFlagTests {

	/// A model written by someone else, who has not declared anything.
	private struct Undeclared: DiffusionModel {
		func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
			Set(seeds.filter { $0 >= 0 && $0 < graph.nodeCount }).count
		}
	}

	@Test("Independent cascade declares it; linear threshold and an undeclared model do not")
	func declarations() throws {
		#expect(try IndependentCascade(probability: 0.5).hasSubmodularTrials)
		#expect(try IndependentCascade(weightScaledProbability: 0.5).hasSubmodularTrials)
		#expect(!LinearThreshold().hasSubmodularTrials)
		#expect(!Undeclared().hasSubmodularTrials)
	}

	@Test("An undeclared model gets exact plain greedy even when asked to be as lazy as possible")
	func undeclaredIsExact() throws {
		let graph = try randomGraph(nodes: 20, density: 0.2, seed: 2)
		let selection = try SeedSelector<Int>(
			model: Undeclared(), budget: 4, trials: 5, seed: 2, lazyRefreshBatch: 1).compute(on: graph)
		let reference = plainGreedy(model: Undeclared(), graph: graph, budget: 4, trials: 5, seed: 2)
		#expect(selection.nodes == reference.map(\.node))
	}
}

