//
//  BurtConstraintTests.swift
//  BusinessMath
//  Burt's constraint, checked against values derived by hand from the definition and
//  against a literal dense-matrix transcription of it that shares no code with the
//  implementation.
//

import Foundation
import SwiftDeterminism
import Testing

import TestSupport
@testable import BusinessMath

private var kite: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
}

private var karate: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges.map {
		(String($0.0), String($0.1))
	})
}

/// A score that is `NaN` when the node is missing, so every comparison against it fails.
/// Absence is then a failed assertion rather than a value invented to stand in for it.
private func score(_ scores: NodeScores<String>, _ node: String) -> Double {
	scores[node] ?? .nan
}

/// A direct transcription of Burt (1992) over a dense matrix: no adjacency lists, no
/// scratch arrays, no shared helpers. Slow by design.
///
/// `c_i = Σ_{j≠i, w_ij>0} ( p_ij + Σ_{q≠i,j} p_iq · p_qj )²`, with `p_ij = w_ij / Σ_k w_ik`.
private func denseConstraint(_ graph: WeightedGraph<String>) -> [String: Double] {
	let n = graph.nodeCount
	var w = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
	for (i, list) in graph.adjacency.enumerated() {
		for entry in list { w[i][entry.neighbour] = entry.weight }
	}
	var p = w
	for i in 0..<n {
		let strength = w[i].reduce(0, +)
		for j in 0..<n { p[i][j] = strength > 0 ? w[i][j] / strength : 0 }
	}
	var result: [String: Double] = [:]
	for i in 0..<n where w[i].contains(where: { $0 > 0 }) {
		var total = 0.0
		for j in 0..<n where j != i && w[i][j] > 0 {
			var inner = p[i][j]
			for q in 0..<n where q != i && q != j { inner += p[i][q] * p[q][j] }
			total += inner * inner
		}
		result[graph.nodes[i]] = total
	}
	return result
}

@Suite("Burt constraint: hand-derived values")
struct BurtConstraintHandDerivedTests {

	private let tolerance = 1e-12

	@Test("Star with n leaves: centre is 1/n, every leaf is 1", arguments: [3, 5])
	func star(leaves: Int) {
		let edges = (1...leaves).map { ("hub", "leaf\($0)") }
		let scores = Brokerage.constraint(WeightedGraph(unweightedEdges: edges))
		#expect(abs(score(scores, "hub") - (1 / Double(leaves))) < tolerance)
		for index in 1...leaves {
			#expect(abs(score(scores, "leaf\(index)") - 1) < tolerance)
		}
	}

	@Test("Triangle: each node is 2 * (1/2 + 1/4)^2 = 1.125")
	func triangle() {
		let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("a", "c")])
		let scores = Brokerage.constraint(graph)
		for node in ["a", "b", "c"] {
			#expect(abs(score(scores, node) - 1.125) < tolerance)
		}
	}

	@Test("Path a-b-c: the ends are 1, the middle is 0.5")
	func path() {
		let scores = Brokerage.constraint(WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")]))
		#expect(abs(score(scores, "a") - 1) < tolerance)
		#expect(abs(score(scores, "c") - 1) < tolerance)
		#expect(abs(score(scores, "b") - 0.5) < tolerance)
	}

	/// Weighted triangle a-b = 1, a-c = 1, b-c = 2.
	///
	/// Strengths: a = 2, b = 3, c = 3. So
	/// p_ab = 1/2, p_ac = 1/2; p_ba = 1/3, p_bc = 2/3; p_ca = 1/3, p_cb = 2/3.
	///
	/// c_a: j = b: p_ab + p_ac·p_cb = 1/2 + 1/3 = 5/6;  j = c: p_ac + p_ab·p_bc = 1/2 + 1/3 = 5/6.
	///      c_a = 2·(5/6)² = 50/36 = 25/18.
	/// c_b: j = a: p_ba + p_bc·p_ca = 1/3 + 2/9 = 5/9;  j = c: p_bc + p_ba·p_ac = 2/3 + 1/6 = 5/6.
	///      c_b = (5/9)² + (5/6)² = 25/81 + 25/36 = 325/324.
	/// c_c: j = a: p_ca + p_cb·p_ba = 1/3 + 2/9 = 5/9;  j = b: p_cb + p_ca·p_ab = 2/3 + 1/6 = 5/6.
	///      c_c = 325/324.
	@Test("Weighted triangle matches the hand derivation")
	func weightedTriangle() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1.0), ("a", "c", 1.0), ("b", "c", 2.0)])
		let scores = Brokerage.constraint(graph)
		#expect(abs(score(scores, "a") - (25.0 / 18.0)) < tolerance)
		#expect(abs(score(scores, "b") - (325.0 / 324.0)) < tolerance)
		#expect(abs(score(scores, "c") - (325.0 / 324.0)) < tolerance)
	}

	@Test("An isolated node is omitted, not scored 0 and not NaN")
	func isolatedOmitted() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1.0)], isolatedNodes: ["loner"])
		let scores = Brokerage.constraint(graph)
		#expect(scores["loner"] == nil)
		#expect(scores.scores.count == 2)
		#expect(scores.scores.values.allSatisfy { $0.isFinite })
	}

	@Test("Empty graph and single node give empty scores")
	func degenerate() throws {
		#expect(Brokerage.constraint(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		#expect(Brokerage.constraint(try WeightedGraph<String>(edges: [], isolatedNodes: ["x"])).scores.isEmpty)
	}

	@Test("A disconnected graph is scored component by component")
	func disconnected() {
		let graph = WeightedGraph(unweightedEdges: [
			("h", "x"), ("h", "y"), ("h", "z"),
			("a", "b"), ("b", "c"), ("a", "c"),
		])
		let scores = Brokerage.constraint(graph)
		#expect(abs(score(scores, "h") - (1.0 / 3.0)) < tolerance)
		#expect(abs(score(scores, "a") - 1.125) < tolerance)
		#expect(scores.scores.count == 7)
	}
}

