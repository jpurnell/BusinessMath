//
//  PageRankConvergenceTests.swift
//  BusinessMath
//
//  Step 4, change 1 of NetworkWeightedGraph.md (ADR-009): PageRank reports how its iteration
//  ended. The oracle is not the loop's own later iterates but two independent things: a dense
//  linear solve of the fixed point (TestSupport/DensePageRank.swift) and the a-priori bound the
//  proposal derived and the measurement confirmed, that after k passes the L1 error is at most
//  2 * damping^k. The measurement is
//  project/summaries/2026-11-13_network_explicit_behaviours/pagerank-measurement.md.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

// MARK: - Helpers

private func bits(_ scores: NodeScores<String>) -> [String: UInt64] {
	scores.scores.mapValues { $0.bitPattern }
}

/// The L1 distance between a graph's scores and a reference vector in `graph.nodes` order.
private func l1Error(_ scores: NodeScores<String>, _ reference: [Double], _ graph: WeightedGraph<String>) -> Double {
	var total = 0.0
	for (index, node) in graph.nodes.enumerated() {
		let found: Double = scores.scores[node] ?? Double.nan
		total += abs(found - reference[index])
	}
	return total
}

/// The ceiling the a-priori bound `2 * damping^k <= tolerance` gives: `ceil(ln(tol/2) / ln d)`.
private func predictedPasses(damping: Double, tolerance: Double) -> Int {
	let ratio: Double = log(tolerance / 2) / log(damping)
	return Int(ratio.rounded(.up))
}

/// A frozen copy of the loop as it stood before this change (ported unchanged from
/// SwiftGraphMetrics in step 2), kept here as an oracle so that "returns identical numbers" is
/// compared against the old code and not against the new code's own claim. Damping is used as
/// given: every damping this suite passes lies in `[0, 0.999]`, where the old clamp was a no-op.
private func legacyPageRank(
	_ graph: WeightedGraph<String>, damping: Double, maxIterations: Int, tolerance: Double
) -> NodeScores<String> {
	let count = graph.nodeCount
	guard count > 0 else { return NodeScores([:]) }
	let teleport = (1 - damping) / Double(count)
	var current = [Double](repeating: 1 / Double(count), count: count)
	let degrees = (0..<count).map { graph.weightedDegree($0) }
	for _ in 0..<max(1, maxIterations) {
		var next = [Double](repeating: teleport, count: count)
		var danglingMass = 0.0
		for index in 0..<count where degrees[index] <= 0 { danglingMass += current[index] }
		let spread = damping * danglingMass / Double(count)
		for index in 0..<count { next[index] += spread }
		for index in 0..<count {
			let degree = degrees[index]
			guard degree > 0 else { continue }
			let share = damping * current[index] / degree
			for (neighbour, weight) in graph.adjacency[index] { next[neighbour] += share * weight }
		}
		var delta = 0.0
		for index in 0..<count { delta += abs(next[index] - current[index]) }
		current = next
		if delta < tolerance { break }
	}
	var scores: [String: Double] = [:]
	for (index, node) in graph.nodes.enumerated() { scores[node] = current[index] }
	return NodeScores(scores)
}

private func families() throws -> [(name: String, graph: WeightedGraph<String>)] {
	[
		("path40", try Synthetic.path(40)),
		("star60", try Synthetic.star(60)),
		("ring50", try Synthetic.ring(50)),
		("er60 with isolates", try Synthetic.erdosRenyi(seed: 5, count: 60, edgeCount: 40)),
		("preferential", try Synthetic.preferentialAttachment(seed: 6, count: 60, perNode: 2)),
		("communities", try Synthetic.communities(seed: 7, count: 60, groups: 3, inside: 40, between: 3)),
	]
}

/// The closed form for a star of `count` nodes: the hub's share, then each leaf's.
private func starScores(count: Int, damping: Double) -> (hub: Double, leaf: Double) {
	let leaves = Double(count - 1)
	let size = Double(count)
	let hub: Double = (1 + damping * leaves) / (size * (1 + damping))
	let leaf: Double = (1 - hub) / leaves
	return (hub, leaf)
}

// MARK: - Suite

@Suite("PageRank convergence report")
struct PageRankConvergenceTests {

