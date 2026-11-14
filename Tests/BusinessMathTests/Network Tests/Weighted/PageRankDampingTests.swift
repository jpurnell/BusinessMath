//
//  PageRankDampingTests.swift
//  BusinessMath
//
//  Step 4, change 2 of NetworkWeightedGraph.md (ADR-009): a damping outside [0, 1) is refused,
//  where it used to be clamped into [0, 0.999] (and NaN passed through and poisoned every score).
//  Each rejected value is named, the old behaviour is shown to be gone, and the accepted range's
//  edges are pinned from both sides.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private func bits(_ scores: NodeScores<String>) -> [String: UInt64] {
	scores.scores.mapValues { $0.bitPattern }
}

/// The damping a refusal carries, or `nil` if the call did not throw `invalidDamping`.
private func refusedDamping(_ body: () throws -> Void) -> Double? {
	do {
		try body()
		return nil
	} catch GraphMeasureError.invalidDamping(let value) {
		return value
	} catch {
		return nil
	}
}

private let refusedDampings: [Double] = [
	Double.nan, Double.infinity, -Double.infinity, 1.0, 1.0000001, 2.5, 1e300,
	-0.3, -1, -Double.leastNonzeroMagnitude,
]

private let sample = WeightedGraph(
	unweightedEdges: [("a", "b"), ("b", "c"), ("c", "d")], isolatedNodes: ["x"])

@Suite("PageRank damping validation")
struct PageRankDampingTests {

	@Test("A NaN, infinite, negative or at-least-one damping is refused by pageRank, and the error carries the value",
		  arguments: refusedDampings)
	func pageRankRefuses(damping: Double) {
		let carried = refusedDamping { _ = try Centrality.pageRank(sample, damping: damping) }
		#expect(carried != nil, "damping \(damping)")
		if damping.isNaN {
			#expect(carried?.isNaN == true)
		} else {
			#expect(carried?.isEqual(to: damping) == true, "damping \(damping)")
		}
	}

	@Test("pageRankConvergence refuses the same dampings: it is the loop, so the two cannot disagree",
		  arguments: refusedDampings)
	func convergenceRefuses(damping: Double) {
		let carried = refusedDamping { _ = try Centrality.pageRankConvergence(sample, damping: damping) }
		#expect(carried != nil, "damping \(damping)")
	}

	@Test("Old behaviour is gone: 1.5 no longer runs as 0.999, -1 no longer runs as 0, NaN no longer gives NaN scores")
	func clampAndNaNPassThroughAreGone() throws {
		let atCap = try Centrality.pageRank(sample, damping: 0.999)
		let atZero = try Centrality.pageRank(sample, damping: 0)
		#expect(refusedDamping { _ = try Centrality.pageRank(sample, damping: 1.5) } != nil)
		#expect(refusedDamping { _ = try Centrality.pageRank(sample, damping: -1) } != nil)
		#expect(refusedDamping { _ = try Centrality.pageRank(sample, damping: Double.nan) } != nil)
		// And the values they used to be treated as are still themselves legal.
		#expect(atCap.scores.values.allSatisfy { $0.isFinite })
		#expect(atZero.scores.values.allSatisfy { abs($0 - 0.2) < 1e-12 })
	}

	@Test("The edges of the accepted range are accepted: 0, -0, 0.999, and the largest double below one")
	func acceptedEdges() throws {
		for damping in [0.0, -0.0, 0.5, 0.999, 1.0.nextDown] {
			let scores = try Centrality.pageRank(sample, damping: damping)
			let total: Double = scores.scores.values.reduce(0, +)
			#expect(scores.scores.values.allSatisfy { $0.isFinite }, "damping \(damping)")
			#expect(abs(total - 1) < 1e-9, "damping \(damping)")
		}
	}

	@Test("Zero damping is teleport only: every node scores 1/n")
	func zeroDampingIsUniform() throws {
		let scores = try Centrality.pageRank(sample, damping: 0)
		for score in scores.scores.values { #expect(abs(score - 0.2) < 1e-12) }
	}

	@Test("Damping just above the old cap is run as given, not as 0.999")
	func aboveTheOldCapIsNotClamped() throws {
		let capped = try Centrality.pageRank(sample, damping: 0.999, maxIterations: 40, tolerance: 0)
		let above = try Centrality.pageRank(sample, damping: 0.9995, maxIterations: 40, tolerance: 0)
		#expect(bits(capped) != bits(above))
	}

	@Test("The refusal does not depend on the graph, the ceiling or the tolerance: an empty graph refuses too")
	func refusalIsInputOnly() throws {
		let empty = try WeightedGraph<String>(edges: [])
		#expect(refusedDamping { _ = try Centrality.pageRank(empty, damping: Double.nan) } != nil)
		#expect(refusedDamping { _ = try Centrality.pageRankConvergence(empty, damping: 1) } != nil)
		#expect(refusedDamping { _ = try Centrality.pageRank(sample, damping: 2, maxIterations: 0, tolerance: 0) } != nil)
		// A valid damping on an empty graph still gives an empty answer.
		#expect(try Centrality.pageRank(empty).scores.isEmpty)
	}

	@Test("Accepted dampings give finite scores summing to one on every family: NaN can no longer come out")
	func neverNaN() throws {
		let graphs = [
			try Synthetic.path(30), try Synthetic.star(30),
			try Synthetic.erdosRenyi(seed: 9, count: 40, edgeCount: 20),
		]
		for graph in graphs {
			for damping in [0.0, 0.1, 0.5, 0.85, 0.99, 0.999, 0.9999] {
				let scores = try Centrality.pageRank(graph, damping: damping)
				let total: Double = scores.scores.values.reduce(0, +)
				#expect(scores.scores.values.allSatisfy { $0.isFinite && $0 >= 0 }, "damping \(damping)")
				#expect(abs(total - 1) < 1e-9, "damping \(damping)")
			}
		}
	}

	@Test("The error compares equal to itself for NaN, and unequal across different values")
	func errorEquality() {
		#expect(GraphMeasureError.invalidDamping(Double.nan) == GraphMeasureError.invalidDamping(Double.nan))
		#expect(GraphMeasureError.invalidDamping(1.5) == GraphMeasureError.invalidDamping(1.5))
		#expect(GraphMeasureError.invalidDamping(1.5) != GraphMeasureError.invalidDamping(2.5))
		#expect(GraphMeasureError.invalidDamping(Double.nan) != GraphMeasureError.invalidDamping(1.5))
	}

	@Test("The registered metric refuses an invalid damping when it runs, through the registry and as a record")
	func metricRefuses() {
		for damping in [Double.nan, 1.0, 1.5, -0.1] {
			let metric = PageRankMetric<String>(damping: damping)
			#expect(refusedDamping { _ = try metric.compute(on: sample) } != nil, "damping \(damping)")
			let registry = MetricRegistry([AnyGraphMetric(metric)])
			#expect(refusedDamping { _ = try registry.run("pagerank", on: sample) } != nil, "damping \(damping)")
			#expect(refusedDamping {
				_ = try registry.record("pagerank", on: sample, context: "c", now: Date(timeIntervalSince1970: 0))
			} != nil, "damping \(damping)")
		}
	}

	@Test("The default metric is unaffected: it still runs and still converges")
	func defaultMetricStillRuns() throws {
		let result = try PageRankMetric<String>().compute(on: sample)
		#expect(result.convergence?.converged == true)
	}
}
