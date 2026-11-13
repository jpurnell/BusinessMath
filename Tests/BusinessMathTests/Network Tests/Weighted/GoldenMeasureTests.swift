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
			if value != expectedValue {
				let got = value.split(separator: " ")
				let want = expectedValue.split(separator: " ")
				let first = zip(got, want).enumerated().first { $0.element.0 != $0.element.1 }?.offset
				Issue.record("\(name) / \(key): first differing token at \(String(describing: first)), got \(got.count) tokens, expected \(want.count)")
			}
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
