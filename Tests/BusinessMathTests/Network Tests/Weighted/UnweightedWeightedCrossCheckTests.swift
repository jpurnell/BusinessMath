//
//  UnweightedWeightedCrossCheckTests.swift
//  BusinessMath
//
//  PERMANENT cross-check: BusinessMath's directed, unweighted `Graph` measures (with the
//  eigenvector and Louvain fixes of step 0) against the undirected `WeightedGraph` measures
//  on the same symmetrised, unweighted graph. Two implementations of the same quantity,
//  written separately, must agree; where they legitimately differ (a `nil` refusal versus a
//  value, directed versus undirected reading) the difference is asserted and named here
//  rather than hidden. If a pair that should agree stops agreeing, fix the code, not the
//  tolerance.
//
//  Tolerances, and why:
//  - degree: exact (small integers in a Double).
//  - betweenness, harmonic closeness, modularity: 1e-12. Same algorithm, different summation
//    order (dictionary versus array), so equal to rounding.
//  - PageRank: 1e-10 per score. Both stop at 1e-12 but on different norms (L1 versus L-inf),
//    so the iterates differ by up to a few multiples of the stopping threshold.
//  - eigenvector: 1e-6 per score after rescaling BM's unit-length vector to a maximum of one
//    (the weighted measure is max-normalised). BM stops at 1e-12 in L-inf, the weighted
//    measure at 1e-10 in L1, and each carries its own convergence error.
//  - Louvain: the partitions as sets of sets, and the modularity values to 1e-12.
//

import Foundation
import Testing
import SwiftDeterminism
import TestSupport
@testable import BusinessMath

// MARK: - Fixtures

struct CrossCheckFixture: Sendable {
	let name: String
	let edges: [(String, String)]
	let isolated: [String]
	let connected: Bool
	let bipartite: Bool
	var weighted: WeightedGraph<String> {
		WeightedGraph(unweightedEdges: edges, isolatedNodes: isolated)
	}
	/// The same graph for the directed, unweighted implementation: every edge in both
	/// directions, built directly (not through the bridge, which is tested on its own).
	var plain: Graph<String> {
		var adjacency: [String: [String]] = [:]
		var seen = Set<[String]>()
		for (a, b) in edges where a != b {
			let key = a < b ? [a, b] : [b, a]
			guard seen.insert(key).inserted else { continue }
			adjacency[a, default: []].append(b)
			adjacency[b, default: []].append(a)
		}
		for node in isolated where adjacency[node] == nil { adjacency[node] = [] }
		return Graph(adjacency: adjacency)
	}
}

private func label(_ prefix: String, _ index: Int) -> String {
	index < 10 ? prefix + "0" + String(index) : prefix + String(index)
}

private func pathEdges(_ count: Int) -> [(String, String)] {
	(0..<(count - 1)).map { (label("p", $0), label("p", $0 + 1)) }
}

private func cliqueEdges(_ prefix: String, _ size: Int) -> [(String, String)] {
	var out: [(String, String)] = []
	for i in 0..<size {
		for j in (i + 1)..<size { out.append((label(prefix, i), label(prefix, j))) }
	}
	return out
}

/// A random connected graph: a random spanning tree plus extra chords, without duplicates.
private func randomConnected(seed: UInt64, count: Int, extra: Int) -> [(String, String)] {
	var rng = SplitMix64(seed: seed)
	var seen = Set<[Int]>()
	var edges: [(String, String)] = []
	func add(_ a: Int, _ b: Int) {
		guard a != b else { return }
		let key = a < b ? [a, b] : [b, a]
		guard seen.insert(key).inserted else { return }
		edges.append((label("v", a), label("v", b)))
	}
	for node in 1..<count { add(node, Int.random(in: 0..<node, using: &rng)) }
	for _ in 0..<extra { add(Int.random(in: 0..<count, using: &rng), Int.random(in: 0..<count, using: &rng)) }
	return edges
}

private let kiteTies: [(String, String)] = ReferenceGraphs.kiteEdges
private let karateTies: [(String, String)] = ReferenceGraphs.karateEdges.map { (label("k", $0.0), label("k", $0.1)) }

private var ringOfCliques: [(String, String)] {
	var edges: [(String, String)] = []
	for c in 0..<4 {
		edges += cliqueEdges("r\(c)m", 5)
		edges.append(("r\(c)m00", "r\((c + 1) % 4)m03"))
	}
	return edges
}

