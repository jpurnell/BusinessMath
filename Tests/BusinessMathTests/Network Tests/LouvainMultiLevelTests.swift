//
//  LouvainMultiLevelTests.swift
//  BusinessMath
//
//  Louvain must contract communities between passes, as its documentation says.
//
//  ## The graph that separates single-level from multi-level
//
//  A ring of k triangles, each joined to the next by one edge. With e = 3 internal edges
//  per triangle, m = k(e + 1) = 4k, and (closed form, derived by hand):
//
//  - every triangle its own community: Q = e/(e+1) − 1/k = 3/4 − 1/k
//  - adjacent triangles paired (k even):  Q = (2e+1)/(2(e+1)) − 2/k = 7/8 − 2/k
//
//  The pairing is better exactly when k > 2(e+1) = 8. For k = 12 that is
//  0.6667 against 0.7083. Merging two whole triangles is a move no single node can make
//  (moving one node out of its triangle loses), so only contraction reaches it.
//

import Testing
import Foundation
import Numerics
import TestSupport
@testable import BusinessMath

@Suite("Louvain multi-level")
struct LouvainMultiLevelTests {

	// MARK: - Builders

	private static func undirected(_ pairs: [(String, String)]) -> Graph<String> {
		var edges: [(String, String)] = []
		for (from, to) in pairs { edges.append((from, to)); edges.append((to, from)) }
		return Graph(edges: edges)
	}

	private static func name(_ index: Int) -> String { "v" + padded(index) }

	private static func padded(_ value: Int) -> String {
		let text = String(value)
		return String(repeating: "0", count: Swift.max(0, 3 - text.count)) + text
	}

	/// Ring of `count` cliques of `size` nodes; the last node of one meets the first of the next.
	private static func ringOfCliques(count: Int, size: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for c in 0..<count {
			let base = c * size
			for i in 0..<size { for j in (i + 1)..<size where size > 1 {
				pairs.append((name(base + i), name(base + j)))
			} }
			let next = ((c + 1) % count) * size
			pairs.append((name(base + size - 1), name(next)))
		}
		return undirected(pairs)
	}

	// MARK: - Independent oracles

	/// Modularity of a labelling on a dense symmetric weight matrix whose diagonal holds
	/// twice the internal weight (so degree is the row sum).
	static func denseModularity(_ w: [[Double]], _ label: [Int]) -> Double {
		let n = w.count
		var twoM: Double = 0
		for i in 0..<n { for j in 0..<n { twoM += w[i][j] } }
		guard twoM > 0 else { return 0 }
		var inside: [Int: Double] = [:]
		var total: [Int: Double] = [:]
		for i in 0..<n {
			var k: Double = 0
			for j in 0..<n {
				k += w[i][j]
				if label[i] == label[j] { inside[label[i], default: 0] += w[i][j] }
			}
			total[label[i], default: 0] += k
		}
		var q: Double = 0
		for (c, tot) in total {
			let fraction: Double = tot / twoM
			q += (inside[c] ?? 0) / twoM - fraction * fraction
		}
		return q
	}

	static func denseAdjacency(_ graph: Graph<String>) -> [[Double]] {
		let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
		var m = [[Double]](repeating: [Double](repeating: 0, count: graph.nodes.count),
						   count: graph.nodes.count)
		for node in graph.nodes {
			for target in graph.neighbors(of: node) {
				if let i = index[node], let j = index[target], i != j { m[i][j] = 1; m[j][i] = 1 }
			}
		}
		return m
	}

	/// Phase one of Louvain on a weighted dense graph: local moving from singletons.
	private static func localMoving(_ w: [[Double]]) -> [Int] {
		let n = w.count
		var label = Array(0..<n)
		var degree = [Double](repeating: 0, count: n)
		var twoM: Double = 0
		for i in 0..<n { for j in 0..<n { degree[i] += w[i][j] }; twoM += degree[i] }
		var total = degree
		var moved = true
		var rounds = 0
		while moved && rounds < 100 {
			moved = false
			rounds += 1
			for i in 0..<n {
				let current = label[i]
				var links = [Int: Double]()
				for j in 0..<n where j != i && w[i][j] > 0 { links[label[j], default: 0] += w[i][j] }
				total[current] -= degree[i]
				var best = current
				var bestGain: Double = (links[current] ?? 0) - total[current] * degree[i] / twoM
				for (c, weight) in links.sorted(by: { $0.key < $1.key }) where c != current {
					let gain: Double = weight - total[c] * degree[i] / twoM
					if gain > bestGain { bestGain = gain; best = c }
				}
				total[best] += degree[i]
				if best != current { label[i] = best; moved = true }
			}
		}
		return label
	}

