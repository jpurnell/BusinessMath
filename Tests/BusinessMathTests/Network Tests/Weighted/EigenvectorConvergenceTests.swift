//
//  EigenvectorConvergenceTests.swift
//  BusinessMath
//

import Foundation
import Testing

import TestSupport
@testable import BusinessMath

/// The diagnostic must be the same iteration as `eigenvector`, not a lookalike: a convergence
/// figure measured on a different loop would say nothing about the one that ships.
@Suite("Eigenvector convergence diagnostic")
struct EigenvectorConvergenceTests {

	@Test("Its scores equal eigenvector's exactly, at every ceiling, across seeded random graphs",
		  arguments: [UInt64(1), 2, 3, 4, 5, 6, 7, 8, 9, 10])
	func agreesWithEigenvector(seed: UInt64) throws {
		let count = 20 + Int(seed) * 7
		let graphs = [
			try Synthetic.erdosRenyi(seed: seed, count: count, edgeCount: count * 2),
			try Synthetic.preferentialAttachment(seed: seed, count: count, perNode: 2),
			try Synthetic.communities(seed: seed, count: count, groups: 2, inside: count * 2, between: 3),
		]
		for graph in graphs {
			for ceiling in [0, 1, 2, 5, 17, 200, 2_000] {
				for tolerance in [1e-10, 1e-3] {
					let direct = Centrality.eigenvector(
						graph, maxIterations: ceiling, tolerance: tolerance)
					let diagnostic = Centrality.eigenvectorConvergence(
						graph, maxIterations: ceiling, tolerance: tolerance)
					#expect(direct.scores == diagnostic.scores.scores,
							"seed \(seed) ceiling \(ceiling) tolerance \(tolerance)")
				}
			}
		}
	}

	@Test("Does not claim convergence when the ceiling is too small, and does when it is large")
	func convergedFlag() throws {
		let ring = try Synthetic.ring(60)
		let tight = Centrality.eigenvectorConvergence(ring, maxIterations: 1)
		#expect(tight.converged == false)
		#expect(tight.iterations == 1)
		#expect(tight.residual >= 1e-10)

		let long = try Synthetic.path(80)
		let few = Centrality.eigenvectorConvergence(long, maxIterations: 5)
		#expect(few.converged == false)
		#expect(few.iterations == 5)

		let roomy = Centrality.eigenvectorConvergence(long, maxIterations: 100_000)
		#expect(roomy.converged)
		#expect(roomy.iterations > 5 && roomy.iterations < 100_000)
		#expect(roomy.residual < 1e-10)
	}

	@Test("A zero ceiling still runs one pass, as eigenvector does")
	func zeroCeilingIsOnePass() throws {
		let result = Centrality.eigenvectorConvergence(try Synthetic.path(10), maxIterations: 0)
		#expect(result.iterations == 1)
	}

	@Test("A looser tolerance never needs more passes, and an enormous one stops after the first")
	func toleranceControlsStopping() throws {
		let graph = try Synthetic.communities(seed: 3, count: 120, groups: 2, inside: 300, between: 2)
		let strict = Centrality.eigenvectorConvergence(graph, maxIterations: 100_000, tolerance: 1e-10)
		let loose = Centrality.eigenvectorConvergence(graph, maxIterations: 100_000, tolerance: 1e-4)
		#expect(strict.converged && loose.converged)
		#expect(loose.iterations < strict.iterations)
		let instant = Centrality.eigenvectorConvergence(graph, maxIterations: 100_000, tolerance: 1e9)
		#expect(instant.iterations == 1 && instant.converged)
	}

	@Test("Once converged the residual is the final change and sits under the tolerance")
	func residualMeaning() throws {
		let graph = try Synthetic.erdosRenyi(seed: 11, count: 200, edgeCount: 800)
		let result = Centrality.eigenvectorConvergence(graph, tolerance: 1e-6)
		#expect(result.converged)
		#expect(result.residual < 1e-6)
		#expect(result.residual >= 0)
		// One pass fewer is not yet converged: the previous change was at least the tolerance.
		let before = Centrality.eigenvectorConvergence(
			graph, maxIterations: result.iterations - 1, tolerance: 1e-6)
		#expect(before.converged == false)
		#expect(before.residual >= 1e-6)
	}

	@Test("Degenerate graphs have nothing to iterate: converged, zero residual")
	func degenerate() throws {
		let empty = Centrality.eigenvectorConvergence(try WeightedGraph<String>(edges: []))
		#expect(empty.converged && empty.residual == 0 && empty.iterations == 0)
		#expect(empty.scores.scores.isEmpty)
		let lone = Centrality.eigenvectorConvergence(
			try WeightedGraph<String>(edges: [], isolatedNodes: ["x"]))
		#expect(lone.converged && lone.residual == 0 && lone.iterations == 0)
		#expect(lone.scores.scores == ["x": 1])
		let edgeless = Centrality.eigenvectorConvergence(
			try WeightedGraph<String>(edges: [], isolatedNodes: ["x", "y", "z"]))
		#expect(edgeless.converged && edgeless.residual == 0)
		#expect(edgeless.scores.scores == ["x": 1, "y": 1, "z": 1])
	}
}
