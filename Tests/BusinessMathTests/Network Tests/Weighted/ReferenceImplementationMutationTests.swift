//
//  ReferenceImplementationMutationTests.swift
//  BusinessMath
//  Written from the mutation audit of the Phase-0 metrics (see
//  project/summaries/2026-11-11_centrality_mutation/summary.md).
//
//  The deliberately naive reference implementations (in TestSupport): the references are
//  what the cross-checks lean on, so they are themselves checked here against hand-derived
//  values. The value-type, registry and envelope parts of the original suite live with the
//  value types (NodeValueTests, MetricEnvelopeTests) or arrive with the registry (step 3).
//

import Foundation
import Testing

import TestSupport
@testable import BusinessMath

private func graph(
	_ edges: [(String, String)], isolated: [String] = []
) -> WeightedGraph<String> {
	WeightedGraph(unweightedEdges: edges, isolatedNodes: isolated)
}

private func close(_ actual: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
	guard let actual else { return false }
	return abs(actual - expected) <= tolerance
}

@Suite("Mutation audit: the independent reference implementations")
struct ReferenceImplementationMutationTests {

	@Test("Enumeration: path of three, star, four-cycle, and the degenerate sizes")
	func betweennessByHand() throws {
		let ref = { (g: WeightedGraph<String>, normalized: Bool) in
			IndependentImplementations.betweennessByEnumeration(g, normalized: normalized) }
		let p3 = graph([("a", "b"), ("b", "c")])
		#expect(close(ref(p3, true)["b"], 1)); #expect(close(ref(p3, false)["b"], 1)); #expect(close(ref(p3, true)["a"], 0))
		let star = graph([("h", "a"), ("h", "b"), ("h", "c"), ("h", "d")])
		#expect(close(ref(star, false)["h"], 6)); #expect(close(ref(star, true)["h"], 1))
		let c4 = graph([("a", "b"), ("b", "c"), ("c", "d"), ("d", "a")])
		for node in ["a", "b", "c", "d"] {
			#expect(close(ref(c4, false)[node], 0.5)); #expect(close(ref(c4, true)[node], 1.0 / 6.0))
		}
		let split = graph([("a", "b"), ("b", "c")], isolated: ["x"])
		#expect(close(ref(split, true)["b"], 1.0 / 3.0)); #expect(close(ref(split, true)["x"], 0))
		#expect(ref(try WeightedGraph<String>(edges: []), true).scores.isEmpty)
		#expect(ref(graph([], isolated: ["x"]), true).scores == ["x": 0])
		#expect(ref(graph([("a", "b")]), true).scores == ["a": 0, "b": 0])
		#expect(ref(graph([("a", "b")]), false).scores == ["a": 0, "b": 0])
	}