private let connectedFixtures: [CrossCheckFixture] = [
	CrossCheckFixture(name: "path5", edges: pathEdges(5), isolated: [], connected: true, bipartite: true),
	CrossCheckFixture(name: "path6", edges: pathEdges(6), isolated: [], connected: true, bipartite: true),
	CrossCheckFixture(name: "star5", edges: (1...4).map { ("hub", label("l", $0)) }, isolated: [], connected: true, bipartite: true),
	CrossCheckFixture(name: "evenCycle6", edges: (0..<6).map { (label("c", $0), label("c", ($0 + 1) % 6)) }, isolated: [], connected: true, bipartite: true),
	CrossCheckFixture(name: "k23", edges: [("a1", "b1"), ("a1", "b2"), ("a1", "b3"), ("a2", "b1"), ("a2", "b2"), ("a2", "b3")], isolated: [], connected: true, bipartite: true),
	CrossCheckFixture(name: "triangle", edges: [("a", "b"), ("b", "c"), ("a", "c")], isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "oddCycle5", edges: (0..<5).map { (label("c", $0), label("c", ($0 + 1) % 5)) }, isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "kite", edges: kiteTies, isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "karate", edges: karateTies, isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "ringOfCliques", edges: ringOfCliques, isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "random1", edges: randomConnected(seed: 1, count: 14, extra: 10), isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "random2", edges: randomConnected(seed: 2, count: 20, extra: 6), isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "random3", edges: randomConnected(seed: 3, count: 25, extra: 30), isolated: [], connected: true, bipartite: false),
	CrossCheckFixture(name: "random4", edges: randomConnected(seed: 4, count: 12, extra: 0), isolated: [], connected: true, bipartite: true),
]

private let disconnectedFixtures: [CrossCheckFixture] = [
	CrossCheckFixture(name: "twoTriangles", edges: [("a", "b"), ("b", "c"), ("a", "c"), ("x", "y"), ("y", "z"), ("x", "z")], isolated: [], connected: false, bipartite: false),
	CrossCheckFixture(name: "pathAndTriangle", edges: [("a", "b"), ("b", "c"), ("x", "y"), ("y", "z"), ("x", "z")], isolated: [], connected: false, bipartite: false),
	CrossCheckFixture(name: "pathWithIsolates", edges: [("a", "b"), ("b", "c")], isolated: ["x", "y", "z"], connected: false, bipartite: true),
	CrossCheckFixture(name: "kiteWithIsolate", edges: kiteTies, isolated: ["Zed"], connected: false, bipartite: false),
]

private let allFixtures: [CrossCheckFixture] = connectedFixtures + disconnectedFixtures

private func louvainOutcome(_ fixture: CrossCheckFixture) throws -> (sameSets: Bool, modularityDifference: Double) {
	let graph = fixture.weighted
	let weighted = Community.louvain(graph)
	let plain = try #require(fixture.plain.louvainCommunities())
	let plainQ = try #require(fixture.plain.modularity(of: plain))
	let weightedQ = try Community.modularity(graph, partition: weighted)
	return (Set(plain) == asSets(weighted), abs(plainQ - weightedQ))
}

private func maxDifference(_ left: [String: Double], _ right: NodeScores<String>) -> Double? {
	guard Set(left.keys) == Set(right.scores.keys) else { return nil }
	var worst = 0.0
	for (node, value) in left {
		guard let other = right.scores[node] else { return nil }
		worst = max(worst, abs(value - other))
	}
	return worst
}

/// A partition as a set of member sets, so labels and order do not matter.
private func asSets(_ partition: NodePartition<String>) -> Set<Set<String>> {
	Set(partition.groups.map { Set($0.members) })
}

private func partition(_ groups: [Set<String>]) -> NodePartition<String> {
	var map: [String: Int] = [:]
	for (index, group) in groups.enumerated() { for node in group { map[node] = index } }
	return NodePartition(map)
}

// MARK: - Suite

@Suite("Cross-check: unweighted Graph measures against WeightedGraph measures")
struct UnweightedWeightedCrossCheckTests {

	@Test("Degree: out-degree count equals weighted degree on a symmetrised unweighted graph",
		  arguments: allFixtures)
	func degreeAgrees(_ fixture: CrossCheckFixture) throws {
		let plain = fixture.plain.degreeCentrality
		let weighted = Centrality.degree(fixture.weighted)
		let difference = try #require(maxDifference(plain, weighted))
		#expect(difference == 0)
	}

