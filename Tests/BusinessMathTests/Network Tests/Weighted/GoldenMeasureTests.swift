//
//  GoldenMeasureTests.swift
//  BusinessMath
//
//  Bit-for-bit golden test. `GoldenMeasureData` was computed with SwiftGraphMetrics's own
//  measures (a scratch program depending on the package by path) on fixed graphs: every
//  centrality, community and brokerage output, to the last bit, including the
//  eigenvector iteration count, convergence flag and residual, and the Louvain, k-core and
//  component partitions. The ported code must reproduce every token. A failure here means a
//  stored metric record (eigenvector-centrality v4, pagerank v2, and the rest) has changed
//  meaning: fix the code, never the constant.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Golden measures: bit-for-bit against SwiftGraphMetrics")
struct GoldenMeasureTests {

	@Test("Every measure on every fixture reproduces SwiftGraphMetrics exactly",
		  arguments: GoldenMeasureData.cases.map(\.name))
	func reproducesSGM(_ name: String) throws {
		let golden = try #require(GoldenMeasureData.cases.first { $0.name == name })
		let graph = try WeightedGraph(edges: golden.edges, isolatedNodes: golden.isolated)
		let actual = goldenMeasures(graph)
		#expect(actual.count == golden.expected.count)
		for ((key, value), (expectedKey, expectedValue)) in zip(actual, golden.expected) {
			#expect(key == expectedKey)
			if Self.eigenvectorKeys.contains(key) {
				// ADR-009: refused exactly when the graph is not connected through positive-weight ties.
				let refused = Self.positiveTieComponents(graph) > 1
				#expect(value == (refused ? "refused" : expectedValue), "\(name) / \(key)")
			} else if key == "modularity.partial" {
				// ADR-009: every second node is left out, so the partition is partial unless the graph has
				// at most one node. The stored token is what the old code returned for that partial partition.
				let partial = graph.nodeCount > 1
				#expect(value == (partial ? "refused" : expectedValue), "\(name) / \(key)")
			} else if let changed = Self.intentionallyChanged(key) {
				// ADR-009: the old output is kept in the data; the new outcome is asserted here.
				#expect(value == "refused", "\(name) / \(key)")
				#expect(expectedValue == changed(graph), "\(name) / \(key): the stored output was the clamped run")
			} else if value != expectedValue {
				let got = value.split(separator: " ")
				let want = expectedValue.split(separator: " ")
				let first = zip(got, want).enumerated().first { $0.element.0 != $0.element.1 }?.offset
				Issue.record("\(name) / \(key): first differing token at \(String(describing: first)), got \(got.count) tokens, expected \(want.count)")
			}
		}
	}

	static let eigenvectorKeys: Set<String> = [
		"eigenvector", "eigenvectorConvergence.report", "eigenvectorConvergence.scores",
		"eigenvectorCeiling5.report", "eigenvectorCeiling5.scores",
		"eigenvectorTol1e-3.report", "eigenvectorTol1e-3.scores", "eigenvectorZeroCeiling",
	]

	/// Connected components through ties of positive weight, by union-find: written here so the
	/// expectation does not come from the library code it checks. A graph of fewer than two nodes has one.
	static func positiveTieComponents(_ graph: WeightedGraph<String>) -> Int {
		var parent = Array(0..<graph.nodeCount)
		func root(_ index: Int) -> Int {
			var current = index
			while parent[current] != current { current = parent[current] }
			return current
		}
		for (node, ties) in graph.adjacency.enumerated() {
			for (other, weight) in ties where weight > 0 {
				parent[root(node)] = root(other)
			}
		}
		return Set((0..<graph.nodeCount).map(root)).count
	}

	/// For a key whose behaviour step 4 changed on purpose: how to recompute what the old code
	/// returned for it, so the stored token is shown to have been exactly that old behaviour.
	static func intentionallyChanged(_ key: String) -> ((WeightedGraph<String>) -> String)? {
		switch key {
		case "pageRank.damping1.5":
			// 1.5 ran as the cap, 0.999.
			return { graph in goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, damping: 0.999) } }
		case "pageRank.damping-1.0":
			// -1 ran as 0.
			return { graph in goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, damping: 0) } }
		default:
			return nil
		}
	}

	@Test("The fixture set covers the cases the plan names")
	func fixtureCoverage() {
		let names = Set(GoldenMeasureData.cases.map(\.name))
		for required in ["path7", "star7", "triangle", "kite", "karate", "weighted12", "twoComponents",
						 "isolates", "random1", "random2", "random3", "zeroWeights", "ringOfCliques"] {
			#expect(names.contains(required))
		}
	}
}
