//
//  EigenvectorDiagnosticsTests.swift
//  BusinessMath
//
//  Metric version 4: the registered eigenvector metric says whether it converged. Ported from
//  SwiftGraphMetrics. Synthetic graphs only.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

@Suite("Eigenvector metric reports convergence")
struct EigenvectorDiagnosticsTests {

	private func report(_ graph: WeightedGraph<String>, ceiling: Int = 200) throws -> ConvergenceReport {
		let output = try EigenvectorMetric<String>(maxIterations: ceiling).compute(on: graph)
		return try #require(output.convergence)
	}

	// MARK: converges at the default ceiling

	@Test("A star converges at the default ceiling")
	func starConverges() throws {
		let result = try report(try Synthetic.star(20))
		#expect(result.converged)
		#expect(result.residual < 1e-10)
		#expect(result.iterations >= 1)
		#expect(result.iterations <= 200)
	}

	@Test("Seeded Erdos-Renyi and preferential-attachment graphs converge",
		  arguments: [UInt64(1), 2, 3, 4, 5, 6])
	func wellMixedConverge(seed: UInt64) throws {
		let graphs = [
			try Synthetic.erdosRenyi(seed: seed, count: 300, edgeCount: 1_500),
			try Synthetic.preferentialAttachment(seed: seed, count: 300, perNode: 3),
		]
		for graph in graphs {
			let result = try report(graph)
			#expect(result.converged, "seed \(seed)")
			#expect(result.residual < 1e-10, "seed \(seed)")
			#expect(result.iterations < 200, "seed \(seed)")
		}
	}

	// MARK: does not converge at the default ceiling

	@Test("A long path hits the ceiling, with a residual far above the tolerance")
	func pathMisses() throws {
		let result = try report(try Synthetic.path(60))
		#expect(result.converged == false)
		#expect(result.iterations == 200)
		#expect(result.maxIterations == 200)
		#expect(result.residual > 1e-6)
	}

	@Test("Two dense clusters joined by one edge hit the ceiling",
		  arguments: [UInt64(1), 2, 3])
	func clustersMiss(seed: UInt64) throws {
		let graph = try Synthetic.communities(seed: seed, count: 200, groups: 2, inside: 700, between: 1)
		let result = try report(graph)
		#expect(result.converged == false, "seed \(seed)")
		#expect(result.iterations == 200, "seed \(seed)")
		#expect(result.residual > 1e-6, "seed \(seed)")
	}

	@Test("A large enough ceiling flips both to converged")
	func largeCeilingConverges() throws {
		let graphs = [
			try Synthetic.path(60),
			try Synthetic.communities(seed: 1, count: 200, groups: 2, inside: 700, between: 1),
		]
		for graph in graphs {
			let result = try report(graph, ceiling: 1_000_000)
			#expect(result.converged)
			#expect(result.residual < 1e-10)
			#expect(result.iterations > 200)
			#expect(result.maxIterations == 1_000_000)
		}
	}

	@Test("The tolerance is carried, and the ceiling is at least one pass")
	func parametersCarried() throws {
		let graph = try Synthetic.erdosRenyi(seed: 7, count: 100, edgeCount: 400)
		let output = try EigenvectorMetric<String>(maxIterations: 0, tolerance: 1e-3).compute(on: graph)
		let result = try #require(output.convergence)
		#expect(result.tolerance.isEqual(to: 1e-3))
		#expect(result.maxIterations == 1)
		#expect(result.iterations == 1)
	}

	@Test("The metric's defaults are 200 passes and a tolerance of 1e-10")
	func defaults() {
		let metric = EigenvectorMetric<String>()
		#expect(metric.maxIterations == 200)
		#expect(metric.tolerance.isEqual(to: 1e-10))
	}

	@Test("A graph with nothing to iterate reports converged, zero passes")
	func degenerate() throws {
		let output = try EigenvectorMetric<String>().compute(on: try WeightedGraph<String>(edges: []))
		let result = try #require(output.convergence)
		#expect(result.converged)
		#expect(result.iterations == 0)
		#expect(result.residual.isEqual(to: 0))
	}

	// MARK: the scores are untouched

	@Test("The scores are exactly Centrality.eigenvector's, at the default and at a raised ceiling",
		  arguments: [UInt64(1), 2, 3])
	func scoresUnchanged(seed: UInt64) throws {
		let graph = try Synthetic.communities(seed: seed, count: 120, groups: 2, inside: 400, between: 2)
		for ceiling in [200, 5_000] {
			let output = try EigenvectorMetric<String>(maxIterations: ceiling).compute(on: graph)
			#expect(output.scores == Centrality.eigenvector(graph, maxIterations: ceiling))
		}
		let defaults = try EigenvectorMetric<String>().compute(on: graph)
		#expect(defaults.scores == Centrality.eigenvector(graph))
	}

	// MARK: through the envelope

	@Test("Round-trips through the registry, an envelope and JSON, seeded",
		  arguments: [UInt64(1), 2, 3, 4])
	func envelopeRoundTrip(seed: UInt64) throws {
		let graph = try Synthetic.communities(seed: seed, count: 100, groups: 2, inside: 300, between: 1)
		let envelope = try #require(
			try MetricRegistry<String>.standard.run("eigenvector-centrality", on: graph))
		#expect(envelope.kind == "scores")
		let expected = Centrality.eigenvectorConvergence(graph)

