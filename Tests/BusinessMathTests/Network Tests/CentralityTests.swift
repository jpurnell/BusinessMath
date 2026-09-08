//
//  CentralityTests.swift
//  BusinessMath
//
//  Degree, PageRank, betweenness, harmonic closeness, eigenvector.
//
//  ## The fixture is chosen to make the case for shipping all five
//
//  An earlier draft of the marketing proposal cut betweenness, closeness and eigenvector,
//  on the strength of a finding that degree matched PageRank to within noise on one
//  dataset. §12.3 records why that reasoning was withdrawn, and this fixture is the
//  concrete demonstration.
//
//  Two triangles joined through a single bridge node `d`:
//
//  ```
//      a───b        f───g
//       ╲ ╱          ╲ ╱
//        c─────d─────e
//  ```
//
//  | node | degree | betweenness | PageRank |
//  |---|---|---|---|
//  | **d** | **2 — lowest tier** | **0.600 — highest** | **0.125 — lowest** |
//  | c, e | 3 | 0.533 | 0.183 |
//  | a, b, f, g | 2 | 0.000 | 0.127 |
//
//  `d` is the only path between the two clusters — remove it and the graph falls in half
//  — and **both degree and PageRank rank it last of seven**. Brokerage and popularity are
//  different questions, and no amount of tuning a popularity measure produces the
//  brokerage answer.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Centrality")
struct CentralityTests {

	/// Two triangles bridged by `d`, as an undirected graph.
	private static var bridged: Graph<String> {
		let undirected: [(String, String)] = [
			("a", "b"), ("b", "a"), ("a", "c"), ("c", "a"), ("b", "c"), ("c", "b"),
			("c", "d"), ("d", "c"), ("d", "e"), ("e", "d"),
			("e", "f"), ("f", "e"), ("e", "g"), ("g", "e"), ("f", "g"), ("g", "f"),
		]
		return Graph(edges: undirected)
	}

	// MARK: - The argument for the suite

	@Test("The bridge has the lowest degree, the lowest PageRank, and the highest betweenness")
	func brokerageIsNotPopularity() throws {
		let graph = Self.bridged
		let degree = graph.degreeCentrality
		let rank = try #require(graph.pageRank())
		let between = graph.betweennessCentrality

		let bridgeDegree = try #require(degree["d"])
		let hubDegree = try #require(degree["c"])
		#expect(bridgeDegree < hubDegree, "d should be less connected than c")

		let bridgeRank = try #require(rank["d"])
		for node in ["a", "b", "c", "e", "f", "g"] {
			let other = try #require(rank[node])
			#expect(bridgeRank <= other,
					"PageRank puts d at \(bridgeRank), above \(node) at \(other)")
		}

