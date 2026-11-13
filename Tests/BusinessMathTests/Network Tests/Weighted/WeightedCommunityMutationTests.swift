//
//  WeightedCommunityMutationTests.swift
//  BusinessMath
//  Written from the mutation audit of the Phase-0 metrics (see
//  project/summaries/2026-11-11_centrality_mutation/summary.md).
//
//  Expected values are derived by hand from the definition of modularity or
//  from a graph whose optimal partition is not in doubt, or come from a
//  reference that shares no code with the implementation.
//

import Foundation
import SwiftDeterminism
import Testing

import TestSupport
@testable import BusinessMath

// MARK: - Helpers

private func graph(
	_ edges: [(String, String)], isolated: [String] = []
) -> WeightedGraph<String> {
	WeightedGraph(unweightedEdges: edges, isolatedNodes: isolated)
}

private func close(_ actual: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
	guard let actual else { return false }
	return abs(actual - expected) <= tolerance
}

private func names(_ count: Int) -> [String] {
	(0..<count).map { "n" + String($0 + 100) }
}

private func clique(_ prefix: String, _ size: Int) -> [(String, String)] {
	var edges: [(String, String)] = []
	for i in 0..<size { for j in (i + 1)..<max(i + 1, size) { edges.append(("\(prefix)\(i)", "\(prefix)\(j)")) } }
	return edges
}

/// A partition's labels in node order, with -1 for a node it does not mention.
private func labels(_ p: NodePartition<String>, _ g: WeightedGraph<String>) -> [Int] {
	g.nodes.map { p[$0] ?? -1 }
}

private func partition(_ groups: [[String]]) -> NodePartition<String> {
	var map: [String: Int] = [:]
	for (index, group) in groups.enumerated() { for node in group { map[node] = index } }
	return NodePartition(map)
}

private func randomEdges(
	seed: UInt64, count: Int, edgeCount: Int
) -> [(String, String, Double)] {
	var rng = SplitMix64(seed: seed)
	let nodes = names(count)
	var edges: [(String, String, Double)] = []
	for _ in 0..<edgeCount {
		let a = Int.random(in: 0..<count, using: &rng)
		let b = Int.random(in: 0..<count, using: &rng)
		edges.append((nodes[a], nodes[b], Double(Int.random(in: 1...4, using: &rng))))
	}
	return edges
}

/// Modularity straight from its textbook definition,
/// Q = (1/2m) sum over ordered pairs (i, j) in the same community of
/// (A_ij - k_i k_j / 2m), taken over the nodes that have a community.
/// A dense double loop: nothing in common with `Community.modularity`.
private func modularityByDefinition(
	_ g: WeightedGraph<String>, _ p: NodePartition<String>
) -> Double {
	let n = g.nodeCount
	var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
	for i in 0..<n { for (j, w) in g.adjacency[i] { a[i][j] = w } }
	let k = a.map { $0.reduce(0, +) }
	let twoM = k.reduce(0, +)
	guard twoM > 0 else { return 0 }
	var q = 0.0
	for i in 0..<n {
		for j in 0..<n {
			guard let ci = p[g.nodes[i]], let cj = p[g.nodes[j]], ci == cj else { continue }
			q += a[i][j] - k[i] * k[j] / twoM
		}
	}
	return q / twoM
}