	@Test("pageRank and pageRankConvergence are one loop: identical scores bit for bit, and identical to the loop as it was before this change",
		  arguments: [UInt64(1), 2, 3, 4, 5, 6])
	func oneLoopAndUnchangedNumbers(seed: UInt64) throws {
		let count = 20 + Int(seed) * 9
		let graphs = [
			try Synthetic.erdosRenyi(seed: seed, count: count, edgeCount: count),
			try Synthetic.preferentialAttachment(seed: seed, count: count, perNode: 2),
			try Synthetic.communities(seed: seed, count: count, groups: 2, inside: count * 2, between: 3),
		]
		for graph in graphs {
			for damping in [0.0, 0.5, 0.85, 0.99, 0.999] {
				for ceiling in [0, 1, 2, 5, 17, 200] {
					for tolerance in [1e-12, 1e-3, 0.0] {
						let direct = Centrality.pageRank(
							graph, damping: damping, maxIterations: ceiling, tolerance: tolerance)
						let run = Centrality.pageRankConvergence(
							graph, damping: damping, maxIterations: ceiling, tolerance: tolerance)
						let legacy = legacyPageRank(
							graph, damping: damping, maxIterations: ceiling, tolerance: tolerance)
						let note = "seed \(seed) damping \(damping) ceiling \(ceiling) tolerance \(tolerance)"
						#expect(bits(direct) == bits(run.scores), "\(note)")
						#expect(bits(direct) == bits(legacy), "\(note)")
					}
				}
			}
		}
	}

	@Test("Does not claim convergence when the ceiling is too small, and does when it is large")
	func convergedFlag() throws {
		let path = try Synthetic.path(80)
		let tight = Centrality.pageRankConvergence(path, maxIterations: 5)
		#expect(tight.converged == false)
		#expect(tight.iterations == 5)
		#expect(tight.residual >= 1e-12)

		let roomy = Centrality.pageRankConvergence(path, maxIterations: 100_000)
		#expect(roomy.converged)
		#expect(roomy.iterations > 5)
		#expect(roomy.iterations < 100_000)
		#expect(roomy.residual < 1e-12)
	}

	@Test("A zero ceiling still runs one pass, as pageRank does")
	func zeroCeilingIsOnePass() throws {
		let result = Centrality.pageRankConvergence(try Synthetic.path(10), maxIterations: 0)
		#expect(result.iterations == 1)
		#expect(result.converged == false)
	}

	@Test("The residual is the final L1 change, and one pass fewer is not yet converged")
	func residualMeaning() throws {
		let graph = try Synthetic.erdosRenyi(seed: 11, count: 200, edgeCount: 800)
		let result = Centrality.pageRankConvergence(graph, tolerance: 1e-6)
		#expect(result.converged)
		#expect(result.residual < 1e-6)
		#expect(result.residual >= 0)
		let before = Centrality.pageRankConvergence(
			graph, maxIterations: result.iterations - 1, tolerance: 1e-6)
		#expect(before.converged == false)
		#expect(before.residual >= 1e-6)
	}

	@Test("A looser tolerance never needs more passes, and an enormous one stops after the first")
	func toleranceControlsStopping() throws {
		let graph = try Synthetic.communities(seed: 3, count: 120, groups: 2, inside: 300, between: 2)
		let strict = Centrality.pageRankConvergence(graph, maxIterations: 100_000, tolerance: 1e-12)
		let loose = Centrality.pageRankConvergence(graph, maxIterations: 100_000, tolerance: 1e-4)
		#expect(strict.converged)
		#expect(loose.converged)
		#expect(loose.iterations < strict.iterations)
		let instant = Centrality.pageRankConvergence(graph, maxIterations: 100_000, tolerance: 1e9)
		#expect(instant.iterations == 1)
		#expect(instant.converged)
	}

