//
//  WeightedGraphTests.swift
//  BusinessMath
//
//  The weighted graph's structural behaviours, ported from SwiftGraphMetrics.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

@Suite("WeightedGraph")
struct WeightedGraphTests {

	@Test("Nodes come out in sorted order regardless of input order")
	func sortedNodes() throws {
		let graph = try WeightedGraph(edges: [("c", "a", 1), ("b", "c", 1)])
		#expect(graph.nodes == ["a", "b", "c"])
		#expect(graph.indexOf["b"] == 1)
	}

	@Test("Duplicate pairs merge by summing, in either direction")
	func mergesDuplicates() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1.5), ("b", "a", 2.5)])
		#expect(graph.edgeCount == 1)
		#expect(graph.totalWeight.isEqual(to: 4))
		#expect(graph.degree(of: "a")?.isEqual(to: 4) == true)
	}

	@Test("Self-loops are dropped but the node survives")
	func dropsSelfLoops() throws {
		let graph = try WeightedGraph(edges: [("a", "a", 5), ("a", "b", 1)])
		#expect(graph.edgeCount == 1)
		#expect(graph.totalWeight.isEqual(to: 1))
		let lonely = try WeightedGraph(edges: [("z", "z", 3)])
		#expect(lonely.nodes == ["z"])
		#expect(lonely.edgeCount == 0)
	}

	@Test("Isolated nodes are kept and have zero degree")
	func isolatedNodes() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1)], isolatedNodes: ["x"])
		#expect(graph.nodeCount == 3)
		#expect(graph.degree(of: "x")?.isEqual(to: 0) == true)
		let position = try #require(graph.indexOf["x"])
		#expect(graph.neighbourCount(position) == 0)
		#expect(graph.degree(of: "missing") == nil)
	}

	@Test("An empty graph is valid")
	func empty() throws {
		let graph = try WeightedGraph<String>(edges: [])
		#expect(graph.nodeCount == 0)
		#expect(graph.edgeCount == 0)
		#expect(graph.totalWeight.isEqual(to: 0))
		#expect(graph.adjacency.isEmpty)
	}

	@Test("Any Comparable node type works, not only strings")
	func integerNodes() {
		let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
		#expect(graph.nodeCount == 34)
		#expect(graph.edgeCount == 78)
		#expect(graph.nodes.first == 1)
		#expect(graph.degree(of: 34)?.isEqual(to: 17) == true)
		// Integer ordering, not string ordering: 2 sorts before 10.
		#expect(graph.indexOf[2] == 1)
		#expect(graph.indexOf[10] == 9)
	}

	@Test("Adjacency lists are sorted by neighbour index")
	func adjacencySorted() {
		let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
		for list in graph.adjacency {
			#expect(list.map(\.neighbour) == list.map(\.neighbour).sorted())
		}
	}

	@Test("Kite graph: eighteen ties between ten people, each weighing one")
	func kiteShape() {
		let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
		#expect(graph.nodeCount == 10)
		#expect(graph.edgeCount == 18)
		#expect(graph.totalWeight.isEqual(to: 18))
		#expect(graph.degree(of: "Diane")?.isEqual(to: 6) == true)
		#expect(graph.degree(of: "Jane")?.isEqual(to: 1) == true)
	}

	@Test("Weighted degree by index equals degree by name")
	func weightedDegreeByIndex() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 2.5), ("b", "c", 0.5), ("a", "c", 1)])
		let b = try #require(graph.indexOf["b"])
		#expect(graph.weightedDegree(b).isEqual(to: 3))
		#expect(graph.degree(of: "b")?.isEqual(to: 3) == true)
	}
}