/// A second Louvain, written densely and from the definition. It keeps the
/// level graph as an n-by-n matrix A (A[i][i] counts a self-loop twice, so
/// row sums are degrees), scores every candidate move by recomputing the whole
/// generalised modularity
///     Q = (1/2m) sum_{i,j same community} (A_ij - gamma k_i k_j / 2m)
/// rather than by the incremental gain formula, and visits candidate
/// communities in ascending order, moving only for a strict improvement. It
/// shares no code with `Community.louvain`. Labels come out numbered in
/// first-appearance order over the nodes.
private func louvainReference(
	_ g: WeightedGraph<String>, resolution gamma: Double = 1, maxPasses: Int = 20
) -> [Int] {
	let n = g.nodeCount
	guard n > 0 else { return [] }
	guard g.totalWeight > 0 else { return Array(0..<n) }
	var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
	for i in 0..<n { for (j, w) in g.adjacency[i] { a[i][j] = w } }
	var assignment = Array(0..<n)

	func quality(_ a: [[Double]], _ community: [Int]) -> Double {
		let size = a.count
		let k = a.map { $0.reduce(0, +) }
		let twoM = k.reduce(0, +)
		var q = 0.0
		for i in 0..<size { for j in 0..<size where community[i] == community[j] {
			q += a[i][j] - gamma * k[i] * k[j] / twoM
		} }
		return q / twoM
	}

	for _ in 0..<max(1, maxPasses) {
		let size = a.count
		let m = a.map { $0.reduce(0, +) }.reduce(0, +) / 2
		guard m > 0 else { break }
		var community = Array(0..<size)
		var improved = false
		var moved = true
		var sweeps = 0
		while moved && sweeps < 50 {
			moved = false
			sweeps += 1
			for i in 0..<size {
				let own = community[i]
				let candidates = Set((0..<size).filter { $0 != i && a[i][$0] > 0 }.map { community[$0] })
					.subtracting([own]).sorted()
				var best = own
				var bestQ = quality(a, community)
				for candidate in candidates {
					var trial = community
					trial[i] = candidate
					let q = quality(a, trial)
					// The production threshold is 1e-12 on the gain, which is m times a change in Q.
					if q > bestQ + 1e-12 / m { best = candidate; bestQ = q }
				}
				if best != own { community[i] = best; moved = true; improved = true }
			}
		}
		guard improved else { break }
		var renumbered: [Int: Int] = [:]
		for value in community where renumbered[value] == nil { renumbered[value] = renumbered.count }
		let compact = community.map { renumbered[$0] ?? 0 }
		for index in 0..<n { assignment[index] = compact[assignment[index]] }
		let count = renumbered.count
		guard count < size else { break }
		var next = [[Double]](repeating: [Double](repeating: 0, count: count), count: count)
		for i in 0..<size { for j in 0..<size { next[compact[i]][compact[j]] += a[i][j] } }
		a = next
	}
	return assignment
}

// MARK: - Modularity

@Suite("Mutation audit: modularity")
struct ModularityMutationTests {

	/// Two triangles joined by one edge: m = 7. Each triangle holds 3 edges and
	/// degree 7, so Q = 2 (3/7 - (7/14)^2) = 2 (3/7 - 1/4) = 5/14.
	@Test("Two triangles and a bridge, split at the bridge")
	func twoTrianglesAndBridge() throws {
		let g = graph([("a", "b"), ("b", "c"), ("a", "c"), ("x", "y"), ("y", "z"), ("x", "z"), ("c", "x")])
		let q = Community.modularity(g, partition: partition([["a", "b", "c"], ["x", "y", "z"]]))
		#expect(close(q, 5.0 / 14.0))
		#expect(close(modularityByDefinition(g, partition([["a", "b", "c"], ["x", "y", "z"]])), 5.0 / 14.0))
	}

	/// The same graph with every node alone: Q = -sum (d / 2m)^2, with degrees
	/// 2, 2, 3, 3, 2, 2 over 2m = 14: -(4 + 4 + 9 + 9 + 4 + 4) / 196 = -34 / 196.
	@Test("Every node alone scores minus the sum of squared degree shares")
	func singletons() throws {
		let g = graph([("a", "b"), ("b", "c"), ("a", "c"), ("x", "y"), ("y", "z"), ("x", "z"), ("c", "x")])
		let q = Community.modularity(g, partition: partition(g.nodes.map { [$0] }))
		#expect(close(q, -34.0 / 196.0))
	}