@Suite("Burt constraint: second opinion and invariants")
struct BurtConstraintCrossCheckTests {

	// networkx is not installed in this environment, so the second source is the dense
	// transcription above rather than `networkx.constraint`.
	@Test("Agrees with the dense-matrix transcription on the kite and the karate club")
	func agreesWithDense() {
		for graph in [kite, karate] {
			let fast = Brokerage.constraint(graph)
			let slow = denseConstraint(graph)
			#expect(fast.scores.count == slow.count)
			for node in graph.nodes {
				let a = score(fast, node)
				let b = slow[node] ?? .nan
				#expect(abs(a - b) < 1e-9, "\(node): \(a) vs \(b)")
			}
		}
	}

	@Test("Agrees with the dense transcription on a weighted, irregular graph")
	func agreesOnWeighted() throws {
		let graph = try WeightedGraph(edges: [
			("a", "b", 2.5), ("a", "c", 0.5), ("b", "c", 1.0), ("c", "d", 4.0),
			("d", "e", 1.5), ("c", "e", 0.25), ("e", "f", 3.0),
		])
		let fast = Brokerage.constraint(graph)
		let slow = denseConstraint(graph)
		for node in graph.nodes {
			#expect(abs(score(fast, node) - (slow[node] ?? .nan)) < 1e-12)
		}
	}

	@Test("Constraint is positive for every non-isolated node; a single neighbour gives 1")
	func invariants() {
		for graph in [kite, karate] {
			let scores = Brokerage.constraint(graph)
			for (index, node) in graph.nodes.enumerated() {
				let value = scores[node]
				guard graph.neighbourCount(index) > 0 else {
					#expect(value == nil)
					continue
				}
				#expect(score(scores, node) > 0, "\(node)")
				if graph.neighbourCount(index) == 1 {
					#expect(abs(score(scores, node) - 1) < 1e-12, "\(node)")
				}
			}
		}
		// The kite's pendant, Jane, has exactly one neighbour.
		#expect(abs(score(Brokerage.constraint(kite), "Jane") - 1) < 1e-12)
	}

	@Test("The kite's connector is the lowest-constraint broker among its hubs")
	func kiteBroker() {
		let scores = Brokerage.constraint(kite)
		#expect((score(scores, "Heather")) < (score(scores, "Diane")))
	}

	@Test("Repeated runs give identical output")
	func deterministic() {
		#expect(Brokerage.constraint(karate) == Brokerage.constraint(karate))
	}

}

// MARK: - Mutation-audit additions (test-quality pass, 2026-11-11)
//
// Written after a mutation audit of `Brokerage.constraint`. The dense transcription above is
// the oracle: it shares no code with the implementation. What the earlier tests lacked was
// breadth (three fixed graphs) and the structural properties the maths gives for free.

private func label(_ index: Int) -> String {
	let digits = String(index)
	return "v" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
}

