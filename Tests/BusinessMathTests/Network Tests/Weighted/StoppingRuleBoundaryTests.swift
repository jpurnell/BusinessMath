//
//  StoppingRuleBoundaryTests.swift
//  BusinessMath
//
//  Written red-first against two mutants that survived the mutation check of the port
//  (project/summaries/2026-11-12_network_weighted_measures/): the iteration stop test `delta < tolerance`
//  weakened to `<=` in the eigenvector and PageRank loops. The boundary only shows when the tolerance
//  equals a change the iteration actually produces, so the tolerance here is taken from the run itself.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Stopping rules are strict: a change exactly equal to the tolerance does not stop the iteration")
struct StoppingRuleBoundaryTests {

	private let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("c", "d"), ("b", "d")], isolatedNodes: ["e"])

	@Test("Eigenvector: with the tolerance set to the residual of a converged run, the run needs more passes")
	func eigenvectorStopIsStrict() {
		let first = Centrality.eigenvectorConvergence(graph, maxIterations: 200, tolerance: 1e-10)
		#expect(first.converged)
		#expect(first.residual > 0)
		let second = Centrality.eigenvectorConvergence(graph, maxIterations: 200, tolerance: first.residual)
		// The pass that produced `first.residual` is not strictly below it, so it cannot stop there.
		#expect(second.iterations > first.iterations)
		#expect(second.residual < first.residual)
	}

	@Test("PageRank: with the tolerance set to the change of pass k, the result is not the pass-k iterate")
	func pageRankStopIsStrict() throws {
		let pass = 6
		let previous = try Centrality.pageRank(graph, maxIterations: pass - 1, tolerance: 0)
		let atPass = try Centrality.pageRank(graph, maxIterations: pass, tolerance: 0)
		var delta = 0.0
		for node in graph.nodes {
			delta += abs((atPass.scores[node] ?? 0) - (previous.scores[node] ?? 0))
		}
		#expect(delta > 0)
		let stopped = try Centrality.pageRank(graph, maxIterations: 200, tolerance: delta)
		#expect(stopped != atPass)
	}
}