	/// A single edge split in two: Q = 0 - 2 (1/2)^2 = -1/2, the lower bound.
	@Test("A split edge reaches the lower bound of minus one half")
	func lowerBound() throws {
		let q = Community.modularity(graph([("a", "b")]), partition: partition([["a"], ["b"]]))
		#expect(close(q, -0.5))
	}

	/// Path a-b-c with {a, b} and {c}: the second community has no internal
	/// edge but still pays for its degree. Q = (1/2 - (3/4)^2) + (0 - (1/4)^2) = -1/8.
	@Test("A community with no internal edge still pays for its degree")
	func communityWithoutInternalEdges() throws {
		let q = Community.modularity(graph([("a", "b"), ("b", "c")]), partition: partition([["a", "b"], ["c"]]))
		#expect(close(q, -0.125))
	}

	/// The reverse placement, to catch a bookkeeping error that is symmetric in one direction only.
	@Test("The same graph partitioned the other way")
	func otherPlacement() throws {
		let q = Community.modularity(graph([("a", "b"), ("b", "c")]), partition: partition([["a"], ["b", "c"]]))
		#expect(close(q, -0.125))
		// All three together is zero, by definition.
		#expect(close(Community.modularity(graph([("a", "b"), ("b", "c")]), partition: partition([["a", "b", "c"]])), 0))
	}

	/// Weights: a-b weight 3, b-c weight 1 gives m = 4 and degrees 3, 4, 1 over 2m = 8.
	/// {a,b} | {c}: (3/4 - (7/8)^2) + (0 - (1/8)^2) = 48/64 - 49/64 - 1/64 = -1/32.
	@Test("Weighted edges count by weight")
	func weighted() throws {
		let g = try WeightedGraph(edges: [("a", "b", 3.0), ("b", "c", 1.0)])
		let q = Community.modularity(g, partition: partition([["a", "b"], ["c"]]))
		let inside: Double = 3.0 / 4.0
		let squareAB: Double = 49.0 / 64.0
		let squareC: Double = 1.0 / 64.0
		let expectedQ: Double = (inside - squareAB) - squareC
		#expect(close(q, expectedQ))
		#expect(close(q, -1.0 / 32.0))
	}

	@Test("A node with no community assignment is left out of the sums")
	func partialPartition() throws {
		let g = graph([("a", "b"), ("b", "c")])
		// Only a and b are assigned, together. By the definition: -1/16.
		let q = Community.modularity(g, partition: NodePartition(["a": 0, "b": 0]))
		#expect(close(q, -0.0625))
		#expect(close(modularityByDefinition(g, NodePartition(["a": 0, "b": 0])), -0.0625))
	}

	/// The same shape at a total weight below one: a guard written for "no edges"
	/// must not mistake a light graph for an empty one. Modularity is scale-free,
	/// so path a-b-c with weights 0.25 and partition {a,b} | {c} is still -1/8.
	@Test("A graph of total weight below one still has a modularity")
	func lightGraph() throws {
		let g = try WeightedGraph(edges: [("a", "b", 0.25), ("b", "c", 0.25)])
		#expect(close(Community.modularity(g, partition: partition([["a", "b"], ["c"]])), -0.125))
		let tiny = try WeightedGraph(edges: [("a", "b", 0.001), ("b", "c", 0.001)])
		#expect(close(Community.modularity(tiny, partition: partition([["a", "b"], ["c"]])), -0.125))
	}