/// A seeded random weighted graph, every node present. Weights are positive.
private func randomBrokerageGraph(
	nodes: Int, edgeProbability: Double, seed: UInt64, labelOf: (Int) -> String = label,
	weightScale: Double = 1
) throws -> (graph: WeightedGraph<String>, edges: [(Int, Int, Double)]) {
	var rng = SplitMix64(seed: seed)
	var edges: [(Int, Int, Double)] = []
	for a in 0..<nodes {
		for b in (a + 1)..<max(a + 1, nodes) where Double.random(in: 0..<1, using: &rng) < edgeProbability {
			edges.append((a, b, Double.random(in: 0.25...4, using: &rng)))
		}
	}
	let graph = try WeightedGraph(
		edges: edges.map { (labelOf($0.0), labelOf($0.1), $0.2 * weightScale) },
		isolatedNodes: (0..<nodes).map(labelOf))
	return (graph, edges)
}

private let burtSeeds: [UInt64] = Array(1...16)

@Suite("Burt constraint: properties")
struct BurtConstraintPropertyTests {

	@Test("Agrees with the dense transcription on seeded random weighted graphs, at several densities", .timeLimit(.minutes(1)),
		  arguments: burtSeeds)
	func agreesWithDenseOnRandomGraphs(seed: UInt64) throws {
		for density in [0.1, 0.3, 0.7] {
			let (graph, _) = try randomBrokerageGraph(nodes: 12, edgeProbability: density, seed: seed)
			let fast = Brokerage.constraint(graph)
			let slow = denseConstraint(graph)
			#expect(fast.scores.count == slow.count, "seed \(seed) density \(density)")
			for node in graph.nodes {
				guard let want = slow[node] else {
					#expect(fast[node] == nil, "isolated \(node) must be omitted")
					continue
				}
				#expect(abs(score(fast, node) - want) < 1e-9, "\(node) seed \(seed) density \(density)")
			}
		}
	}

	/// Bounds from the definition. With shares p_ij summing to 1 over d contacts,
	/// sum p_ij^2 >= 1/d (Cauchy-Schwarz), and indirect terms only add, so c >= 1/d.
	/// Each investment p_ij + sum_q p_iq p_qj is at most p_ij + sum_{q != j} p_iq <= 1, and
	/// the investments sum to at most 1 + sum_q p_iq * 1 = 2, so c <= 1 * 2.
	@Test("Constraint is positive for every non-isolated node and lies in [1/degree, 2]",
		  arguments: burtSeeds)
	func boundsAndPositivity(seed: UInt64) throws {
		let (graph, _) = try randomBrokerageGraph(nodes: 15, edgeProbability: 0.25, seed: seed)
		let scores = Brokerage.constraint(graph)
		var scored = 0
		for (index, node) in graph.nodes.enumerated() {
			let degree = graph.neighbourCount(index)
			if degree == 0 {
				#expect(scores[node] == nil, "isolated \(node) must be omitted")
				continue
			}
			scored += 1
			let value = score(scores, node)
			#expect(value.isFinite && value > 0, "\(node)")
			#expect(value >= 1 / Double(degree) - 1e-12, "\(node) lower bound")
			#expect(value <= 2 + 1e-12, "\(node) upper bound")
		}
		#expect(scores.scores.count == scored)
	}

	@Test("Scaling every weight by a constant changes nothing: shares are ratios",
		  arguments: [0.001, 7.0, 1e6])
	func weightScaleInvariance(factor: Double) throws {
		for seed in burtSeeds.prefix(6) {
			let (base, _) = try randomBrokerageGraph(nodes: 12, edgeProbability: 0.3, seed: seed)
			let (scaled, _) = try randomBrokerageGraph(nodes: 12, edgeProbability: 0.3, seed: seed, weightScale: factor)
			let a = Brokerage.constraint(base)
			let b = Brokerage.constraint(scaled)
			#expect(a.scores.count == b.scores.count)
			for node in base.nodes where a[node] != nil || b[node] != nil {
				#expect(abs(score(a, node) - score(b, node)) < 1e-9, "\(node) seed \(seed) factor \(factor)")
			}
		}
	}

