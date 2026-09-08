//
//  GraphTests.swift
//  BusinessMath
//
//  The graph type, Tarjan's components, and topological sort.
//
//  ## Determinism is the property under test
//
//  A graph algorithm whose output order varies between runs is unusable in a library that
//  tests for reproducibility, and `Dictionary` and `Set` iteration order in Swift is not
//  stable across runs. The design answer is that **sortedness is a property of the type**:
//  `Graph.init` sorts once at construction, so every algorithm inherits the guarantee and
//  no doc comment has to ask a caller for it.
//
//  These tests attack that directly. Each structural test builds the same graph from
//  several different insertion orders and requires bit-identical output — which is a
//  stronger claim than "the answer is correct", and the one that actually fails when the
//  guarantee is lost.
//
//  ## The parity cut
//
//  `DependencyGraph.components(of:)` has been in `Model Definition` for months and cycle
//  detection depends on it. Lifting it to a generic must not change a single answer, so
//  `parityWithDependencyGraph` runs both over the same inputs and compares exactly. That
//  test is the whole licence for the lift.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Graph, components and ordering")
struct GraphTests {

	// MARK: - Construction and determinism

	@Test("Adjacency is sorted at construction, whatever order it arrived in")
	func adjacencyIsSorted() throws {
		let graph = Graph(adjacency: ["b": ["d", "a", "c"], "a": ["c", "b"], "c": [], "d": []])
		#expect(graph.nodes == ["a", "b", "c", "d"], "nodes came back \(graph.nodes)")
		#expect(graph.neighbors(of: "b") == ["a", "c", "d"], "got \(graph.neighbors(of: "b"))")
		#expect(graph.neighbors(of: "a") == ["b", "c"])
		#expect(graph.neighbors(of: "missing").isEmpty)
	}

	@Test("A graph built from edges makes every mentioned node a vertex")
	func edgesIntroduceVertices() {
		let graph = Graph(edges: [("a", "b"), ("b", "c")])
		#expect(graph.nodes == ["a", "b", "c"], "got \(graph.nodes)")
		#expect(graph.neighbors(of: "c").isEmpty, "a sink still exists as a vertex")
		#expect(graph.edgeCount == 2, "got \(graph.edgeCount)")
	}

	@Test("Unlisted targets can be excluded, which is what a dependency graph needs")
	func unlistedTargetsPolicy() {
		// `Model Definition` reads a name with no definition as supplied data rather than
		// as a vertex, and an edge to it cannot participate in a cycle.
		let general = Graph(adjacency: ["a": ["b"]])
		#expect(general.nodes == ["a", "b"], "by default a target is a vertex: \(general.nodes)")

		let defined = Graph(adjacency: ["a": ["b"]], includeUnlistedTargets: false)
		#expect(defined.nodes == ["a"], "keys-only should give just a: \(defined.nodes)")
		#expect(defined.neighbors(of: "a").isEmpty, "the dangling edge should be dropped")
	}

	// MARK: - Strongly connected components