	/// Terms are added in community order so the total is the same bit pattern
	/// in every process: Swift seeds its dictionary hashing per launch, and a sum
	/// taken in dictionary order differs in the last bits from run to run.
	/// The reference below accumulates in ascending community order with the
	/// same expressions, so the comparison is exact. Many communities of unequal
	/// size, some with no internal edge, make an out-of-order sum differ
	/// in the last bit with near certainty.
	@Test("The sum runs over communities in ascending order, bit for bit")
	func summationOrder() throws {
		var mismatches = 0
		for seed in 0..<24 as Range<UInt64> {
			let count = 40
			let g = try WeightedGraph(edges: randomEdges(seed: 20_000 + seed, count: count, edgeCount: 70 + Int(seed)),
								  isolatedNodes: names(count))
			var rng = SplitMix64(seed: 21_000 + seed)
			let p = NodePartition(Dictionary(uniqueKeysWithValues: g.nodes.map { ($0, Int.random(in: 0..<16, using: &rng)) }))

			var inside: [Int: Double] = [:], degrees: [Int: Double] = [:]
			for (i, node) in g.nodes.enumerated() {
				let c = p[node] ?? -1
				degrees[c, default: 0] += g.adjacency[i].reduce(0) { $0 + $1.weight }
				for (j, w) in g.adjacency[i] where p[g.nodes[j]] == c { inside[c, default: 0] += w }
			}
			let total = g.totalWeight
			var expected = 0.0
			for c in inside.keys.sorted() {
				expected += ((inside[c] ?? 0) / 2) / total - pow((degrees[c] ?? 0) / (2 * total), 2)
			}
			for c in degrees.keys.sorted() where inside[c] == nil {
				expected -= pow((degrees[c] ?? 0) / (2 * total), 2)
			}
			let actual = Community.modularity(g, partition: p)
			#expect(close(actual, expected, tolerance: 1e-12))
			if actual != expected { mismatches += 1 }
		}
		#expect(mismatches == 0, "\(mismatches) of 24 sums differ from the ascending-order sum in the last bits")
	}

	@Test("A graph with no edges has modularity zero")
	func edgeless() throws {
		#expect(Community.modularity(graph([], isolated: ["a", "b"]), partition: partition([["a"], ["b"]])) == 0)
		#expect(Community.modularity(try WeightedGraph<String>(edges: []), partition: NodePartition([:])) == 0)
	}

	// MARK: Properties

	@Test("Agrees with the textbook definition on random graphs and partitions")
	func agreesWithDefinition() throws {
		for seed in 0..<20 as Range<UInt64> {
			let count = 6 + Int(seed % 5)
			let g = try WeightedGraph(edges: randomEdges(seed: 2_000 + seed, count: count, edgeCount: 8 + Int(seed)),
								  isolatedNodes: names(count))
			var rng = SplitMix64(seed: 3_000 + seed)
			let parts = 1 + Int(seed % 4)
			var map: [String: Int] = [:]
			for node in g.nodes where Int.random(in: 0..<8, using: &rng) != 0 {   // some unassigned
				map[node] = Int.random(in: 0..<parts, using: &rng)
			}
			let p = NodePartition(map)
			let q = Community.modularity(g, partition: p)
			#expect(close(q, modularityByDefinition(g, p), tolerance: 1e-9), "seed \(seed)")
		}
	}

	@Test("Modularity of a complete assignment lies within [-1/2, 1)")
	func bounds() throws {
		for seed in 0..<20 as Range<UInt64> {
			let g = try WeightedGraph(edges: randomEdges(seed: 4_000 + seed, count: 9, edgeCount: 12), isolatedNodes: names(9))
			var rng = SplitMix64(seed: 5_000 + seed)
			let p = NodePartition(Dictionary(uniqueKeysWithValues:
				g.nodes.map { ($0, Int.random(in: 0..<(1 + Int(seed % 5)), using: &rng)) }))
			let q = Community.modularity(g, partition: p)
			#expect(q >= -0.5 - 1e-12 && q < 1, "seed \(seed): \(q)")
		}
	}