		let data = try JSONEncoder().encode(envelope)
		let decoded = try JSONDecoder().decode(MetricEnvelope.self, from: data)
		#expect(decoded == envelope)

		let typed = try #require(try decoded.value(as: DiagnosedScores<String>.self))
		#expect(typed.scores == expected.scores)
		let found = try #require(typed.convergence)
		#expect(found.converged == expected.converged)
		#expect(found.iterations == expected.iterations)
		#expect(found.residual.isEqual(to: expected.residual))
		#expect(decoded.convergence == found)
	}

	@Test("A consumer that only knows NodeScores still reads a version 4 envelope")
	func plainReaderStillWorks() throws {
		let graph = try Synthetic.path(30)
		let envelope = try #require(
			try MetricRegistry<String>.standard.run("eigenvector-centrality", on: graph))
		let plain = try #require(try envelope.value(as: NodeScores<String>.self))
		#expect(plain == Centrality.eigenvector(graph))
	}

	@Test("A stored version 3 envelope decodes, and its convergence reads as unknown")
	func oldShapeDecodes() throws {
		let stored = #"{"kind":"scores","payload":{"scores":{"a":1,"b":0.5}}}"#
		let envelope = try JSONDecoder().decode(MetricEnvelope.self, from: Data(stored.utf8))
		#expect(envelope.convergence == nil)
		let typed = try #require(try envelope.value(as: DiagnosedScores<String>.self))
		#expect(typed.convergence == nil)
		#expect(typed.scores == NodeScores(["a": 1, "b": 0.5]))
		#expect(ConvergenceNote.sentence(envelope.convergence)
			== "Convergence was not recorded for this result.")
	}

	@Test("A whole stored version 3 record decodes")
	func oldRecordDecodes() throws {
		struct Context: Codable, Sendable, Hashable { let note: String }
		let stored = """
		{"metric":"eigenvector-centrality","metricVersion":3,"context":{"note":"old"},
		 "computedAt":0,"output":{"kind":"scores","payload":{"scores":{"a":1}}}}
		"""
		let record = try JSONDecoder().decode(MetricRecord<Context>.self, from: Data(stored.utf8))
		#expect(record.metricVersion == 3)
		#expect(record.output.convergence == nil)
	}

	@Test("Other kinds carry no convergence")
	func otherKinds() throws {
		let degree = try #require(
			try MetricRegistry<String>.standard.run("degree", on: try Synthetic.star(5)))
		#expect(degree.convergence == nil)
		let louvain = try #require(
			try MetricRegistry<String>.standard.run("louvain", on: try Synthetic.star(5)))
		#expect(louvain.convergence == nil)
	}

	@Test("Only a scores envelope is read for convergence, whatever another kind's payload holds")
	func otherKindWithLookalikeKey() throws {
		let payload = #"""
		{"convergence":{"iterations":3,"converged":true,"residual":0,"tolerance":1e-10,"maxIterations":200}}
		"""#
		let lookalike = MetricEnvelope(
			kind: "something-else",
			payload: try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8)))
		#expect(lookalike.convergence == nil)
		let real = MetricEnvelope(kind: "scores", payload: lookalike.payload)
		#expect(real.convergence?.iterations == 3)
	}

	// MARK: the sentence

	@Test("The sentence says which it was, with the numbers")
	func sentences() {
		let ok = ConvergenceReport(
			iterations: 151, converged: true, residual: 8.2e-11, tolerance: 1e-10, maxIterations: 200)
		#expect(ConvergenceNote.sentence(ok)
			== "Converged in 151 passes (final change 8.20E-11, tolerance 1.00E-10).")
		let one = ConvergenceReport(
			iterations: 1, converged: true, residual: 0, tolerance: 1e-10, maxIterations: 200)
		#expect(ConvergenceNote.sentence(one).hasPrefix("Converged in 1 pass ("))
		let miss = ConvergenceReport(
			iterations: 200, converged: false, residual: 4.7e-2, tolerance: 1e-10, maxIterations: 200)
		let expectedMiss = "Did not converge: stopped at the 200-pass ceiling with a final change of 4.70E-2 "
			+ "against a tolerance of 1.00E-10, so these scores may be far from the true "
			+ "eigenvector. Raise maxIterations to check."
		#expect(ConvergenceNote.sentence(miss) == expectedMiss)
		// The ceiling and the passes run are different numbers when a report says so.
		let early = ConvergenceReport(
			iterations: 150, converged: false, residual: 1e-3, tolerance: 1e-10, maxIterations: 200)
		#expect(ConvergenceNote.sentence(early).contains("the 200-pass ceiling"))
		let many = ConvergenceReport(
			iterations: 3, converged: true, residual: 1e-11, tolerance: 1e-10, maxIterations: 200)
		#expect(ConvergenceNote.sentence(many).hasPrefix("Converged in 3 passes ("))
		#expect(ConvergenceNote.sentence(nil) == "Convergence was not recorded for this result.")
	}
}
