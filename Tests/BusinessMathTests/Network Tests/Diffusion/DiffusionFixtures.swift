//
//  DiffusionFixtures.swift
//  BusinessMath
//
//  Shared fixtures for the diffusion tests. Ported from SwiftGraphMetrics's DiffusionTests.
//  Synthetic graphs only; every random graph is seeded and built with SplitMix64.
//

import Foundation
import SwiftDeterminism
import TestSupport

@testable import BusinessMath

/// Graph builders and independent per-trial oracles shared by the diffusion suites.
enum DiffusionFixtures {


	/// Star with `leaves` leaves; centre is "c", leaves are "l00", "l01", ...
	static func star(leaves: Int) -> WeightedGraph<String> {
		var edges: [(String, String)] = []
		for index in 0..<leaves {
			let padding: String = index < 10 ? "0" : ""
			let leaf: String = "l" + padding + String(index)
			edges.append(("c", leaf))
		}
		return WeightedGraph(unweightedEdges: edges)
	}

	/// Path "p0" - "p1" - ... - "p(n-1)".
	static func path(_ n: Int) -> WeightedGraph<String> {
		WeightedGraph(unweightedEdges: (1..<n).map { ("p\($0 - 1)", "p\($0)") }, isolatedNodes: n == 1 ? ["p0"] : [])
	}

	/// Tolerance comparison; spreads here are exact integer ratios, so 1e-9 is generous.
	static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

	static func index(_ graph: WeightedGraph<String>, _ name: String) -> Int {
		graph.indexOf[name] ?? -1
	}

	/// Small seeded random graph on integer nodes, built with the portfolio's generator.
	static func randomGraph(nodes: Int, edgeProbability: Double, seed: UInt64) -> WeightedGraph<Int> {
		var rng = SplitMix64(seed: seed)
		var edges: [(Int, Int)] = []
		for a in 0..<nodes {
			for b in (a + 1)..<nodes where Double.random(in: 0..<1, using: &rng) < edgeProbability {
				edges.append((a, b))
			}
		}
		return WeightedGraph(unweightedEdges: edges, isolatedNodes: Array(0..<nodes))
	}

	static func kite() -> WeightedGraph<String> {
		WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
	}

	static func karate() -> WeightedGraph<Int> {
		WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
	}

	static func estimate(
		_ model: some DiffusionModel, _ graph: WeightedGraph<String>, seeds: [String],
		trials: Int, seed: UInt64 = 7
	) throws -> SpreadEstimate {
		try SpreadEstimator(trials: trials, seed: seed)
			.estimate(model: model, on: graph, seeds: seeds.map { index(graph, $0) })
	}

	// MARK: - Mutation-audit additions (test-quality pass, 2026-11-11)
	//
	// Written after a mutation audit showed which wrong implementations the tests above could
	// not tell apart from the right one. The strongest additions are *per-trial oracles*: a
	// trial's random draws are a pure function of (seed, trial, edge or node), so the outcome
	// of one trial can be recomputed by a different algorithm (reachability over the edges that
	// fired; a threshold fixed point) and compared exactly, with no statistical tolerance.

	/// A seeded random weighted graph on `0..<nodes`; every node is present, isolated ones too.
	static func randomWeightedGraph(
		nodes: Int, edgeProbability: Double, seed: UInt64, weighted: Bool
	) throws -> WeightedGraph<Int> {
		var rng = SplitMix64(seed: seed)
		var edges: [(Int, Int, Double)] = []
		for a in 0..<nodes {
			for b in (a + 1)..<max(a + 1, nodes) where Double.random(in: 0..<1, using: &rng) < edgeProbability {
				edges.append((a, b, weighted ? Double.random(in: 0.5...3, using: &rng) : 1))
			}
		}
		return try WeightedGraph(edges: edges, isolatedNodes: Array(0..<nodes))
	}

	/// How an oracle cascade fires an edge: with one fixed probability, or scaled by weight.
	enum CascadeRule: Sendable {
		case fixed(Double)
		case scaled(Double)
	}

	/// Independent cascade, one trial, as reachability over the directed edges that fired.
	static func cascadeOracle(
		_ graph: WeightedGraph<Int>, _ rule: CascadeRule, seeds: [Int],
		masterSeed: UInt64, trial: Int
	) -> Int {
		let randomness = TrialRandomness(masterSeed: masterSeed, trial: trial)
		let heaviest = graph.adjacency.flatMap { $0 }.map(\.weight).max() ?? 0
		func fires(_ from: Int, _ to: Int, _ weight: Double) -> Bool {
			let probability: Double
			switch rule {
			case .fixed(let p): probability = p
			case .scaled(let base): probability = min(1, base * weight / heaviest)
			}
			return randomness.uniform(from: from, to: to) < probability
		}
		var reached = Set(seeds.filter { (0..<graph.nodeCount).contains($0) })
		var stack = Array(reached)
		while let source = stack.popLast() {
			for edge in graph.adjacency[source]
			where !reached.contains(edge.neighbour) && fires(source, edge.neighbour, edge.weight) {
				reached.insert(edge.neighbour)
				stack.append(edge.neighbour)
			}
		}
		return reached.count
	}

	/// Linear threshold, one trial, as the least fixed point of "share of active weight >= threshold".
	static func thresholdOracle(
		_ graph: WeightedGraph<Int>, seeds: [Int], masterSeed: UInt64, trial: Int
	) -> Int {
		let randomness = TrialRandomness(masterSeed: masterSeed, trial: trial)
		var active = Set(seeds.filter { (0..<graph.nodeCount).contains($0) })
		var changed = true
		while changed {
			changed = false
			for node in 0..<graph.nodeCount where !active.contains(node) {
				let degree = graph.adjacency[node].reduce(0.0) { $0 + $1.weight }
				guard degree > 0 else { continue }
				let activeWeight = graph.adjacency[node]
					.filter { active.contains($0.neighbour) }.reduce(0.0) { $0 + $1.weight }
				if activeWeight >= randomness.uniform(forNode: node) * degree {
					active.insert(node)
					changed = true
				}
			}
		}
		return active.count
	}

	static let oracleSeeds: [UInt64] = Array(1...8)
}