	/// Multi-level Louvain reference: local moving, contract, repeat until nothing merges.
	/// Returns a label per original node.
	static func referenceMultiLevel(_ original: [[Double]]) -> [Int] {
		var w = original
		var membership = Array(0..<original.count)
		// Every level that does not stop the loop strictly shrinks the graph, so n levels bound it.
		for _ in 0..<original.count {
			let label = localMoving(w)
			var relabel: [Int: Int] = [:]
			for l in label where relabel[l] == nil { relabel[l] = relabel.count }
			let groups = relabel.count
			if groups == w.count { break }
			var next = [[Double]](repeating: [Double](repeating: 0, count: groups), count: groups)
			for i in 0..<w.count { for j in 0..<w.count {
				next[relabel[label[i]] ?? 0][relabel[label[j]] ?? 0] += w[i][j]
			} }
			for i in 0..<membership.count { membership[i] = relabel[label[membership[i]]] ?? 0 }
			w = next
		}
		return membership
	}

	/// The same without contraction: what the shipped code did.
	static func referenceSingleLevel(_ original: [[Double]]) -> [Int] { localMoving(original) }

	/// Every set partition of n items as restricted-growth strings.
	static func allPartitions(_ n: Int) -> [[Int]] {
		var out: [[Int]] = []
		var current = [Int](repeating: 0, count: n)
		func extend(_ position: Int, _ maxUsed: Int) {
			if position == n { out.append(current); return }
			for value in 0...(maxUsed + 1) {
				current[position] = value
				extend(position + 1, Swift.max(maxUsed, value))
			}
		}
		if n > 0 { current[0] = 0; extend(1, 0) }
		return out
	}

	private static func labelling(_ communities: [Set<String>], _ graph: Graph<String>) -> [Int] {
		var label = [Int](repeating: -1, count: graph.nodes.count)
		for (c, community) in communities.enumerated() {
			for node in community { if let i = graph.nodes.firstIndex(of: node) { label[i] = c } }
		}
		return label
	}

	// MARK: - The red test: contraction

	@Test("Ring of 12 triangles reaches at least the paired partition (closed form 7/8 - 2/12)")
	func ringOfTriangles() throws {
		let graph = Self.ringOfCliques(count: 12, size: 3)
		let found = try #require(graph.louvainCommunities())
		let q = try #require(graph.modularity(of: found))
		let paired: Double = 7.0 / 8.0 - 2.0 / 12.0
		#expect(q >= paired - 1e-9, "Q = \(q), pairing adjacent triangles gives \(paired)")
		#expect(found.count < 12, "no triangles were merged: \(found.count) communities")
	}

	@Test("Ring of 16 K4 cliques beats one community per clique (closed form)")
	func ringOfK4() throws {
		// e = 6, k = 16 > 2(e+1) = 14: pairing wins. Clique Q = 6/7 - 1/16, pair Q = 13/14 - 2/16.
		let graph = Self.ringOfCliques(count: 16, size: 4)
		let found = try #require(graph.louvainCommunities())
		let q = try #require(graph.modularity(of: found))
		let paired: Double = 13.0 / 14.0 - 2.0 / 16.0
		#expect(q >= paired - 1e-9, "Q = \(q), pairing gives \(paired)")
	}

	@Test("The production result matches the multi-level reference on rings of cliques")
	func matchesReferenceOnRings() throws {
		for (count, size) in [(12, 3), (10, 3), (16, 4), (6, 4), (24, 3)] {
			let graph = Self.ringOfCliques(count: count, size: size)
			let dense = Self.denseAdjacency(graph)
			let reference = Self.denseModularity(dense, Self.referenceMultiLevel(dense))
			let found = try #require(graph.louvainCommunities())
			let q = Self.denseModularity(dense, Self.labelling(found, graph))
			#expect(q >= reference - 1e-9, "ring \(count)x\(size): Q = \(q), reference \(reference)")
		}
	}

	@Test("Modularity never exceeds the exhaustive optimum on graphs of 8 nodes or fewer")
	func boundedByOptimum() throws {
		let rng = SeededRNG(seed: 77)
		let partitions = Self.allPartitions(8)
		#expect(partitions.count == 4140)
		for trial in 0..<25 {
			var pairs: [(String, String)] = []
			for node in 1..<8 {
				pairs.append((Self.name(Int(rng.next() * Double(node))), Self.name(node)))
			}
			for _ in 0..<(2 + trial % 5) {
				let a = Int(rng.next() * 8), b = Int(rng.next() * 8)
				if a != b { pairs.append((Self.name(a), Self.name(b))) }
			}
			let graph = Self.undirected(pairs)
			let dense = Self.denseAdjacency(graph)
			var optimum: Double = -1
			for p in partitions { optimum = Swift.max(optimum, Self.denseModularity(dense, p)) }
			let found = try #require(graph.louvainCommunities())
			let q = Self.denseModularity(dense, Self.labelling(found, graph))
			#expect(q <= optimum + 1e-9, "trial \(trial): \(q) exceeds the optimum \(optimum)")
			#expect(q >= optimum - 0.1, "trial \(trial): \(q) is far below the optimum \(optimum)")
		}
	}