	@Test("PageRank agrees to 1e-10, including dangling nodes (isolates)", arguments: allFixtures)
	func pageRankAgrees(_ fixture: CrossCheckFixture) throws {
		let plain = try #require(fixture.plain.pageRank())
		let weighted = try Centrality.pageRank(fixture.weighted)
		let difference = try #require(maxDifference(plain, weighted))
		#expect(difference < 1e-10)
	}

	@Test("Betweenness agrees to 1e-12", arguments: allFixtures)
	func betweennessAgrees(_ fixture: CrossCheckFixture) throws {
		let plain = fixture.plain.betweennessCentrality
		let weighted = Centrality.betweenness(fixture.weighted)
		let difference = try #require(maxDifference(plain, weighted))
		#expect(difference < 1e-12)
	}

	@Test("Harmonic closeness agrees to 1e-12", arguments: allFixtures)
	func harmonicAgrees(_ fixture: CrossCheckFixture) throws {
		let plain = fixture.plain.harmonicCloseness
		let weighted = Centrality.harmonic(fixture.weighted)
		let difference = try #require(maxDifference(plain, weighted))
		#expect(difference < 1e-12)
	}

	@Test("Eigenvector agrees to 1e-6 after rescaling, on connected graphs including bipartite ones",
		  arguments: connectedFixtures)
	func eigenvectorAgrees(_ fixture: CrossCheckFixture) throws {
		let plain = try #require(fixture.plain.eigenvectorCentrality(tolerance: 1e-12, maxIterations: 20_000))
		let peak = try #require(plain.values.max())
		#expect(peak > 0)
		var rescaled: [String: Double] = [:]
		for (node, value) in plain { rescaled[node] = value / peak }
		let report = try Centrality.eigenvectorConvergence(fixture.weighted, maxIterations: 20_000, tolerance: 1e-12)
		#expect(report.converged)
		let difference = try #require(maxDifference(rescaled, report.scores))
		#expect(difference < 1e-6)
	}

	@Test("Eigenvector at the weighted default budget agrees on the small bipartite graphs too")
	func eigenvectorDefaultBudgetBipartite() throws {
		for fixture in connectedFixtures where fixture.bipartite {
			let plain = try #require(fixture.plain.eigenvectorCentrality(tolerance: 1e-12, maxIterations: 20_000))
			let peak = try #require(plain.values.max())
			var rescaled: [String: Double] = [:]
			for (node, value) in plain { rescaled[node] = value / peak }
			let weighted = try Centrality.eigenvector(fixture.weighted)
			let difference = try #require(maxDifference(rescaled, weighted))
			#expect(difference < 1e-6)
		}
	}