		let bridgeBetween = try #require(between["d"])
		for node in ["a", "b", "c", "e", "f", "g"] {
			let other = try #require(between[node])
			#expect(bridgeBetween >= other,
					"betweenness puts d at \(bridgeBetween), below \(node) at \(other)")
		}
		#expect(bridgeBetween > 0.5, "the bridge should be strongly central, got \(bridgeBetween)")
	}

	// MARK: - Against independently computed values

	@Test("Degree centrality counts neighbours")
	func degreeCentrality() throws {
		let degree = Self.bridged.degreeCentrality
		let expected: [String: Double] = ["a": 2, "b": 2, "c": 3, "d": 2,
										  "e": 3, "f": 2, "g": 2]
		var checked = 0
		for (node, wanted) in expected.sorted(by: { $0.key < $1.key }) {
			let got = try #require(degree[node])
			#expect(Swift.abs(got - wanted) < 1e-12, "\(node): \(got), expected \(wanted)")
			checked += 1
		}
		#expect(checked == 7)
	}

	@Test("Betweenness matches a reference implementation of Brandes")
	func betweenness() throws {
		let expected: [String: Double] = [
			"a": 0, "b": 0, "c": 0.5333333333, "d": 0.6,
			"e": 0.5333333333, "f": 0, "g": 0,
		]
		let between = Self.bridged.betweennessCentrality
		var checked = 0
		for (node, wanted) in expected.sorted(by: { $0.key < $1.key }) {
			let got = try #require(between[node])
			#expect(Swift.abs(got - wanted) < 1e-9, "\(node): \(got), expected \(wanted)")
			checked += 1
		}
		#expect(checked == 7)
	}

	@Test("PageRank matches a reference power iteration and sums to one")
	func pageRank() throws {
		let expected: [String: Double] = [
			"a": 0.1273440708, "b": 0.1273440708, "c": 0.1828033034,
			"d": 0.1250171100, "e": 0.1828033034, "f": 0.1273440708,
			"g": 0.1273440708,
		]
		let rank = try #require(Self.bridged.pageRank())
		var total: Double = 0
		var checked = 0
		for (node, wanted) in expected.sorted(by: { $0.key < $1.key }) {
			let got = try #require(rank[node])
			#expect(Swift.abs(got - wanted) < 1e-7, "\(node): \(got), expected \(wanted)")
			total += got
			checked += 1
		}
		#expect(Swift.abs(total - 1) < 1e-9, "PageRank sums to \(total)")
		#expect(checked == 7)
	}

	@Test("Harmonic closeness matches a reference breadth-first computation")
	func closeness() throws {
		let expected: [String: Double] = [
			"a": 0.5555555556, "b": 0.5555555556, "c": 0.6944444444,
			"d": 0.6666666667, "e": 0.6944444444, "f": 0.5555555556,
			"g": 0.5555555556,
		]
		let close = Self.bridged.harmonicCloseness
		var checked = 0
		for (node, wanted) in expected.sorted(by: { $0.key < $1.key }) {
			let got = try #require(close[node])
			#expect(Swift.abs(got - wanted) < 1e-9, "\(node): \(got), expected \(wanted)")
			checked += 1
		}
		#expect(checked == 7)
	}

	@Test("Eigenvector centrality matches a reference power iteration")
	func eigenvector() throws {
		let expected: [String: Double] = [
			"a": 0.3348052733, "b": 0.3348052733, "c": 0.4496177297,
			"d": 0.3838092108, "e": 0.4496177297, "f": 0.3348052733,
			"g": 0.3348052733,
		]
		let vector = try #require(Self.bridged.eigenvectorCentrality())
		var checked = 0
		for (node, wanted) in expected.sorted(by: { $0.key < $1.key }) {
			let got = try #require(vector[node])
			#expect(Swift.abs(got - wanted) < 1e-6, "\(node): \(got), expected \(wanted)")
			checked += 1
		}
		#expect(checked == 7)
		// L2-normalised, so the vector has unit length.
		let lengthSquared = vector.values.reduce(0.0) { $0 + $1 * $1 }
		#expect(Swift.abs(lengthSquared - 1) < 1e-9, "‖v‖² = \(lengthSquared)")
	}

	// MARK: - Where the measures are defined and where they are not

	@Test("Harmonic closeness stays defined on a disconnected graph")
	func closenessSurvivesDisconnection() throws {
		// This is why harmonic rather than the classical variant. Classical closeness is
		// n−1 over the *sum* of distances, which is infinite when anything is
		// unreachable, so the whole measure collapses to zero for every node in a graph
		// with two components. Harmonic sums reciprocals instead, so an unreachable node
		// contributes nothing and the rest of the answer survives.
		let split = Graph(edges: [("a", "b"), ("b", "a"), ("c", "d"), ("d", "c")])
		let close = split.harmonicCloseness
		let a = try #require(close["a"])
		#expect(Swift.abs(a - 1.0 / 3.0) < 1e-12,
				"one reachable neighbour of three others gives 1/3, got \(a)")
		#expect(a > 0, "a disconnected graph must not collapse the measure to zero")
	}

	@Test("PageRank reports a failure to converge rather than its last iterate")
	func pageRankRefusesWithoutConvergence() {
		// One iteration cannot converge on this graph, and returning whatever the vector
		// held at that point would be a ranking with no meaning and no marker saying so.
		#expect(Self.bridged.pageRank(maxIterations: 1) == nil)
		#expect(Self.bridged.pageRank(damping: 1.5) == nil)
		#expect(Self.bridged.pageRank(damping: 0) == nil)
	}

	@Test("Eigenvector centrality refuses a graph where it is not meaningful")
	func eigenvectorRefusesLocalisation() {
		// A disconnected graph has one eigenvector per component and the power iteration
		// converges to whichever the start vector favours — an answer that depends on the
		// initial guess is not a property of the graph.
		let split = Graph(edges: [("a", "b"), ("b", "a"), ("c", "d"), ("d", "c")])
		#expect(split.eigenvectorCentrality() == nil)
		// A graph with no edges has no leading eigenvector at all.
		#expect(Graph(adjacency: ["a": [], "b": []]).eigenvectorCentrality() == nil)
	}

	@Test("An empty graph has no centrality of any kind")
	func emptyGraph() {
		let empty = Graph<String>(adjacency: [:])
		#expect(empty.degreeCentrality.isEmpty)
		#expect(empty.betweennessCentrality.isEmpty)
		#expect(empty.harmonicCloseness.isEmpty)
		#expect(empty.pageRank() == nil)
		#expect(empty.eigenvectorCentrality() == nil)
	}
}