	// MARK: - Properties

	@Test("Properties on seeded random graphs: range, coverage, determinism")
	func properties() throws {
		let rng = SeededRNG(seed: 4242)
		for trial in 0..<40 {
			let size = 6 + Int(rng.next() * 30)
			var pairs: [(String, String)] = []
			for node in 1..<size {
				pairs.append((Self.name(Int(rng.next() * Double(node))), Self.name(node)))
			}
			for _ in 0..<(size / 2) {
				let a = Int(rng.next() * Double(size)), b = Int(rng.next() * Double(size))
				if a != b { pairs.append((Self.name(a), Self.name(b))) }
			}
			let graph = Self.undirected(pairs)
			let found = try #require(graph.louvainCommunities(), "trial \(trial)")
			let q = try #require(graph.modularity(of: found), "trial \(trial): not a partition")
			#expect(q >= -0.5 && q < 1, "trial \(trial): Q = \(q)")
			let placed = found.reduce(0) { $0 + $1.count }
			#expect(placed == graph.nodes.count, "trial \(trial)")
			#expect(found.reduce(into: Set<String>()) { $0.formUnion($1) } == Set(graph.nodes))
			#expect(found.allSatisfy { !$0.isEmpty })
			let again = try #require(graph.louvainCommunities())
			#expect(again == found, "trial \(trial): not deterministic")
		}
	}

	@Test("Planted structure: relabelling the nodes gives the same partition structure")
	func relabelling() throws {
		// Four 5-cliques in a ring, so the structure is unambiguous at every level.
		let graph = Self.ringOfCliques(count: 4, size: 5)
		let rename: (String) -> String = { "w" + Self.padded(99 - (Int($0.dropFirst()) ?? 0)) }
		var relabelled: [(String, String)] = []
		for node in graph.nodes { for t in graph.neighbors(of: node) {
			relabelled.append((rename(node), rename(t)))
		} }
		let other = Graph(edges: relabelled)
		let first = try #require(graph.louvainCommunities())
		let second = try #require(other.louvainCommunities())
		let mapped = Set(first.map { Set($0.map(rename)) })
		#expect(mapped == Set(second), "\(mapped) vs \(second)")
	}

	@Test("maxPasses: 1 is local moving alone, and more passes never lower modularity")
	func passesAreMonotone() throws {
		let graph = Self.ringOfCliques(count: 12, size: 3)
		let one = try #require(graph.louvainCommunities(maxPasses: 1))
		let qOne = try #require(graph.modularity(of: one))
		#expect(Swift.abs(qOne - (0.75 - 1.0 / 12.0)) < 1e-9, "one round gave \(qOne)")
		var last = qOne
		for passes in 2...5 {
			let found = try #require(graph.louvainCommunities(maxPasses: passes))
			let q = try #require(graph.modularity(of: found))
			#expect(q >= last - 1e-12, "\(passes) passes lowered Q from \(last) to \(q)")
			last = q
		}
	}

	@Test("Never below local moving alone, on seeded random graphs")
	func neverBelowSingleLevel() throws {
		let rng = SeededRNG(seed: 99)
		for trial in 0..<30 {
			let size = 12 + Int(rng.next() * 40)
			var pairs: [(String, String)] = []
			for node in 1..<size {
				pairs.append((Self.name(Int(rng.next() * Double(node))), Self.name(node)))
			}
			for _ in 0..<size {
				let a = Int(rng.next() * Double(size)), b = Int(rng.next() * Double(size))
				if a != b { pairs.append((Self.name(a), Self.name(b))) }
			}
			let graph = Self.undirected(pairs)
			let dense = Self.denseAdjacency(graph)
			let single = Self.denseModularity(dense, Self.referenceSingleLevel(dense))
			let found = try #require(graph.louvainCommunities())
			let q = Self.denseModularity(dense, Self.labelling(found, graph))
			#expect(q >= single - 1e-9, "trial \(trial): \(q) below local moving alone, \(single)")
		}
	}

	@Test("A self-loop is kept consistent through contraction")
	func selfLoop() throws {
		var pairs: [(String, String)] = [("a", "a")]
		for c in 0..<6 {
			let base = c * 3
			pairs += [(Self.name(base), Self.name(base + 1)), (Self.name(base + 1), Self.name(base + 2)),
					  (Self.name(base), Self.name(base + 2)), (Self.name(base + 2), Self.name(((c + 1) % 6) * 3))]
		}
		var edges: [(String, String)] = []
		for (f, t) in pairs { edges.append((f, t)); edges.append((t, f)) }
		let graph = Graph(edges: edges)
		let found = try #require(graph.louvainCommunities())
		let q = try #require(graph.modularity(of: found), "result is not a partition")
		#expect(q >= -0.5 && q < 1)
		#expect(found.reduce(0) { $0 + $1.count } == graph.nodes.count)
	}
}
