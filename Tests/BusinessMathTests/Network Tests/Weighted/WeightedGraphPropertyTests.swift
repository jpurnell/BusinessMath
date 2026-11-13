//
//  WeightedGraphPropertyTests.swift
//  BusinessMath
//
//  Seeded property tests for WeightedGraph construction. Every generator is a SplitMix64
//  stream from a fixed seed, so a failure reproduces.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

@Suite("WeightedGraph: properties over seeded random graphs")
struct WeightedGraphPropertyTests {

	/// Weights drawn from multiples of 0.25 so that sums are exact in binary floating point
	/// and order of summation cannot change the answer.
	private func randomEdges(_ rng: inout DeterministicGenerator, nodes: Int, count: Int) -> [(Int, Int, Double)] {
		var edges: [(Int, Int, Double)] = []
		for _ in 0..<count {
			let from = rng.nextInt(in: 0..<nodes)
			let to = rng.nextInt(in: 0..<nodes)
			let quarters = rng.nextInt(in: 0..<17)
			edges.append((from, to, Double(quarters) * 0.25))
		}
		return edges
	}

	private func shuffled<T>(_ items: [T], _ rng: inout DeterministicGenerator) -> [T] {
		var result = items
		var index = result.count - 1
		while index > 0 {
			let other = rng.nextInt(in: 0..<(index + 1))
			result.swapAt(index, other)
			index -= 1
		}
		return result
	}

	@Test("Relabelling the nodes by a bijection preserves the multiset of weighted degrees")
	func relabellingInvariance() throws {
		var rng = DeterministicGenerator(seed: 2001)
		for trial in 0..<50 {
			let edges = randomEdges(&rng, nodes: 9, count: 20)
			let permutation = shuffled(Array(0..<9), &rng)
			let relabelled = edges.map { (permutation[$0.0], permutation[$0.1], $0.2) }
			let original = try WeightedGraph(edges: edges, isolatedNodes: Array(0..<9))
			let other = try WeightedGraph(edges: relabelled, isolatedNodes: Array(0..<9))
			let degrees = original.nodes.compactMap { original.degree(of: $0) }.sorted()
			let otherDegrees = other.nodes.compactMap { other.degree(of: $0) }.sorted()
			#expect(degrees == otherDegrees, "trial \(trial)")
			#expect(original.edgeCount == other.edgeCount, "trial \(trial)")
			#expect(original.totalWeight.isEqual(to: other.totalWeight), "trial \(trial)")
			for node in 0..<9 {
				#expect(original.degree(of: node)?.isEqual(to: other.degree(of: permutation[node]) ?? .nan) == true, "trial \(trial) node \(node)")
			}
		}
	}

	@Test("The sum of weighted degrees is twice the total weight")
	func handshake() throws {
		var rng = DeterministicGenerator(seed: 2002)
		for trial in 0..<50 {
			let graph = try WeightedGraph(edges: randomEdges(&rng, nodes: 10, count: 25))
			var sum = 0.0
			for index in graph.adjacency.indices { sum += graph.weightedDegree(index) }
			let twice = 2 * graph.totalWeight
			#expect(sum.isEqual(to: twice), "trial \(trial)")
		}
	}

	@Test("Edge order does not change the graph")
	func edgeOrderIndependence() throws {
		var rng = DeterministicGenerator(seed: 2003)
		for trial in 0..<50 {
			let edges = randomEdges(&rng, nodes: 8, count: 18)
			let reordered = shuffled(edges, &rng)
			let flipped = reordered.map { ($0.1, $0.0, $0.2) }
			let first = try WeightedGraph(edges: edges)
			let second = try WeightedGraph(edges: flipped)
			#expect(first.nodes == second.nodes, "trial \(trial)")
			#expect(first.edgeCount == second.edgeCount, "trial \(trial)")
			#expect(first.totalWeight.isEqual(to: second.totalWeight), "trial \(trial)")
			#expect(first.adjacency.count == second.adjacency.count, "trial \(trial)")
			for index in first.adjacency.indices {
				#expect(first.adjacency[index].map(\.neighbour) == second.adjacency[index].map(\.neighbour), "trial \(trial)")
				#expect(first.adjacency[index].map(\.weight) == second.adjacency[index].map(\.weight), "trial \(trial)")
			}
		}
	}

	@Test("Repeating every edge doubles every weight and leaves the structure alone")
	func duplicateEdgesSum() throws {
		var rng = DeterministicGenerator(seed: 2004)
		for trial in 0..<50 {
			let edges = randomEdges(&rng, nodes: 8, count: 15)
			let single = try WeightedGraph(edges: edges)
			let doubled = try WeightedGraph(edges: edges + edges)
			#expect(single.nodes == doubled.nodes, "trial \(trial)")
			#expect(single.edgeCount == doubled.edgeCount, "trial \(trial)")
			let twiceTotal = 2 * single.totalWeight
			#expect(doubled.totalWeight.isEqual(to: twiceTotal), "trial \(trial)")
			for index in single.adjacency.indices {
				#expect(single.adjacency[index].map(\.neighbour) == doubled.adjacency[index].map(\.neighbour), "trial \(trial)")
				let twice = single.adjacency[index].map { 2 * $0.weight }
				#expect(doubled.adjacency[index].map(\.weight) == twice, "trial \(trial)")
			}
		}
	}

	@Test("Adjacency is symmetric: every tie is recorded at both ends with the same weight")
	func adjacencySymmetric() throws {
		var rng = DeterministicGenerator(seed: 2005)
		for trial in 0..<50 {
			let graph = try WeightedGraph(edges: randomEdges(&rng, nodes: 9, count: 22))
			for (index, list) in graph.adjacency.enumerated() {
				for entry in list {
					let back = graph.adjacency[entry.neighbour].first { $0.neighbour == index }
					#expect(back?.weight.isEqual(to: entry.weight) == true, "trial \(trial)")
					#expect(entry.neighbour != index, "trial \(trial): self-loop survived")
				}
			}
		}
	}

	@Test("The bridge on a random symmetric graph round-trips to the same adjacency")
	func bridgeRoundTrip() {
		var rng = DeterministicGenerator(seed: 2006)
		for trial in 0..<50 {
			var map: [Int: [Int]] = [:]
			for node in 0..<8 { map[node] = [] }
			for _ in 0..<14 {
				let from = rng.nextInt(in: 0..<8)
				let to = rng.nextInt(in: 0..<8)
				guard from != to else { continue }
				map[from, default: []].append(to)
				map[to, default: []].append(from)
			}
			let symmetric = Graph(adjacency: map.mapValues { Array(Set($0)) })
			let weighted = WeightedGraph(symmetric)
			let back = Graph(weighted)
			#expect(back.adjacency == symmetric.adjacency, "trial \(trial)")
			#expect(back.nodes == symmetric.nodes, "trial \(trial)")
			let edgeTotal = Double(weighted.edgeCount)
			#expect(weighted.totalWeight.isEqual(to: edgeTotal), "trial \(trial)")
		}
	}
}
