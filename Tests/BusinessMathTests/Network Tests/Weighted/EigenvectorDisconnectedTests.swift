//
//  EigenvectorDisconnectedTests.swift
//  BusinessMath
//
//  Step 4, change 5 of NetworkWeightedGraph.md (ADR-009): eigenvector centrality refuses a graph
//  that is not connected, as the unweighted `Graph.eigenvectorCentrality` always has. It used to
//  run anyway: the leading eigenvector lives on the component with the largest eigenvalue and every
//  other node decayed toward zero, which reads as "unimportant" rather than "not comparable".
//  Connectivity is judged by ties of positive weight, because a zero-weight tie carries nothing
//  through the iteration.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private func componentsRefused(_ body: () throws -> Void) -> Int? {
	do {
		try body()
		return nil
	} catch GraphMeasureError.disconnectedGraph(let components) {
		return components
	} catch {
		return nil
	}
}

@Suite("Eigenvector centrality refuses a disconnected graph")
struct EigenvectorDisconnectedTests {

	static let disconnected: [(String, WeightedGraph<String>, Int)] = [
		("two triangles", WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("a", "c"), ("x", "y"), ("y", "z"), ("x", "z")]), 2),
		("path and triangle", WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("x", "y"), ("y", "z"), ("x", "z")]), 2),
		("path with three isolates", WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")], isolatedNodes: ["x", "y", "z"]), 4),
		("two isolated nodes", WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["p", "q"]), 2),
		("edgeless four", WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["a", "b", "c", "d"]), 4),
	]

	@Test("Each disconnected graph is refused by eigenvector and by the convergence form, naming the component count")
	func refused() {
		for (name, graph, components) in Self.disconnected {
			#expect(componentsRefused { _ = try Centrality.eigenvector(graph) } == components, "\(name)")
			#expect(componentsRefused { _ = try Centrality.eigenvectorConvergence(graph) } == components, "\(name)")
		}
	}

	@Test("A zero-weight tie does not connect: it carries nothing through the iteration")
	func zeroWeightBridgeDoesNotConnect() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1), ("b", "c", 1), ("c", "d", 0), ("d", "e", 1), ("e", "f", 1)])
		#expect(componentsRefused { _ = try Centrality.eigenvector(graph) } == 2)
		let allZero = try WeightedGraph(edges: [("a", "b", 0), ("b", "c", 0)])
		#expect(componentsRefused { _ = try Centrality.eigenvector(allZero) } == 3)
	}

	@Test("Connected graphs are untouched, including bipartite ones, and a lone node and the empty graph")
	func connectedStillScores() throws {
		let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		let scores = try Centrality.eigenvector(path)
		let middle = try #require(scores["b"])
		let end = try #require(scores["a"])
		#expect(abs(middle - 1) < 1e-9)
		#expect(abs(end - 0.7071067811865476) < 1e-9)
		let weighted = try WeightedGraph(edges: [("a", "b", 0.02), ("b", "c", 0.5)])
		#expect(try Centrality.eigenvector(weighted).scores.count == 3)
		let lone = try Centrality.eigenvector(WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["x"]))
		let loneScore = try #require(lone["x"])
		#expect(abs(loneScore - 1) < 1e-12)
		#expect(try Centrality.eigenvector(WeightedGraph<String>(edges: [])).scores.isEmpty)
	}

	@Test("Old behaviour is gone: the near-zero scores for the non-dominant component can no longer be obtained")
	func oldNearZeroScoresGone() {
		let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")], isolatedNodes: ["x", "y", "z"])
		#expect(componentsRefused { _ = try Centrality.eigenvector(graph) } == 4)
	}

	@Test("The registered metric is version 5, refuses a disconnected graph through compute, run and record, and still scores a connected one")
	func metric() throws {
		#expect(EigenvectorMetric<String>.descriptor.version == 5)
		let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")], isolatedNodes: ["x"])
		let metric = EigenvectorMetric<String>()
		#expect(componentsRefused { _ = try metric.compute(on: graph) } == 2)
		#expect(componentsRefused { _ = try MetricRegistry<String>.standard.run("eigenvector-centrality", on: graph) } == 2)
		#expect(componentsRefused {
			_ = try MetricRegistry<String>.standard.record("eigenvector-centrality", on: graph, context: "c", now: Date(timeIntervalSince1970: 0))
		} == 2)
		let connected = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		let result = try metric.compute(on: connected)
		#expect(result.convergence?.converged == true)
	}

	@Test("Records stored as version 4 (which may be of a disconnected graph) still decode")
	func version4StillDecodes() throws {
		let stored = #"{"computedAt":0,"context":"c","metric":"eigenvector-centrality","metricVersion":4,"output":{"kind":"scores","payload":{"convergence":{"converged":true,"iterations":9,"maxIterations":200,"residual":1e-11,"tolerance":1e-10},"scores":{"a":1,"x":0}}}}"#
		let record = try JSONDecoder().decode(MetricRecord<String>.self, from: Data(stored.utf8))
		#expect(record.metricVersion == 4)
		#expect(record.output.convergence?.iterations == 9)
	}

	@Test("The error compares by component count")
	func errorEquality() {
		#expect(GraphMeasureError.disconnectedGraph(components: 2) == GraphMeasureError.disconnectedGraph(components: 2))
		#expect(GraphMeasureError.disconnectedGraph(components: 2) != GraphMeasureError.disconnectedGraph(components: 3))
	}
}
