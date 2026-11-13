//
//  WeightValidationTests.swift
//  BusinessMath
//
//  Weight validation at the WeightedGraph boundary, ported from SwiftGraphMetrics. The
//  consumer-side suites (metrics, diffusion, siting) arrive with those types in later steps.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private let hostileWeights: [Double] = [
	.nan, .infinity, -.infinity, -1, -1e-300, -Double.greatestFiniteMagnitude,
]

@Suite("WeightedGraph: weights are validated where the graph is built")
struct WeightValidationTests {

	@Test("A NaN, infinite or negative weight is refused, naming the edge", arguments: hostileWeights)
	func refusesHostileWeight(weight: Double) {
		do {
			_ = try WeightedGraph(edges: [("a", "b", 1.0), ("b", "c", weight)])
			Issue.record("a weight of \(weight) was accepted")
		} catch let GraphError.invalidWeight(from, to, reported) {
			#expect(from == "b" && to == "c", "named the wrong edge: \(from)-\(to)")
			#expect(reported.bitPattern == weight.bitPattern)
		} catch {
			Issue.record("wrong error for \(weight): \(error)")
		}
	}

	@Test("The weight of a self-loop is checked even though the loop is then dropped", arguments: hostileWeights)
	func refusesHostileSelfLoop(weight: Double) {
		#expect(throws: GraphError.self) {
			_ = try WeightedGraph(edges: [("a", "a", weight), ("a", "b", 1)])
		}
	}

	@Test("Zero and negative zero are legal weights: a recorded tie with no strength")
	func zeroIsLegal() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 0.0), ("b", "c", -0.0)])
		#expect(graph.edgeCount == 2)
		#expect(graph.totalWeight.isEqual(to: 0))
		#expect(graph.degree(of: "b")?.isEqual(to: 0) == true)
	}

	@Test("Finite weights that sum past the largest finite number are refused, however they meet")
	func refusesOverflowingSums() {
		let big = Double.greatestFiniteMagnitude
		// Duplicates merged.
		#expect(throws: GraphError.weightSumOverflow) {
			_ = try WeightedGraph(edges: [("a", "b", big), ("b", "a", big)])
		}
		// One node's weighted degree.
		#expect(throws: GraphError.weightSumOverflow) {
			_ = try WeightedGraph(edges: [("hub", "x", big), ("hub", "y", big)])
		}
		// The graph's total weight, with no node's degree overflowing.
		#expect(throws: GraphError.weightSumOverflow) {
			_ = try WeightedGraph(edges: [("a", "b", big), ("c", "d", big), ("e", "f", big)])
		}
	}

	@Test("Hostile weights are refused wherever they sit in a seeded random edge list")
	func refusesWhereverItSits() {
		var rng = DeterministicGenerator(seed: 77)
		for trial in 0..<60 {
			var edges: [(Int, Int, Double)] = []
			for _ in 0..<12 {
				let from = rng.nextInt(in: 0..<8)
				let to = rng.nextInt(in: 0..<8)
				edges.append((from, to, rng.nextDouble(in: 0.0...5.0)))
			}
			let position = rng.nextInt(in: 0..<edges.count)
			edges[position].2 = hostileWeights[trial % hostileWeights.count]
			#expect(throws: GraphError.self, "trial \(trial)") { _ = try WeightedGraph(edges: edges) }
		}
	}

	@Test("A graph built from valid weights is unchanged by validating them")
	func validGraphUnchanged() throws {
		let graph = try WeightedGraph(edges: [("a", "b", 1.5), ("b", "a", 2.5), ("b", "c", 0.25)])
		#expect(graph.totalWeight.isEqual(to: 4.25))
		#expect(graph.degree(of: "b")?.isEqual(to: 4.25) == true)
		#expect(graph.edgeCount == 2)
	}

	@Test("Unweighted construction cannot throw and weighs every edge one")
	func unweighted() {
		let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
		#expect(graph.totalWeight.isEqual(to: 2))
	}

	@Test("The smallest positive weight is accepted, and a half-range weight is accepted")
	func boundaryWeightsAccepted() throws {
		let tiny = try WeightedGraph(edges: [("a", "b", Double.leastNonzeroMagnitude)])
		#expect(tiny.edgeCount == 1)
		let half = Double.greatestFiniteMagnitude / 2
		let large = try WeightedGraph(edges: [("a", "b", half)])
		#expect(large.totalWeight.isEqual(to: half))
	}

	@Test("A single edge of the largest finite weight is refused: the total is accumulated from both ends before halving")
	func largestSingleWeightRefused() {
		// Carried over from SwiftGraphMetrics unchanged. It refuses a graph that is
		// representable, which fails closed rather than returning a wrong number; pinned so
		// that any change to it is deliberate.
		#expect(throws: GraphError.weightSumOverflow) {
			_ = try WeightedGraph(edges: [("a", "b", Double.greatestFiniteMagnitude)])
		}
	}
}
