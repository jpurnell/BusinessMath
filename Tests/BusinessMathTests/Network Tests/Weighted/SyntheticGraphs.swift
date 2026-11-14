//
//  SyntheticGraphs.swift
//  BusinessMath
//

import SwiftDeterminism

import TestSupport
@testable import BusinessMath

/// Synthetic graph families for exercising the iteration behaviour of eigenvector centrality.
///
/// Every generator is deterministic for a given seed and uses only SwiftDeterminism's
/// `SplitMix64`. Nothing here reads, resembles or is derived from real data.
enum Synthetic {

	typealias Edge = (String, String, Double)

	static func name(_ index: Int) -> String { "n" + String(100_000 + index) }

	static func graph(_ edges: [Edge], count: Int) throws -> WeightedGraph<String> {
		try WeightedGraph(edges: edges, isolatedNodes: (0..<count).map(name))
	}

	static func path(_ count: Int) throws -> WeightedGraph<String> {
		try graph((1..<count).map { (name($0 - 1), name($0), 1.0) }, count: count)
	}

	static func ring(_ count: Int) throws -> WeightedGraph<String> {
		try graph((0..<count).map { (name($0), name(($0 + 1) % count), 1.0) }, count: count)
	}

	static func star(_ count: Int) throws -> WeightedGraph<String> {
		try graph((1..<count).map { (name(0), name($0), 1.0) }, count: count)
	}

	/// A `rows` by `columns` lattice.
	static func grid(rows: Int, columns: Int) throws -> WeightedGraph<String> {
		var edges: [Edge] = []
		for r in 0..<rows {
			for c in 0..<columns {
				let here = r * columns + c
				if c + 1 < columns { edges.append((name(here), name(here + 1), 1.0)) }
				if r + 1 < rows { edges.append((name(here), name(here + columns), 1.0)) }
			}
		}
		return try graph(edges, count: rows * columns)
	}

	private static func weight(_ rng: inout SplitMix64) -> Double {
		Double(Int.random(in: 1...4, using: &rng))
	}

	/// The graph induced on its largest connected component, reading ties of positive weight, the
	/// connectivity eigenvector centrality requires (ADR-009). Ties between equally large components
	/// go to the one holding the lowest node. Used where a test is about the iteration, not about
	/// what happens on a graph the measure now refuses.
	static func connectedPart(_ graph: WeightedGraph<String>) throws -> WeightedGraph<String> {
		var component = [Int](repeating: -1, count: graph.nodeCount)
		var sizes: [Int] = []
		for start in 0..<graph.nodeCount where component[start] < 0 {
			let id = sizes.count
			component[start] = id
			var queue = [start]
			var head = 0
			while head < queue.count {
				let node = queue[head]
				head += 1
				for (neighbour, weight) in graph.adjacency[node] where weight > 0 && component[neighbour] < 0 {
					component[neighbour] = id
					queue.append(neighbour)
				}
			}
			sizes.append(queue.count)
		}
		guard let largest = sizes.enumerated().max(by: { $0.element < $1.element || ($0.element == $1.element && $0.offset > $1.offset) })?.offset else {
			return graph
		}
		var edges: [Edge] = []
		for (node, ties) in graph.adjacency.enumerated() where component[node] == largest {
			for (other, weight) in ties where other > node && weight > 0 {
				edges.append((graph.nodes[node], graph.nodes[other], weight))
			}
		}
		let nodes = graph.nodes.indices.filter { component[$0] == largest }.map { graph.nodes[$0] }
		return try WeightedGraph(edges: edges, isolatedNodes: nodes)
	}

	/// `edgeCount` random pairs among `count` nodes, weights 1 to 4 (duplicates merge by sum).
	static func erdosRenyi(seed: UInt64, count: Int, edgeCount: Int) throws -> WeightedGraph<String> {
		var rng = SplitMix64(seed: seed)
		var edges: [Edge] = []
		for _ in 0..<edgeCount {
			let a = Int.random(in: 0..<count, using: &rng)
			let b = Int.random(in: 0..<count, using: &rng)
			edges.append((name(a), name(b), weight(&rng)))
		}
		return try graph(edges, count: count)
	}

	/// Barabasi-Albert style growth: each new node attaches to `perNode` existing nodes chosen
	/// in proportion to their degree.
	static func preferentialAttachment(seed: UInt64, count: Int, perNode: Int) throws -> WeightedGraph<String> {
		var rng = SplitMix64(seed: seed)
		var edges: [Edge] = []
		var endpoints: [Int] = []
		let seedSize = perNode + 1
		for a in 0..<seedSize {
			for b in (a + 1)..<seedSize {
				edges.append((name(a), name(b), weight(&rng)))
				endpoints += [a, b]
			}
		}
		for node in seedSize..<count {
			var chosen = Set<Int>()
			while chosen.count < perNode {
				chosen.insert(endpoints[Int.random(in: 0..<endpoints.count, using: &rng)])
			}
			for target in chosen.sorted() {
				edges.append((name(node), name(target), weight(&rng)))
				endpoints += [node, target]
			}
		}
		return try graph(edges, count: count)
	}

	/// `groups` equal clusters. `inside` random edges per cluster, `between` random edges
	/// across all cluster pairs in total. Few `between` edges give a small spectral gap.
	static func communities(
		seed: UInt64, count: Int, groups: Int, inside: Int, between: Int
	) throws -> WeightedGraph<String> {
		var rng = SplitMix64(seed: seed)
		let size = count / groups
		var edges: [Edge] = []
		for g in 0..<groups {
			for _ in 0..<inside {
				let a = g * size + Int.random(in: 0..<size, using: &rng)
				let b = g * size + Int.random(in: 0..<size, using: &rng)
				edges.append((name(a), name(b), weight(&rng)))
			}
		}
		for _ in 0..<between {
			let a = Int.random(in: 0..<(size * groups), using: &rng)
			let b = Int.random(in: 0..<(size * groups), using: &rng)
			edges.append((name(a), name(b), weight(&rng)))
		}
		return try graph(edges, count: count)
	}
}