	@Test("Invariant under community renumbering, weight scaling and node relabelling")
	func invariances() throws {
		for seed in 0..<8 as Range<UInt64> {
			let edges = randomEdges(seed: 6_000 + seed, count: 8, edgeCount: 14)
			let g = try WeightedGraph(edges: edges, isolatedNodes: names(8))
			var rng = SplitMix64(seed: 7_000 + seed)
			let map = Dictionary(uniqueKeysWithValues: g.nodes.map { ($0, Int.random(in: 0..<3, using: &rng)) })
			let base = Community.modularity(g, partition: NodePartition(map))

			let renumbered = Community.modularity(g, partition: NodePartition(map.mapValues { ($0 + 1) * 17 }))
			let scaled = Community.modularity(
				try WeightedGraph(edges: edges.map { ($0.0, $0.1, $0.2 * 6) }, isolatedNodes: names(8)),
				partition: NodePartition(map))
			let renamed = Community.modularity(
				try WeightedGraph(edges: edges.map { ("q" + $0.0, "q" + $0.1, $0.2) }, isolatedNodes: names(8).map { "q" + $0 }),
				partition: NodePartition(Dictionary(uniqueKeysWithValues: map.map { ("q" + $0.key, $0.value) })))
			#expect(close(renumbered, base, tolerance: 1e-12))
			#expect(close(scaled, base, tolerance: 1e-12))
			#expect(close(renamed, base, tolerance: 1e-12))
		}
	}
}

// MARK: - Louvain

@Suite("Mutation audit: Louvain")
struct LouvainMutationTests {

	private var twoCliques: WeightedGraph<String> {
		graph(clique("a", 4) + clique("b", 4) + [("a0", "b0")])
	}

	@Test("Two four-cliques joined by one edge split at the bridge")
	func twoCliquesAndBridge() throws {
		let p = Community.louvain(twoCliques)
		#expect(p.communityCount == 2)
		#expect(p["a0"] == p["a1"] && p["a1"] == p["a2"] && p["a2"] == p["a3"])
		#expect(p["b0"] == p["b1"] && p["b1"] == p["b2"] && p["b2"] == p["b3"])
		#expect(p["a0"] != p["b0"])
		// m = 13, each clique holds 6 edges and degree 13: Q = 2 (6/13 - 1/4).
		#expect(close(Community.modularity(twoCliques, partition: p), 2 * (6.0 / 13.0 - 0.25)))
	}

	@Test("Three cliques in a ring are three communities")
	func ringOfThreeCliques() throws {
		let g = graph(clique("a", 5) + clique("b", 5) + clique("c", 5)
					  + [("a0", "b0"), ("b1", "c0"), ("c1", "a1")])
		let p = Community.louvain(g)
		#expect(p.communityCount == 3)
		for prefix in ["a", "b", "c"] {
			#expect(Set((0..<5).compactMap { p["\(prefix)\($0)"] }).count == 1)
		}
	}