	@Test("Components are found, and are the ones worked out by hand")
	func componentsAreCorrect() {
		// a → b → c → a is one cycle; d → e is two singletons; f stands alone.
		let graph = Graph(adjacency: [
			"a": ["b"], "b": ["c"], "c": ["a"],
			"d": ["e"], "e": [], "f": [],
		])
		let components = graph.stronglyConnectedComponents
		let asSet = Set(components.map { Set($0) })
		#expect(asSet == [Set(["a", "b", "c"]), Set(["d"]), Set(["e"]), Set(["f"])],
				"got \(components)")
	}

	@Test("Every component's members come back sorted")
	func componentMembersAreSorted() {
		let graph = Graph(adjacency: ["z": ["y"], "y": ["x"], "x": ["z"]])
		let components = graph.stronglyConnectedComponents
		#expect(components.count == 1)
		#expect(components[0] == ["x", "y", "z"], "got \(components[0])")
	}

	@Test("A self-loop is a component of one, and is still a cycle")
	func selfLoop() {
		let graph = Graph(adjacency: ["a": ["a"], "b": []])
		let components = graph.stronglyConnectedComponents
		#expect(components.count == 2, "got \(components)")
		#expect(graph.isCyclic, "a self-loop is a cycle")
		#expect(Graph(adjacency: ["a": [], "b": []]).isCyclic == false)
	}

	@Test("Component output does not depend on the order the graph was built in")
	func componentsAreDeterministic() {
		// The same graph, six different insertion orders. Dictionary iteration order is
		// not stable across runs, so anything reading it directly fails this eventually
		// rather than immediately — which is why the test compares all six to each other
		// rather than to a fixture.
		let edges: [(String, String)] = [("a", "b"), ("b", "c"), ("c", "a"),
										 ("d", "a"), ("e", "d"), ("d", "e")]
		var results: [[[String]]] = []
		for seed in 0..<6 {
			var shuffled = edges
			// A fixed rotation per seed: deterministic, but a different insertion order.
			shuffled.rotate(by: seed)
			results.append(Graph(edges: shuffled).stronglyConnectedComponents)
		}
		let first = results[0]
		for (index, result) in results.enumerated() {
			#expect(result == first, "ordering \(index) gave \(result), not \(first)")
		}
	}

	// MARK: - Topological sort

	@Test("A DAG sorts so that every edge points forward")
	func topologicalOrder() throws {
		let graph = Graph(adjacency: [
			"shirt": ["tie"], "tie": ["jacket"], "belt": ["jacket"],
			"trousers": ["belt", "shoes"], "jacket": [], "shoes": [],
		])
		let order = try #require(graph.topologicalSort())
		#expect(order.count == graph.nodes.count, "got \(order.count) of \(graph.nodes.count)")
		var position: [String: Int] = [:]
		for (index, node) in order.enumerated() { position[node] = index }
		var checked = 0
		for node in graph.nodes {
			for target in graph.neighbors(of: node) {
				let from = try #require(position[node])
				let to = try #require(position[target])
				#expect(from < to, "edge \(node) → \(target) points backwards in \(order)")
				checked += 1
			}
		}
		#expect(checked == 5, "only \(checked) of 5 edges were checked")
	}

	@Test("A cyclic graph has no topological order and says so")
	func cyclicHasNoOrder() {
		#expect(Graph(adjacency: ["a": ["b"], "b": ["a"]]).topologicalSort() == nil)
		#expect(Graph(adjacency: ["a": ["a"]]).topologicalSort() == nil)
		// A DAG with a cycle bolted on the side is still cyclic.
		#expect(Graph(adjacency: ["a": ["b"], "b": [], "c": ["d"], "d": ["c"]])
			.topologicalSort() == nil)
	}

	@Test("The topological order is the same whatever order the graph was built in")
	func topologicalOrderIsDeterministic() {
		let edges: [(String, String)] = [("a", "c"), ("b", "c"), ("c", "d"), ("a", "b")]
		var results: [[String]] = []
		for seed in 0..<4 {
			var shuffled = edges
			shuffled.rotate(by: seed)
			if let order = Graph(edges: shuffled).topologicalSort() { results.append(order) }
		}
		#expect(results.count == 4, "only \(results.count) sorts succeeded")
		for (index, result) in results.enumerated() {
			#expect(result == results[0], "ordering \(index) gave \(result)")
		}
	}

	// MARK: - The parity cut

	@Test("The lifted components agree exactly with the ones Model Definition shipped")
	func parityWithDependencyGraph() {
		// Cycle detection has depended on `DependencyGraph.components(of:)` for months.
		// The lift is only safe if it changes nothing, so both are run over the same
		// inputs and compared exactly — including the order components come back in,
		// which callers may be relying on whether or not they should.
		let graphs: [[String: [String]]] = [
			["revenue": ["price", "volume"], "price": [], "volume": []],
			["a": ["b"], "b": ["c"], "c": ["a"]],
			["a": ["a"]],
			["interest": ["debt"], "debt": ["interest"], "cash": ["interest"]],
			// Names with no definition are supplied data, not vertices.
			["total": ["supplied", "computed"], "computed": ["supplied"]],
			[:],
		]
		var compared = 0
		for graph in graphs {
			let original = DependencyGraph.components(of: graph)
			let lifted = Graph(adjacency: graph, includeUnlistedTargets: false)
				.stronglyConnectedComponents
			#expect(lifted == original,
					"lifted \(lifted) against original \(original) for \(graph)")
			compared += 1
		}
		#expect(compared == graphs.count, "only \(compared) graphs were compared")
	}

	@Test("The lift works at a node type that is not String")
	func genericNodeType() {
		let graph = Graph(adjacency: [1: [2], 2: [3], 3: [1], 4: []])
		let components = graph.stronglyConnectedComponents
		#expect(components.count == 2, "got \(components)")
		#expect(components.contains([1, 2, 3]), "got \(components)")
		#expect(components.contains([4]))
	}
}

private extension Array {
	/// Rotates in place — a deterministic way to vary insertion order across a test.
	mutating func rotate(by amount: Int) {
		guard !isEmpty, amount > 0 else { return }
		let shift = amount % count
		self = Array(self[shift...] + self[..<shift])
	}
}
