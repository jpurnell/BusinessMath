//
//  GraphBridgeTests.swift
//  BusinessMath
//
//  Graph <-> WeightedGraph. New in BusinessMath: the bridge did not exist in SwiftGraphMetrics.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

@Suite("Graph and WeightedGraph bridges")
struct GraphBridgeTests {

	@Test("Symmetrising a directed edge makes one undirected tie of weight one")
	func directedEdgeBecomesUndirected() {
		let weighted = WeightedGraph(Graph(edges: [("a", "b")]))
		#expect(weighted.nodes == ["a", "b"])
		#expect(weighted.edgeCount == 1)
		#expect(weighted.totalWeight.isEqual(to: 1))
		#expect(weighted.degree(of: "a")?.isEqual(to: 1) == true)
		#expect(weighted.degree(of: "b")?.isEqual(to: 1) == true)
	}

	@Test("Edges listed in both directions still weigh one, not two")
	func reciprocalEdgesNotDoubled() {
		let weighted = WeightedGraph(Graph(edges: [("a", "b"), ("b", "a"), ("b", "c")]))
		#expect(weighted.edgeCount == 2)
		#expect(weighted.totalWeight.isEqual(to: 2))
		#expect(weighted.degree(of: "a")?.isEqual(to: 1) == true)
		#expect(weighted.degree(of: "b")?.isEqual(to: 2) == true)
	}

	@Test("Every weight in a symmetrised graph is exactly one")
	func allWeightsOne() {
		let weighted = WeightedGraph(Graph(edges: ReferenceGraphs.kiteEdges))
		for list in weighted.adjacency {
			for entry in list { #expect(entry.weight.isEqual(to: 1)) }
		}
	}

	@Test("Isolated vertices survive, in both directions")
	func isolatedPreserved() throws {
		let graph = Graph(adjacency: ["a": ["b"], "b": [], "z": []])
		let weighted = WeightedGraph(graph)
		#expect(weighted.nodes == ["a", "b", "z"])
		let z = try #require(weighted.indexOf["z"])
		#expect(weighted.neighbourCount(z) == 0)
		let back = Graph(weighted)
		#expect(back.nodes == ["a", "b", "z"])
		#expect(back.neighbors(of: "z").isEmpty)
	}

	@Test("Targets with no entry of their own become vertices")
	func unlistedTargets() {
		let graph = Graph(adjacency: ["a": ["b", "c"]])
		let weighted = WeightedGraph(graph)
		#expect(weighted.nodes == ["a", "b", "c"])
		#expect(weighted.edgeCount == 2)
	}

	@Test("A self-loop in a Graph is dropped by the bridge, as WeightedGraph drops all loops")
	func selfLoopDropped() {
		let weighted = WeightedGraph(Graph(adjacency: ["a": ["a", "b"]]))
		#expect(weighted.edgeCount == 1)
		#expect(weighted.totalWeight.isEqual(to: 1))
	}

	@Test("WeightedGraph to Graph gives both directions of every edge and drops the weights")
	func backToGraph() throws {
		let weighted = try WeightedGraph(edges: [("a", "b", 7.5), ("b", "c", 0.25)])
		let graph = Graph(weighted)
		#expect(graph.nodes == ["a", "b", "c"])
		#expect(graph.neighbors(of: "a") == ["b"])
		#expect(graph.neighbors(of: "b") == ["a", "c"])
		#expect(graph.neighbors(of: "c") == ["b"])
		#expect(graph.edgeCount == 4)
	}

	@Test("Zero-weight ties survive the trip to Graph, which has no weights to lose them in")
	func zeroWeightTieKept() throws {
		let weighted = try WeightedGraph(edges: [("a", "b", 0.0)])
		let graph = Graph(weighted)
		#expect(graph.neighbors(of: "a") == ["b"])
		#expect(graph.neighbors(of: "b") == ["a"])
	}

	@Test("Round trip on a symmetric graph returns the input")
	func roundTripSymmetric() {
		let symmetric = Graph(adjacency: [
			"a": ["b", "c"], "b": ["a"], "c": ["a", "d"], "d": ["c"], "e": [],
		])
		let back = Graph(WeightedGraph(symmetric))
		#expect(back.nodes == symmetric.nodes)
		#expect(back.adjacency == symmetric.adjacency)
	}

	@Test("Round trip on a directed graph returns its undirected closure")
	func roundTripDirectedGivesClosure() {
		let directed = Graph(edges: [("a", "b"), ("b", "c"), ("c", "d"), ("d", "b")])
		let back = Graph(WeightedGraph(directed))
		let expected = Graph(adjacency: [
			"a": ["b"], "b": ["a", "c", "d"], "c": ["b", "d"], "d": ["b", "c"],
		])
		#expect(back.adjacency == expected.adjacency)
		#expect(back.nodes == expected.nodes)
	}

	@Test("Round trip of the karate club is exact")
	func roundTripKarate() {
		var map: [Int: [Int]] = [:]
		for (from, to) in ReferenceGraphs.karateEdges {
			map[from, default: []].append(to)
			map[to, default: []].append(from)
		}
		let symmetric = Graph(adjacency: map)
		let weighted = WeightedGraph(symmetric)
		#expect(weighted.edgeCount == 78)
		let back = Graph(weighted)
		#expect(back.adjacency == symmetric.adjacency)
	}

	@Test("The bridge agrees with building the weighted graph directly")
	func agreesWithDirectConstruction() {
		let viaBridge = WeightedGraph(Graph(edges: ReferenceGraphs.kiteEdges))
		let direct = WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
		#expect(viaBridge.nodes == direct.nodes)
		#expect(viaBridge.edgeCount == direct.edgeCount)
		#expect(viaBridge.totalWeight.isEqual(to: direct.totalWeight))
		for index in viaBridge.adjacency.indices {
			#expect(viaBridge.adjacency[index].map(\.neighbour) == direct.adjacency[index].map(\.neighbour))
		}
	}
}