	/// Two triangles whose internal edges weigh 5, joined by c-x. With the link
	/// at weight 1 the triangles stay apart (Q = 2 (15/31 - 1/4) > 0). With the
	/// link at weight 40 the heavy edge dominates: {a,b} {c,x} {y,z} scores
	/// 0.163 against 0 for everything together, so c and x pair off and the
	/// rest are left behind. The weights, not just the topology, decide.
	@Test("A heavy link pairs its ends; a light link leaves the triangles whole")
	func weightsDecide() throws {
		func build(link: Double) throws -> WeightedGraph<String> {
			try WeightedGraph(edges: [("a", "b", 5), ("b", "c", 5), ("a", "c", 5),
								  ("x", "y", 5), ("y", "z", 5), ("x", "z", 5), ("c", "x", link)])
		}
		let light = Community.louvain(try build(link: 1))
		#expect(light.communityCount == 2)
		#expect(light["a"] == light["c"] && light["x"] == light["z"] && light["c"] != light["x"])
		let heavy = Community.louvain(try build(link: 40))
		#expect(heavy["c"] == heavy["x"])
		#expect(close(Community.modularity(try build(link: 40), partition: heavy),
					  modularityByDefinition(try build(link: 40), heavy)))
		#expect(Community.modularity(try build(link: 40), partition: heavy) > 0.16)
	}

	@Test("Without edges each node is its own community, numbered in node order")
	func edgeless() throws {
		let p = Community.louvain(graph([], isolated: ["c", "a", "b"]))
		#expect(p.communities == ["a": 0, "b": 1, "c": 2])
		#expect(Community.louvain(try WeightedGraph<String>(edges: [])).communities.isEmpty)
	}

	@Test("A lone node is a community of its own, numbered zero")
	func loneNode() throws {
		#expect(Community.louvain(graph([], isolated: ["x"])).communities == ["x": 0])
	}

	/// One aggregation pass leaves communities that a second pass merges.
	/// These seeds (random weighted graphs on 12-21 nodes) were chosen because
	/// the first pass alone stops short; more passes must give a strictly
	/// better modularity by the independent definition.
	@Test("A second pass merges what the first leaves, and scores strictly higher")
	func secondPassHelps() throws {
		for seed in [0, 1, 2, 3, 5, 6, 8, 9, 12] as [UInt64] {
			let count = 12 + Int(seed % 10)
			let g = try WeightedGraph(edges: randomEdges(seed: seed, count: count, edgeCount: count * 2))
			let one = Community.louvain(g, maxPasses: 1)
			let two = Community.louvain(g, maxPasses: 2)
			let many = Community.louvain(g)
			#expect(one != two, "seed \(seed)")
			#expect(two == many, "seed \(seed)")
			#expect(one.communityCount > many.communityCount, "seed \(seed)")
			#expect(modularityByDefinition(g, many) > modularityByDefinition(g, one) + 1e-9, "seed \(seed)")
			#expect(Community.louvain(g, maxPasses: 0) == one, "seed \(seed)")
		}
	}

	@Test("Uniform weight scaling by a power of two, up or down, gives the identical partition")
	func scalingDown() throws {
		for seed in 0..<6 as Range<UInt64> {
			let edges = randomEdges(seed: 14_000 + seed, count: 12, edgeCount: 24)
			let base = Community.louvain(try WeightedGraph(edges: edges, isolatedNodes: names(12)))
			for factor in [1.0 / 16, 1.0 / 1024, 64.0] {
				let scaled = Community.louvain(try WeightedGraph(
					edges: edges.map { ($0.0, $0.1, $0.2 * factor) }, isolatedNodes: names(12)))
				#expect(scaled == base, "seed \(seed) factor \(factor)")
			}
		}
	}

	@Test("A single edge is one community; an isolate stays alone")
	func smallest() throws {
		let p = Community.louvain(graph([("a", "b")], isolated: ["x"]))
		#expect(p["a"] == p["b"]); #expect(p["a"] != p["x"])
		#expect(p.communityCount == 2)
	}

	/// Resolution is the exponent of how much a community's size is penalised.
	/// Very large: nothing is worth joining. Zero: only connection counts.
	@Test("Resolution: huge keeps every node alone, zero merges a connected graph")
	func resolution() throws {
		let g = twoCliques
		#expect(Community.louvain(g, resolution: 1_000).communityCount == g.nodeCount)
		#expect(Community.louvain(g, resolution: 0).communityCount == 1)
		#expect(Community.louvain(g, resolution: 1).communityCount == 2)
	}

	@Test("Labels are dense, and numbered in the order of each community's first node")
	func labelsAreCanonical() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try WeightedGraph(edges: randomEdges(seed: 8_000 + seed, count: 12, edgeCount: 16 + Int(seed)),
								  isolatedNodes: names(12))
			let p = Community.louvain(g)
			var highest = -1
			for node in g.nodes {
				let label = p[node] ?? -99
				#expect(label >= 0 && label <= highest + 1, "seed \(seed) \(node)")
				highest = max(highest, label)
			}
			#expect(Set(p.communities.values).count == highest + 1)
			#expect(p.communities.count == g.nodeCount)
		}
	}

	@Test("The same graph and settings always give the same partition")
	func deterministic() throws {
		for seed in 0..<6 as Range<UInt64> {
			let g = try WeightedGraph(edges: randomEdges(seed: 9_000 + seed, count: 14, edgeCount: 30), isolatedNodes: names(14))
			let first = Community.louvain(g)
			for _ in 0..<3 { #expect(Community.louvain(g) == first) }
		}
	}

	@Test("Never worse than every node alone, and communities do not span components")
	func qualityAndConnectivity() throws {
		for seed in 0..<15 as Range<UInt64> {
			let g = try WeightedGraph(edges: randomEdges(seed: 10_000 + seed, count: 14, edgeCount: 12 + Int(seed)),
								  isolatedNodes: names(14))
			let p = Community.louvain(g)
			let singletons = NodePartition(Dictionary(uniqueKeysWithValues: g.nodes.enumerated().map { ($1, $0) }))
			#expect(Community.modularity(g, partition: p) >= Community.modularity(g, partition: singletons) - 1e-12)
			let components = Community.connectedComponents(g)
			for u in g.nodes {
				for v in g.nodes where p[u] == p[v] {
					#expect(components[u] == components[v], "seed \(seed): \(u) \(v)")
				}
			}
		}
	}

	@Test("Invariant under order-preserving relabelling and under uniform weight scaling")
	func invariances() throws {
		for seed in 0..<8 as Range<UInt64> {
			let edges = randomEdges(seed: 11_000 + seed, count: 12, edgeCount: 24)
			let base = Community.louvain(try WeightedGraph(edges: edges, isolatedNodes: names(12)))
			let renamed = Community.louvain(try WeightedGraph(
				edges: edges.map { ("z" + $0.0, "z" + $0.1, $0.2) }, isolatedNodes: names(12).map { "z" + $0 }))
			let scaled = Community.louvain(try WeightedGraph(
				edges: edges.map { ($0.0, $0.1, $0.2 * 16) }, isolatedNodes: names(12)))
			for node in names(12) {
				#expect(renamed["z" + node] == base[node], "seed \(seed)")
				#expect(scaled[node] == base[node], "seed \(seed)")
			}
		}
	}

	@Test("More passes never lower modularity; zero passes behaves as one")
	func passes() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try WeightedGraph(edges: randomEdges(seed: 12_000 + seed, count: 16, edgeCount: 30), isolatedNodes: names(16))
			let one = Community.louvain(g, maxPasses: 1)
			let many = Community.louvain(g, maxPasses: 20)
			#expect(Community.louvain(g, maxPasses: 0) == one)
			#expect(Community.modularity(g, partition: many) >= Community.modularity(g, partition: one) - 1e-12)
		}
	}

	/// Louvain on graphs whose best partition is known exactly by exhaustion
	/// (every set partition of 8 nodes: 4140 of them), scored by the independent
	/// definition above. On cliques-with-bridges the greedy answer is the optimum.
	@Test("Reaches the exhaustive optimum on small planted graphs")
	func matchesExhaustiveOptimum() throws {
		func allPartitions(_ n: Int) -> [[Int]] {
			var result: [[Int]] = []
			func extend(_ labels: [Int], _ top: Int) {
				if labels.count == n { result.append(labels); return }
				for label in 0...(top + 1) { extend(labels + [label], max(top, label)) }
			}
			extend([0], 0)
			return result
		}
		let graphs: [WeightedGraph<String>] = [
			graph(clique("a", 4) + clique("b", 4) + [("a0", "b0")]),
			graph(clique("a", 3) + clique("b", 3) + [("a0", "b0")], isolated: ["p", "q"]),
			graph(clique("a", 4) + clique("b", 4)),
		]
		for g in graphs {
			var best = -Double.infinity
			for labels in allPartitions(g.nodeCount) {
				let q = modularityByDefinition(g, NodePartition(Dictionary(uniqueKeysWithValues: zip(g.nodes, labels))))
				best = max(best, q)
			}
			let found = Community.modularity(g, partition: Community.louvain(g))
			#expect(close(found, best, tolerance: 1e-9), "found \(found) best \(best)")
		}
	}

	/// Differential test against the dense reference above, on graphs built to
	/// be full of ties (rings, grids, cliques on a ring, equal weights) as well
	/// as random weighted ones. Every move, tie-break and collapse has to agree.
	@Test("Agrees move for move with an independent dense Louvain")
	func agreesWithDenseReference() throws {
		var graphs: [WeightedGraph<String>] = []
		graphs.append(graph((0..<8).map { ("r\($0)", "r\(($0 + 1) % 8)") }))                         // ring
		graphs.append(graph((0..<3).flatMap { x in (0..<3).flatMap { y -> [(String, String)] in
			var e: [(String, String)] = []
			if x < 2 { e.append(("g\(x)\(y)", "g\(x + 1)\(y)")) }
			if y < 2 { e.append(("g\(x)\(y)", "g\(x)\(y + 1)")) }
			return e } }))                                                                          // grid
		graphs.append(graph(clique("a", 3) + clique("b", 3) + clique("c", 3) + clique("d", 3)
							+ [("a0", "b0"), ("b1", "c0"), ("c1", "d0"), ("d1", "a1")]))            // ring of cliques
		graphs.append(graph([("h", "a"), ("h", "b"), ("h", "c"), ("h", "d"), ("a", "b"), ("c", "d")]))
		graphs.append(graph(clique("a", 4) + clique("b", 4) + [("a0", "b0"), ("a1", "b1")], isolated: ["z"]))
		for seed in 0..<14 as Range<UInt64> {
			graphs.append(try WeightedGraph(edges: randomEdges(seed: 13_000 + seed, count: 9 + Int(seed % 4), edgeCount: 12 + Int(seed)),
										isolatedNodes: names(9 + Int(seed % 4))))
		}
		for (index, g) in graphs.enumerated() {
			for resolution in [1.0, 0.5, 2.0] {
				for passes in [1, 20] {
					let expected = louvainReference(g, resolution: resolution, maxPasses: passes)
					let actual = Community.louvain(g, resolution: resolution, maxPasses: passes)
					#expect(labels(actual, g) == expected,
							"graph \(index) resolution \(resolution) passes \(passes)")
				}
			}
		}
	}

	/// Gains closer than 1e-12 are ties (the lowest community number wins);
	/// gains further apart than that are real. Weights perturbed by a few parts
	/// in 1e13 and a few parts in 1e12 put the comparison on either side of
	/// the threshold, and the dense reference applies the same threshold.
	@Test("Differences below the 1e-12 tolerance are ties, and differences above it are not")
	func nearTies() throws {
		func perturbed(_ base: [(String, String)], _ delta: [Double]) throws -> WeightedGraph<String> {
			try WeightedGraph(edges: base.enumerated().map { ($1.0, $1.1, 1 + delta[$0 % delta.count]) })
		}
		let ring = (0..<8).map { ("r\($0)", "r\(($0 + 1) % 8)") }
		let cliques = clique("a", 3) + clique("b", 3) + clique("c", 3)
			+ [("a0", "b0"), ("b1", "c0"), ("c1", "a1")]
		let hub = [("h", "a"), ("h", "b"), ("h", "c"), ("h", "d"), ("a", "b"), ("c", "d")]
		for (index, base) in [ring, cliques, hub].enumerated() {
			for delta in [[0, 4e-13, 0, 0], [0, 0, 4e-12], [4e-12, 0, 4e-13], [0, 1e-11, 0, 4e-13, 4e-12],
						  [3e-12, 0, 0, 3e-13, 0, 6e-13], [0, 5e-12, 0]] {
				let g = try perturbed(base, delta)
				let expected = louvainReference(g)
				let actual = Community.louvain(g)
				#expect(labels(actual, g) == expected, "graph \(index) delta \(delta)")
			}
		}
	}
}