	@Test("Degenerate graphs: an empty graph has nothing to iterate; one node and an edgeless graph settle at once")
	func degenerate() throws {
		let empty = Centrality.pageRankConvergence(try WeightedGraph<String>(edges: []))
		#expect(empty.converged)
		#expect(empty.iterations == 0)
		#expect(empty.residual.isEqual(to: 0))
		#expect(empty.scores.scores.isEmpty)

		let lone = Centrality.pageRankConvergence(try WeightedGraph<String>(edges: [], isolatedNodes: ["x"]))
		#expect(lone.converged)
		#expect(lone.iterations >= 1)
		let loneScore = try #require(lone.scores["x"])
		#expect(abs(loneScore - 1) < 1e-12)

		let edgeless = Centrality.pageRankConvergence(
			try WeightedGraph<String>(edges: [], isolatedNodes: ["x", "y", "z"]))
		#expect(edgeless.converged)
		for score in edgeless.scores.scores.values { #expect(abs(score - 1.0 / 3.0) < 1e-12) }
	}

	@Test("The a-priori bound is the oracle: after k passes the L1 error is at most 2 * damping^k, on every family and damping")
	func aPrioriBound() throws {
		for (name, graph) in try families() {
			for damping in [0.5, 0.7, 0.85, 0.9, 0.95, 0.99] {
				let exact = IndependentImplementations.pageRankByDenseSolve(graph, damping: damping)
				for passes in [1, 2, 3, 5, 10, 20, 40, 80, 160] {
					let run = Centrality.pageRankConvergence(
						graph, damping: damping, maxIterations: passes, tolerance: 0)
					let error = l1Error(run.scores, exact, graph)
					let bound: Double = 2 * pow(damping, Double(passes))
					#expect(error <= bound + 1e-12, "\(name) damping \(damping) passes \(passes)")
				}
			}
		}
	}

	@Test("At the default damping and tolerance, convergence is reached within the pass count the bound predicts, on every family")
	func passesMatchThePrediction() throws {
		let tolerance = 1e-12
		for (name, graph) in try families() {
			for damping in [0.5, 0.7, 0.85, 0.9, 0.95] {
				let predicted = predictedPasses(damping: damping, tolerance: tolerance)
				let run = Centrality.pageRankConvergence(
					graph, damping: damping, maxIterations: 10_000, tolerance: tolerance)
				#expect(run.converged, "\(name) \(damping)")
				#expect(run.iterations >= 1, "\(name) \(damping)")
				#expect(run.residual < tolerance, "\(name) \(damping)")
				#expect(run.iterations <= predicted + 2, "\(name) \(damping) took \(run.iterations), predicted \(predicted)")
			}
		}
	}

	@Test("The default call converges on every family, with the ceiling's margin intact")
	func defaultConverges() throws {
		for (name, graph) in try families() {
			let run = Centrality.pageRankConvergence(graph)
			#expect(run.converged, "\(name)")
			#expect(run.iterations >= 1, "\(name)")
			#expect(run.residual < 1e-12, "\(name)")
			#expect(run.iterations <= 176, "\(name)")
		}
	}

	@Test("Damping 0.99 at the default ceiling does not converge, says so, and the scores really are off")
	func highDampingReportsNonConvergence() throws {
		let graph = try Synthetic.path(120)
		let run = Centrality.pageRankConvergence(graph, damping: 0.99)
		#expect(run.converged == false)
		#expect(run.iterations == 200)
		#expect(run.residual > 1e-12)
		// It is a true failure, not a false alarm: the answer is far from the fixed point.
		let exact = IndependentImplementations.pageRankByDenseSolve(graph, damping: 0.99)
		let error = l1Error(run.scores, exact, graph)
		#expect(error > 1e-6)
		// The a-priori count says why: 2819 passes are needed, 200 are allowed.
		#expect(predictedPasses(damping: 0.99, tolerance: 1e-12) > 200)
	}

	@Test("Damping 0.9 stops short on a path within the default ceiling, which the bound also predicts")
	func dampingPointNine() throws {
		let graph = try Synthetic.path(1_000)
		let run = Centrality.pageRankConvergence(graph, damping: 0.9)
		#expect(run.converged == false)
		#expect(run.iterations == 200)
		#expect(predictedPasses(damping: 0.9, tolerance: 1e-12) > 200)
	}

	@Test("A star of 5,000 at the defaults converges, to the closed form")
	func starConverges() throws {
		let graph = try Synthetic.star(5_000)
		let run = Centrality.pageRankConvergence(graph)
		#expect(run.converged)
		#expect(run.iterations <= 176)
		// The star is the structurally slowest family: the bound is nearly tight on it.
		let predicted = predictedPasses(damping: 0.85, tolerance: 1e-12)
		#expect(run.iterations >= predicted - 5)
		let exact = starScores(count: 5_000, damping: 0.85)
		let hub = try #require(run.scores[Synthetic.name(0)])
		let leaf = try #require(run.scores[Synthetic.name(1)])
		#expect(abs(hub - exact.hub) < 1e-12)
		#expect(abs(leaf - exact.leaf) < 1e-12)
	}

	/// Measured, not assumed (pagerank-measurement.md section 2b): a star-like hub sums many equal
	/// terms, so the change between passes bottoms out above 1e-12 once the star is large enough,
	/// and the loop runs to the ceiling without ever meeting the tolerance although its answer is
	/// accurate. The report says so truthfully: not converged, residual a little above the
	/// tolerance, and the scores within about 1e-11 of the closed form. This pins the behaviour at
	/// 50,000 nodes, where the floor (measured 4.5e-12) is 4.5 times the tolerance; the
	/// threshold itself, between 10,000 and 11,000 on the machine that measured it, is a rounding
	/// limit cycle and is not pinned.
	@Test("A very large star cannot meet the tolerance and reports that, while its scores are still accurate")
	func largeStarNoiseFloor() throws {
		let graph = try Synthetic.star(50_000)
		let run = Centrality.pageRankConvergence(graph)
		#expect(run.converged == false)
		#expect(run.iterations == 200)
		#expect(run.residual > 1e-12)
		#expect(run.residual < 1e-9)
		let exact = starScores(count: 50_000, damping: 0.85)
		let hub = try #require(run.scores[Synthetic.name(0)])
		#expect(abs(hub - exact.hub) < 1e-10)
	}
}

@Suite("PageRank metric, version 3")
struct PageRankMetricVersion3Tests {

