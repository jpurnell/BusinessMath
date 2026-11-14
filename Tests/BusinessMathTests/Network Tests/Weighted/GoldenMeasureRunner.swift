//
//  GoldenMeasureRunner.swift
//  BusinessMath
//
//  Runs every ported measure over a graph and renders each result as bit-pattern tokens. This
//  file was byte-for-byte the runner the scratch program used against SwiftGraphMetrics (only
//  the import line differed), so the two sides encoded identically. Step 4 (ADR-009) changed some
//  behaviours on purpose; for those the runner renders the new outcome, `refused`, under the same
//  key, and GoldenMeasureTests asserts it against the stored old tokens explicitly. Every other
//  line is unchanged except for the `try` that a throwing signature requires.
//

import Foundation
@testable import BusinessMath
// Template shared verbatim (except the import line) with the BusinessMath golden test.

func hex(_ value: Double) -> String { String(value.bitPattern, radix: 16) }

func goldenScoreTokens(_ scores: NodeScores<String>, _ graph: WeightedGraph<String>) -> String {
	graph.nodes.map { node in scores.scores[node].map(hex) ?? "-" }.joined(separator: " ")
}

func goldenPartitionTokens(_ partition: NodePartition<String>, _ graph: WeightedGraph<String>) -> String {
	graph.nodes.map { node in partition.communities[node].map(String.init) ?? "-" }.joined(separator: " ")
}

/// The tokens of a measure that may now refuse its input, or `refused`.
func goldenTokensOrRefusal(_ graph: WeightedGraph<String>, _ body: () throws -> NodeScores<String>) -> String {
	do {
		return goldenScoreTokens(try body(), graph)
	} catch {
		return "refused"
	}
}

/// The bit pattern of a value that may now refuse its input, or `refused`.
func goldenValueOrRefusal(_ body: () throws -> Double) -> String {
	do {
		return hex(try body())
	} catch {
		return "refused"
	}
}

func goldenMeasures(_ graph: WeightedGraph<String>) -> [(String, String)] {
	var out: [(String, String)] = []
	func scores(_ key: String, _ value: NodeScores<String>) { out.append((key, goldenScoreTokens(value, graph))) }
	func parts(_ key: String, _ value: NodePartition<String>) { out.append((key, goldenPartitionTokens(value, graph))) }

	scores("degree", Centrality.degree(graph))
	scores("eigenvector", Centrality.eigenvector(graph))
	let converged = Centrality.eigenvectorConvergence(graph)
	out.append(("eigenvectorConvergence.report",
		"\(converged.iterations) \(converged.converged ? 1 : 0) \(hex(converged.residual))"))
	scores("eigenvectorConvergence.scores", converged.scores)
	let capped = Centrality.eigenvectorConvergence(graph, maxIterations: 5, tolerance: 1e-10)
	out.append(("eigenvectorCeiling5.report",
		"\(capped.iterations) \(capped.converged ? 1 : 0) \(hex(capped.residual))"))
	scores("eigenvectorCeiling5.scores", capped.scores)
	let loose = Centrality.eigenvectorConvergence(graph, maxIterations: 200, tolerance: 1e-3)
	out.append(("eigenvectorTol1e-3.report",
		"\(loose.iterations) \(loose.converged ? 1 : 0) \(hex(loose.residual))"))
	scores("eigenvectorTol1e-3.scores", loose.scores)
	scores("eigenvectorZeroCeiling", Centrality.eigenvector(graph, maxIterations: 0))
	out.append(("pageRank", goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph) }))
	for damping in [0.5, 0.99] {
		out.append(("pageRank.damping\(damping)", goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, damping: damping) }))
	}
	// Step 4 (ADR-009): 1.5 used to run as 0.999 and -1 as 0; both are refused now.
	for damping in [1.5, -1.0] {
		out.append(("pageRank.damping\(damping)", goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, damping: damping) }))
	}
	out.append(("pageRank.ceiling3", goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, maxIterations: 3) }))
	out.append(("pageRank.tol1e-3", goldenTokensOrRefusal(graph) { try Centrality.pageRank(graph, tolerance: 1e-3) }))
	scores("betweenness", Centrality.betweenness(graph))
	scores("betweennessRaw", Centrality.betweenness(graph, normalized: false))
	scores("closeness", Centrality.closeness(graph))
	scores("harmonic", Centrality.harmonic(graph))
	scores("clustering", Centrality.clustering(graph))
	scores("kCore", Community.kCore(graph))
	scores("constraint", Brokerage.constraint(graph))
	let components = Community.connectedComponents(graph)
	parts("components", components)
	let louvain = Community.louvain(graph)
	parts("louvain", louvain)
	parts("louvain.resolution0.5", Community.louvain(graph, resolution: 0.5))
	parts("louvain.resolution2", Community.louvain(graph, resolution: 2.0))
	parts("louvain.passes1", Community.louvain(graph, maxPasses: 1))
	out.append(("modularity.louvain", goldenValueOrRefusal { try Community.modularity(graph, partition: louvain) }))
	out.append(("modularity.components", goldenValueOrRefusal { try Community.modularity(graph, partition: components) }))
	let singletons = NodePartition(Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) }))
	out.append(("modularity.singletons", goldenValueOrRefusal { try Community.modularity(graph, partition: singletons) }))
	let half = NodePartition(Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().filter { $0.offset % 2 == 0 }.map { ($0.element, 0) }))
	// Step 4 (ADR-009): a partition that leaves nodes out used to be scored; it is refused now.
	out.append(("modularity.partial", goldenValueOrRefusal { try Community.modularity(graph, partition: half) }))
	return out
}