	@Test("Dense matrix: path of three, weighted path, star, bipartite, and the degenerate sizes")
	func eigenvectorByHand() throws {
		let ref = { (g: WeightedGraph<String>, iterations: Int) in
			IndependentImplementations.eigenvectorByDenseMatrix(g, iterations: iterations) }
		let p3 = ref(graph([("a", "b"), ("b", "c")]), 2_000)
		#expect(close(p3["a"], 1 / 2.0.squareRoot(), tolerance: 1e-9)); #expect(close(p3["b"], 1, tolerance: 1e-9))
		let weighted = ref(try WeightedGraph(edges: [("a", "b", 1.0), ("b", "c", 3.0)]), 2_000)
		#expect(close(weighted["a"], 1 / 10.0.squareRoot(), tolerance: 1e-9))
		#expect(close(weighted["c"], 3 / 10.0.squareRoot(), tolerance: 1e-9)); #expect(close(weighted["b"], 1, tolerance: 1e-9))
		let star = ref(graph([("h", "a"), ("h", "b"), ("h", "c"), ("h", "d")]), 2_000)
		#expect(close(star["h"], 1, tolerance: 1e-9)); #expect(close(star["a"], 0.5, tolerance: 1e-9))
		let triangle = ref(graph([("a", "b"), ("b", "c"), ("a", "c")]), 2_000)
		for node in ["a", "b", "c"] { #expect(close(triangle[node], 1, tolerance: 1e-9)) }
		let withIsolate = ref(graph([("a", "b"), ("b", "c"), ("a", "c")], isolated: ["x"]), 2_000)
		#expect(close(withIsolate["x"], 0, tolerance: 1e-9))
		#expect(ref(try WeightedGraph<String>(edges: []), 2_000).scores.isEmpty)
		#expect(ref(graph([], isolated: ["x"]), 2_000).scores == ["x": 1])
		// The iteration ceiling is floored at one pass: zero passes is one pass, not none.
		#expect(ref(graph([("a", "b"), ("b", "c")]), 0) == ref(graph([("a", "b"), ("b", "c")]), 1))
		#expect(ref(graph([("a", "b"), ("b", "c")]), 1) != ref(graph([("a", "b"), ("b", "c")]), 2))
		// No edges: nothing to rank, every node the same.
		#expect(Set(ref(graph([], isolated: ["x", "y"]), 2_000).scores.values).count == 1)
	}

	/// The reference must also converge where plain multiplication does not, and
	/// where the weights are far from one.
	@Test("Dense matrix: a bipartite graph beside an isolate, one pass by hand, and weights of any size")
	func eigenvectorEdgeCases() throws {
		let ref = { (g: WeightedGraph<String>, iterations: Int) in
			IndependentImplementations.eigenvectorByDenseMatrix(g, iterations: iterations) }
		// The isolate has degree zero, so a shift taken from the smallest degree would be zero
		// and the path would oscillate.
		let path = ref(graph([("a", "b"), ("b", "c")], isolated: ["x"]), 2_000)
		#expect(close(path["a"], 1 / 2.0.squareRoot(), tolerance: 1e-9)); #expect(close(path["b"], 1, tolerance: 1e-9))
		#expect(close(path["c"], 1 / 2.0.squareRoot(), tolerance: 1e-9)); #expect(close(path["x"], 0, tolerance: 1e-9))
		// One pass from a vector of ones with shift 2 (the largest degree): (A + 2I)(1,1,1) = (3,4,3).
		let one = ref(graph([("a", "b"), ("b", "c")]), 1)
		#expect(close(one["a"], 0.75, tolerance: 1e-12)); #expect(close(one["b"], 1, tolerance: 1e-12))
		// Path of six is sin(k pi / 7) at any scale of weight.
		let nodes = (0..<6).map { "p\($0)" }
		for weight in [1.0, 1e-3, 1e-6, 1e4] {
			let g = try WeightedGraph(edges: (1..<6).map { (nodes[$0 - 1], nodes[$0], weight) })
			let scores = ref(g, 2_000)
			for (k, node) in nodes.enumerated() {
				#expect(close(scores[node], sin(Double(k + 1) * Double.pi / 7) / sin(3 * Double.pi / 7), tolerance: 1e-6),
						"weight \(weight) node \(k)")
			}
		}
		// No edges: every node ties for the largest.
		#expect(ref(graph([], isolated: ["x", "y"]), 2_000).scores == ["x": 1, "y": 1])
	}

	@Test("Peeling: clique with a pendant and an isolate, a tail on a triangle, and the empty graph")
	func kCoreByHand() throws {
		let ref = { (g: WeightedGraph<String>) in IndependentImplementations.kCoreByPeeling(g) }
		let g = graph([("a", "b"), ("a", "c"), ("a", "d"), ("b", "c"), ("b", "d"), ("c", "d"), ("a", "e")], isolated: ["x"])
		let cores = ref(g)
		for node in ["a", "b", "c", "d"] { #expect(close(cores[node], 3)) }
		#expect(close(cores["e"], 1)); #expect(close(cores["x"], 0))
		let tail = ref(graph([("a", "b"), ("b", "c"), ("c", "a"), ("a", "a1"), ("a1", "a2")]))
		for node in ["a", "b", "c"] { #expect(close(tail[node], 2)) }
		#expect(close(tail["a1"], 1)); #expect(close(tail["a2"], 1))
		#expect(ref(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		#expect(ref(graph([], isolated: ["x", "y"])).scores == ["x": 0, "y": 0])
	}
}