	@Test("Relabelling the nodes relabels the scores and nothing else", arguments: burtSeeds)
	func relabelInvariance(seed: UInt64) throws {
		let nodes = 12
		var rng = SplitMix64(seed: seed &+ 40)
		let permutation = Array(0..<nodes).shuffled(using: &rng)
		let (original, _) = try randomBrokerageGraph(nodes: nodes, edgeProbability: 0.3, seed: seed)
		let (relabelled, _) = try randomBrokerageGraph(
			nodes: nodes, edgeProbability: 0.3, seed: seed, labelOf: { label(permutation[$0]) })
		let a = Brokerage.constraint(original)
		let b = Brokerage.constraint(relabelled)
		#expect(a.scores.count == b.scores.count)
		for index in 0..<nodes {
			#expect(a[label(index)] == nil ? b[label(permutation[index])] == nil
				: abs(score(a, label(index)) - score(b, label(permutation[index]))) < 1e-12,
				"node \(index) -> \(permutation[index]) seed \(seed)")
		}
	}

	@Test("How the same graph is written does not matter: duplicate edges merge, direction and self-loops are irrelevant")
	func edgeListNormalisation() throws {
		let merged = try WeightedGraph(edges: [("a", "b", 3.0), ("b", "c", 1.0), ("a", "c", 2.0)])
		let written = try WeightedGraph(edges: [
			("b", "a", 1.0), ("a", "b", 2.0), ("c", "b", 1.0), ("c", "a", 2.0), ("a", "a", 9.0), ("c", "c", 4.0),
		])
		#expect(Brokerage.constraint(merged) == Brokerage.constraint(written))
	}

	@Test("Isolated, zero-weight and unusable ties are omitted, never scored 0 or NaN")
	func unusableTies() throws {
		// Both ends of a zero-weight tie have no tie strength at all.
		let zero = Brokerage.constraint(try WeightedGraph(edges: [("a", "b", 0.0), ("c", "d", 1.0)]))
		#expect(zero["a"] == nil && zero["b"] == nil)
		#expect(abs(score(zero, "c") - 1) < 1e-12 && abs(score(zero, "d") - 1) < 1e-12)
		// Weights that would overflow a tie strength are refused when the graph is built, so no
		// score can be built on one (NaN, infinite and negative weights likewise).
		#expect(throws: GraphError.weightSumOverflow) {
			_ = try WeightedGraph(edges: [("a", "b", 1e308), ("a", "c", 1e308)])
		}
		// Tiny but positive weights are ratios like any other.
		let tiny = Brokerage.constraint(try WeightedGraph(edges: [("a", "b", 1e-300), ("b", "c", 1e-300)]))
		#expect(abs(score(tiny, "b") - 0.5) < 1e-12)
	}

	@Test("A node reached by a single contact always scores 1, whoever the contact is",
		  arguments: burtSeeds)
	func pendantIsOne(seed: UInt64) throws {
		let (graph, _) = try randomBrokerageGraph(nodes: 14, edgeProbability: 0.12, seed: seed)
		let scores = Brokerage.constraint(graph)
		for (index, node) in graph.nodes.enumerated() where graph.neighbourCount(index) == 1 {
			#expect(abs(score(scores, node) - 1) < 1e-12, "\(node)")
		}
	}

	@Test("Introducing two of a hub's contacts to each other raises the hub's constraint")
	func closureRaisesConstraint() {
		// A hub with four mutually unknown contacts, then one contact pair introduced.
		let open = WeightedGraph(unweightedEdges: [("h", "a"), ("h", "b"), ("h", "c"), ("h", "d")])
		let closed = WeightedGraph(unweightedEdges: [("h", "a"), ("h", "b"), ("h", "c"), ("h", "d"), ("a", "b")])
		#expect(abs(score(Brokerage.constraint(open), "h") - 0.25) < 1e-12)
		#expect(score(Brokerage.constraint(closed), "h") > score(Brokerage.constraint(open), "h") + 1e-3)
	}

	/// The size the package was built for: about 1,100 nodes and 15,000 edges.
	@Test("Constraint on a 1,100-node, 15,000-edge graph finishes quickly and every score is finite and positive",
		  .timeLimit(.minutes(1)))
	func largeGraph() throws {
		var rng = SplitMix64(seed: 11)
		var edges: [(String, String, Double)] = []
		var seen = Set<[Int]>()
		while seen.count < 15_000 {
			let a = Int.random(in: 0..<1100, using: &rng)
			let b = Int.random(in: 0..<1100, using: &rng)
			guard a != b, seen.insert([min(a, b), max(a, b)]).inserted else { continue }
			edges.append((label(a), label(b), Double.random(in: 0.5...5, using: &rng)))
		}
		let graph = try WeightedGraph(edges: edges, isolatedNodes: (0..<1100).map(label))
		let scores = Brokerage.constraint(graph)
		#expect(scores.scores.values.allSatisfy { $0.isFinite && $0 > 0 && $0 <= 2 })
		#expect(scores.scores.count == (0..<1100).filter { graph.neighbourCount($0) > 0 }.count)
	}
}