	@Test("Eigenvector, agreement since ADR-009: both refuse a disconnected graph, nil unweighted and a thrown error weighted",
		  arguments: [disconnectedFixtures[1], disconnectedFixtures[2], disconnectedFixtures[3]])
	func eigenvectorDisconnectedBothRefuse(_ fixture: CrossCheckFixture) {
		#expect(fixture.plain.eigenvectorCentrality() == nil)
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.eigenvector(fixture.weighted) }
	}

	@Test("Eigenvector, agreement since ADR-009: two components with the same leading eigenvalue are refused by both too")
	func eigenvectorTiedComponentsBothRefuse() {
		let fixture = disconnectedFixtures[0]
		#expect(fixture.plain.eigenvectorCentrality() == nil)
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.eigenvector(fixture.weighted) }
	}

	@Test("Eigenvector, agreement since ADR-009: an edgeless graph is nil unweighted and refused weighted (it scored all ones before)")
	func eigenvectorEdgelessBothRefuse() {
		let plain = Graph<String>(adjacency: ["a": [], "b": [], "c": []])
		#expect(plain.eigenvectorCentrality() == nil)
		let weighted = WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["a", "b", "c"])
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.eigenvector(weighted) }
	}

	@Test("Modularity of the same partition agrees to 1e-12: the weighted Louvain result, the components, and singletons",
		  arguments: allFixtures)
	func modularityAgrees(_ fixture: CrossCheckFixture) throws {
		let graph = fixture.weighted
		let louvain = Community.louvain(graph)
		let candidates: [NodePartition<String>] = [
			louvain, Community.connectedComponents(graph),
			NodePartition(Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) })),
		]
		for candidate in candidates {
			let sets = candidate.groups.map { Set($0.members) }
			let plain = try #require(fixture.plain.modularity(of: sets))
			let weighted = try Community.modularity(graph, partition: candidate)
			#expect(abs(plain - weighted) < 1e-12)
		}
	}

	@Test("Louvain: the partitions are the same sets of nodes and have the same modularity",
		  arguments: allFixtures)
	func louvainAgrees(_ fixture: CrossCheckFixture) throws {
		let outcome = try louvainOutcome(fixture)
		#expect(outcome.sameSets)
		#expect(outcome.modularityDifference < 1e-12)
	}

	/// `random3` used to be split differently by the two implementations (modularity 0.3615 unweighted,
	/// 0.3569 weighted): the weighted Louvain moves a node only if the gain beats the best by more than
	/// 1e-12, the unweighted one if it was strictly greater, so a tie that is exact on paper was
	/// decided by rounding there and kept as a tie here. It was pinned as a known issue until step 4
	/// (ADR-009) gave the unweighted rule the same margin; it is a plain assertion now.
	@Test("Louvain: random3 is split the same way by both, now that the unweighted move rule has the tie margin")
	func louvainTieRuleRandom3() throws {
		let fixture = try #require(allFixtures.first { $0.name == "random3" })
		let outcome = try louvainOutcome(fixture)
		#expect(outcome.sameSets)
		#expect(outcome.modularityDifference < 1e-12)
	}

	@Test("Louvain on the karate club finds the same four communities in both")
	func karateLouvain() throws {
		let fixture = CrossCheckFixture(name: "karate", edges: karateTies, isolated: [], connected: true, bipartite: false)
		let plain = try #require(fixture.plain.louvainCommunities())
		let weighted = Community.louvain(fixture.weighted)
		#expect(Set(plain) == asSets(weighted))
		#expect(plain.count == weighted.communityCount)
	}

	@Test("Modularity, difference: an edgeless graph is nil unweighted and zero weighted")
	func modularityEdgelessDifference() throws {
		let plain = Graph<String>(adjacency: ["a": [], "b": []])
		#expect(plain.modularity(of: [["a"], ["b"]]) == nil)
		let weighted = WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["a", "b"])
		let value = try Community.modularity(weighted, partition: partition([["a"], ["b"]]))
		#expect(value == 0)
	}

	@Test("Modularity, agreement since ADR-009: a partition that omits a node is refused by both, nil unweighted and a thrown error weighted")
	func modularityPartialPartitionBothRefuse() {
		let fixture = connectedFixtures[0]
		let omitted = fixture.edges[0].0
		var sets = Community.connectedComponents(fixture.weighted).groups.map { Set($0.members) }
		sets[0].remove(omitted)
		#expect(fixture.plain.modularity(of: sets) == nil)
		#expect(throws: GraphMeasureError.self) {
			_ = try Community.modularity(fixture.weighted, partition: partition(sets))
		}
	}

	@Test("Modularity, agreement since ADR-009: a partition that names a node the graph does not have is refused by both")
	func modularityForeignNodeBothRefuse() {
		let fixture = connectedFixtures[0]
		var sets = Community.connectedComponents(fixture.weighted).groups.map { Set($0.members) }
		sets[0].insert("not-a-node")
		#expect(fixture.plain.modularity(of: sets) == nil)
		#expect(throws: GraphMeasureError.self) {
			_ = try Community.modularity(fixture.weighted, partition: partition(sets))
		}
	}

	@Test("Louvain, difference: an edgeless graph is nil unweighted, every node alone weighted")
	func louvainEdgelessDifference() {
		let plain = Graph<String>(adjacency: ["a": [], "b": []])
		#expect(plain.louvainCommunities() == nil)
		let weighted = Community.louvain(WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["a", "b"]))
		#expect(weighted.communityCount == 2)
	}

	@Test("Directed semantics, difference: a directed path scores its out-edges only; symmetrised, the middle node has degree two")
	func directedDifference() {
		let directed = Graph(edges: [("a", "b"), ("b", "c")])
		#expect(directed.degreeCentrality == ["a": 1, "b": 1, "c": 0])
		let symmetrised = Centrality.degree(WeightedGraph(directed))
		#expect(symmetrised.scores == ["a": 1, "b": 2, "c": 1])
	}
}
