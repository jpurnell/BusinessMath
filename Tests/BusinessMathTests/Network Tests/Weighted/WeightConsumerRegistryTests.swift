//
//  WeightConsumerRegistryTests.swift
//  BusinessMath
//
//  What the registered metrics and siting from degree scores do with the weights that remain legal
//  (zero, tiny, huge). The registry half of SwiftGraphMetrics's WeightConsumerTests, which waited for
//  the registry.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Weight consumers: the standard metrics and centrality-weighted siting")
struct WeightConsumerRegistryTests {

	/// A ring with a chord, so every node has two or three ties, in the given weight pattern.
	private func graph(weights: [Double]) throws -> WeightedGraph<String> {
		let pairs = [("n0", "n1"), ("n1", "n2"), ("n2", "n3"), ("n3", "n4"), ("n4", "n0"), ("n0", "n2")]
		var edges: [(String, String, Double)] = []
		for (offset, pair) in pairs.enumerated() {
			edges.append((pair.0, pair.1, weights[offset % weights.count]))
		}
		return try WeightedGraph(edges: edges, isolatedNodes: ["lonely"])
	}

	static let patterns: [[Double]] = [
		[0], [1e-300], [1e300], [1], [0, 1], [1e-300, 1e300], [1, 0, 1e-300, 1e300, 1, 0],
	]

	@Test("Every standard metric returns finite scores", arguments: patterns)
	func standardMetricsFinite(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		let registry = MetricRegistry<String>.standard
		#expect(registry.available.count >= 10)
		for descriptor in registry.available {
			if descriptor.identifier == "eigenvector-centrality" {
				// The graph carries an isolated node, so it is not connected: refused since ADR-009.
				#expect(throws: GraphMeasureError.self) { _ = try registry.run(descriptor.identifier, on: graph) }
				continue
			}
			let envelope = try #require(try registry.run(descriptor.identifier, on: graph))
			if let scores = try envelope.value(as: NodeScores<String>.self) {
				#expect(scores.scores.values.allSatisfy { $0.isFinite }, "\(descriptor.identifier) on \(weights)")
			}
		}
		let burt = Brokerage.constraint(graph)
		#expect(burt.scores.values.allSatisfy { $0.isFinite && $0 >= 0 }, "burt on \(weights)")
	}

	@Test("Siting on centrality-weighted demand stays finite", arguments: patterns)
	func sitingFromCentrality(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		// Demand weights must have a positive total; degree centrality of a graph whose every
		// tie is zero is all zeros, so give the problem a unit floor like a real caller would.
		let degree = Centrality.degree(graph)
		let demand = NodeScores(degree.scores.mapValues { $0.isFinite ? $0 + 1 : 1 })
		let problem = try SiteProblem(
			demand: demand, sites: ["n0", "n2"], cost: { demand, site in demand == site ? 0 : 1 })
		let assignment = try PMedian().select(problem, count: 1)
		#expect(assignment.meanWeightedCost.isFinite)
		#expect(assignment.meanWeightedCost >= 0)
		#expect(assignment.meanWeightedCost <= 1)
	}
}