// MARK: - Zero-weight ties (ADR-003)

/// A tie of weight zero is no tie. Burt (1992) defines a node's contacts as the nodes it has a
/// tie to, and a recorded tie that carries no strength is not one. The same reading is already
/// applied to a node whose every tie is zero (it is omitted), so it applies to a single zero
/// tie among others too.
@Suite("Burt constraint: a zero-weight tie is not a tie")
struct BurtZeroWeightTests {

	/// a-b = 1, a-c = 0, b-c = 1.
	///
	/// Without the a-c tie, `a` has one contact, `b`: constraint exactly 1. `b` has contacts
	/// `a` and `c` (p = 1/2 each), and `a` and `c` share no tie, so each contributes (1/2)^2:
	/// 1/2. `c` mirrors `a`: 1. If the zero tie were counted, `a` would gain an indirect
	/// investment in `c` through `b` (1 * 1/2) and score 1 + 1/4 = 1.25.
	@Test("a-b = 1, a-c = 0, b-c = 1 scores a = 1, b = 1/2, c = 1")
	func pinned() throws {
		let scores = Brokerage.constraint(try WeightedGraph(edges: [("a", "b", 1.0), ("a", "c", 0.0), ("b", "c", 1.0)]))
		#expect(abs(score(scores, "a") - 1.0) < 1e-12, "a = \(score(scores, "a"))")
		#expect(abs(score(scores, "b") - 0.5) < 1e-12, "b = \(score(scores, "b"))")
		#expect(abs(score(scores, "c") - 1.0) < 1e-12, "c = \(score(scores, "c"))")
	}

	@Test("Adding zero-weight edges changes no score, over seeded random graphs", arguments: Array(0..<40 as Range<UInt64>))
	func zeroEdgeIsAbsentEdge(seed: UInt64) throws {
		let nodes = 12
		let base = try randomBrokerageGraph(nodes: nodes, edgeProbability: 0.25, seed: seed)
		var rng = SplitMix64(seed: seed &+ 5000)
		var edges = base.edges.map { (label($0.0), label($0.1), $0.2) }
		let present = Set(base.edges.map { [min($0.0, $0.1), max($0.0, $0.1)] })
		var added = 0
		for a in 0..<nodes {
			for b in (a + 1)..<max(a + 1, nodes)
			where !present.contains([a, b]) && Double.random(in: 0..<1, using: &rng) < 0.3 {
				edges.append((label(a), label(b), 0.0))
				added += 1
			}
		}
		let withZeros = try WeightedGraph(edges: edges, isolatedNodes: (0..<nodes).map(label))
		#expect(added > 0)
		let plain = Brokerage.constraint(base.graph)
		let zeros = Brokerage.constraint(withZeros)
		#expect(Set(zeros.scores.keys) == Set(plain.scores.keys))
		for node in base.graph.nodes {
			guard let expected = plain[node] else { continue }
			#expect(abs(score(zeros, node) - expected) < 1e-12, "\(node): \(score(zeros, node)) vs \(expected)")
		}
	}

	@Test("Agrees with the dense transcription on graphs mixing zero and positive weights",
		  arguments: Array(0..<40 as Range<UInt64>))
	func agreesWithDenseWithZeros(seed: UInt64) throws {
		var rng = SplitMix64(seed: seed &+ 9000)
		var edges: [(String, String, Double)] = []
		for a in 0..<10 {
			for b in (a + 1)..<10 where Double.random(in: 0..<1, using: &rng) < 0.35 {
				let weight = Bool.random(using: &rng) ? 0.0 : Double.random(in: 0.25...4, using: &rng)
				edges.append((label(a), label(b), weight))
			}
		}
		let graph = try WeightedGraph(edges: edges, isolatedNodes: (0..<10).map(label))
		let fast = Brokerage.constraint(graph)
		let slow = denseConstraint(graph)
		#expect(Set(fast.scores.keys) == Set(slow.keys))
		for (node, expected) in slow {
			#expect(abs(score(fast, node) - expected) < 1e-9, "\(node): \(score(fast, node)) vs \(expected)")
		}
	}
}
