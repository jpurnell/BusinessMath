//
//  BurtConstraintMetricTests.swift
//  BusinessMath
//
//  The registry, descriptor and envelope parts of SwiftGraphMetrics's BurtConstraintTests, which
//  waited for the registry. Synthetic and published reference graphs only.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private var kite: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
}

@Suite("Burt constraint: the registered metric")
struct BurtConstraintMetricTests {

	@Test("Round-trips through the registry as a scores envelope")
	func registryRoundTrip() throws {
		let registry = MetricRegistry<String>([]).registering(BurtConstraint<String>())
		let descriptor = try #require(registry.available.first)
		#expect(descriptor.identifier == "burt-constraint")
		#expect(descriptor.version == 1)
		let envelope = try #require(try registry.run("burt-constraint", on: kite))
		#expect(envelope.kind == "scores")
		let decoded = try #require(try envelope.value(as: NodeScores<String>.self))
		#expect(decoded == Brokerage.constraint(kite))
	}

	@Test("Descriptor says what low and high do and do not mean")
	func descriptorHonest() {
		let descriptor = BurtConstraint<String>.descriptor
		#expect(descriptor.lowMeans.contains("not"))
		#expect(descriptor.highMeans.contains("not"))
		#expect(descriptor.interpretation.contains("influence"))
		for text in [descriptor.interpretation, descriptor.highMeans, descriptor.lowMeans] {
			#expect(!text.contains("classmate"))
		}
	}

	@Test("The instance descriptor is the static one")
	func instanceDescriptor() {
		#expect(BurtConstraint<String>().descriptor == BurtConstraint<String>.descriptor)
	}

	@Test("Computing the metric is computing the brokerage measure, and the hand-derived path values hold")
	func computeMatchesMeasure() throws {
		let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		let scores = try BurtConstraint<String>().compute(on: path)
		#expect(scores == Brokerage.constraint(path))
		#expect(scores["b"]?.isEqual(to: 0.5) == true)
		#expect(scores["a"]?.isEqual(to: 1) == true)
	}

	@Test("Scores round-trip through the registry envelope on integer nodes, as JSON")
	func integerNodeRoundTrip() throws {
		let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
		let scores = try BurtConstraint<Int>().compute(on: graph)
		let envelope = try MetricEnvelope(scores)
		let wire = try JSONDecoder().decode(MetricEnvelope.self, from: try JSONEncoder().encode(envelope))
		#expect(try wire.value(as: NodeScores<Int>.self) == scores)
		#expect(scores == Brokerage.constraint(graph))
	}

	@Test("An isolate is omitted from the registered metric's scores, as from the measure")
	func isolatesOmitted() throws {
		let graph = WeightedGraph(unweightedEdges: [("a", "b")], isolatedNodes: ["x"])
		let scores = try BurtConstraint<String>().compute(on: graph)
		#expect(scores["x"] == nil)
		#expect(scores.scores.count == 2)
	}
}