	@Test("The registered metric is pagerank at version 3 and its defaults are the loop's")
	func descriptorAndDefaults() {
		#expect(PageRankMetric<String>.descriptor.identifier == "pagerank")
		#expect(PageRankMetric<String>.descriptor.version == 3)
		let metric = PageRankMetric<String>()
		#expect(metric.damping.isEqual(to: 0.85))
		#expect(metric.maxIterations == 200)
		#expect(metric.tolerance.isEqual(to: 1e-12))
	}

	@Test("It returns the same scores as Centrality.pageRank, bit for bit, plus the report of that run")
	func scoresAndReport() throws {
		let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
		let result = try PageRankMetric<Int>().compute(on: graph)
		let direct = Centrality.pageRank(graph)
		#expect(result.scores.scores.mapValues { $0.bitPattern } == direct.scores.mapValues { $0.bitPattern })
		let report = try #require(result.convergence)
		let run = Centrality.pageRankConvergence(graph)
		#expect(report.iterations == run.iterations)
		#expect(report.converged == run.converged)
		#expect(report.residual.isEqual(to: run.residual))
		#expect(report.tolerance.isEqual(to: 1e-12))
		#expect(report.maxIterations == 200)
	}

	@Test("A damping that cannot converge in the ceiling is recorded as not converged, with the sentence that says so")
	func recordedNonConvergence() throws {
		let graph = try Synthetic.path(120)
		let result = try PageRankMetric<String>(damping: 0.99).compute(on: graph)
		let report = try #require(result.convergence)
		#expect(report.converged == false)
		#expect(report.iterations == 200)
		#expect(ConvergenceNote.sentence(report).hasPrefix("Did not converge"))
		let registry = MetricRegistry([AnyGraphMetric(PageRankMetric<String>(damping: 0.99))])
		let record = try #require(try registry.record(
			"pagerank", on: graph, context: "ctx", now: Date(timeIntervalSince1970: 0)))
		#expect(record.output.convergence?.converged == false)
	}

	@Test("The stored shape is kind 'scores' with an optional convergence key, so plain-scores readers still work")
	func storedShape() throws {
		let record = try #require(try MetricRegistry<Int>.standard.record(
			"pagerank", on: karate(), context: "ctx", now: Date(timeIntervalSince1970: 0)))
		#expect(record.metricVersion == 3)
		#expect(record.output.kind == "scores")
		#expect(record.output.convergence?.converged == true)
		let plain = try #require(try record.output.value(as: NodeScores<Int>.self))
		#expect(plain.scores.count == 34)
		let typed = try #require(try record.output.value(as: DiagnosedScores<Int>.self))
		#expect(typed.convergence == record.output.convergence)
	}

	private func karate() -> WeightedGraph<Int> {
		WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
	}

	@Test("A version 2 pagerank record, written before convergence was reported, still decodes, reads as unknown, and re-encodes to the stored bytes")
	func version2StillDecodes() throws {
		let stored = #"{"computedAt":0,"context":"old","metric":"pagerank","metricVersion":2,"output":{"kind":"scores","payload":{"scores":{"a":0.25,"b":0.5,"c":0.25}}}}"#
		let record = try JSONDecoder().decode(MetricRecord<String>.self, from: Data(stored.utf8))
		#expect(record.metricVersion == 2)
		#expect(record.output.convergence == nil)
		let typed = try #require(try record.output.value(as: DiagnosedScores<String>.self))
		#expect(typed.convergence == nil)
		#expect(ConvergenceNote.sentence(record.output.convergence) == "Convergence was not recorded for this result.")
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		#expect(String(decoding: try encoder.encode(record), as: UTF8.self) == stored)
	}
}
