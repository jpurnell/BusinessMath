//
//  WeightedReferenceValueTests.swift
//  BusinessMath
//  Every expected value here comes from the literature, not from running the
//  code. A fixture whose answers were produced by the code under test proves
//  only that the code agrees with itself.
//

import Foundation
import Testing

import TestSupport
@testable import BusinessMath

private var kite: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
}

private var karate: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges.map {
		(String($0.0), String($0.1))
	})
}

@Suite("Reference graphs are what they claim")
struct ReferenceGraphIntegrityTests {

	@Test("The kite has ten nodes and eighteen edges")
	func kiteShape() {
		#expect(kite.nodeCount == 10)
		#expect(kite.edgeCount == 18)
	}

	@Test("The karate club has thirty-four nodes and seventy-eight edges")
	func karateShape() {
		#expect(karate.nodeCount == 34)
		#expect(karate.edgeCount == 78)
	}

	@Test("Kite degrees match the published sequence")
	func kiteDegrees() {
		let scores = Centrality.degree(kite)
		for (node, expected) in ReferenceGraphs.kiteDegrees {
			#expect(scores[node]?.isEqual(to: Double(expected)) == true,
					"\(node): expected \(expected), got \(scores[node] ?? -1)")
		}
	}

	@Test("Karate degrees match the published values")
	func karateDegrees() {
		let scores = Centrality.degree(karate)
		for (node, expected) in ReferenceGraphs.karateDegrees {
			#expect(scores[String(node)]?.isEqual(to: Double(expected)) == true,
					"node \(node): expected \(expected), got \(scores[String(node)] ?? -1)")
		}
	}
}

@Suite("Centrality against published results")
struct PublishedCentralityTests {

	/// The point of the kite graph. Degree and betweenness pick different
	/// people, which is why this library reports both rather than one.
	@Test("Degree and betweenness disagree on the kite, as published")
	func metricsDisagree() throws {
		let degrees = Centrality.degree(kite)
		let betweenness = Centrality.betweenness(kite)

		#expect(degrees.ranked.first?.node == "Diane")
		#expect(betweenness.ranked.first?.node == "Heather")
		// Diane is the best connected and yet bridges almost nothing.
		let dianeBetweenness = try #require(betweenness["Diane"])
		let heatherBetweenness = try #require(betweenness["Heather"])
		#expect(heatherBetweenness > dianeBetweenness)
	}

	/// Published normalised betweenness for the kite: Heather 0.389,
	/// Ike 0.222, Fernando and Garth 0.231, Diane 0.102.
	@Test("Kite betweenness matches the published values")
	func kiteBetweenness() {
		let scores = Centrality.betweenness(kite, normalized: true)
		let expected: [String: Double] = [
			"Heather": 0.3889, "Ike": 0.2222, "Fernando": 0.2315,
			"Garth": 0.2315, "Diane": 0.1019, "Jane": 0.0,
		]
		for (node, value) in expected {
			let actual = scores[node] ?? -1
			#expect(abs(actual - value) < 0.001,
					"\(node): expected \(value), got \(actual)")
		}
	}

	/// Node 34 (the administrator) outranks node 1 (the instructor) on
	/// eigenvector centrality — a standard result for this graph.
	@Test("Karate eigenvector ranks the administrator first")
	func karateEigenvector() {
		let scores = Centrality.eigenvector(karate)
		let ranked = scores.ranked
		#expect(ranked[0].node == "34")
		#expect(ranked[1].node == "1")
		#expect(ranked[2].node == "3")
	}

	@Test("PageRank agrees with eigenvector on who leads the karate club")
	func pageRankAgrees() throws {
		// Two different methods; if they disagreed on the top two, one is wrong.
		let ranked = try Centrality.pageRank(karate).ranked
		#expect(Set(ranked.prefix(2).map(\.node)) == Set(["34", "1"]))
	}

	@Test("Betweenness on the karate club puts node 1 at the top")
	func karateBetweenness() {
		// Node 1 is the instructor and the principal bridge; published
		// normalised betweenness is about 0.438.
		let scores = Centrality.betweenness(karate)
		#expect(scores.ranked.first?.node == "1")
		let value = scores["1"] ?? 0
		#expect(abs(value - 0.4376) < 0.002, "got \(value)")
	}

	@Test("Closeness on the kite favours Fernando and Garth, as published")
	func kiteCloseness() {
		let ranked = Centrality.closeness(kite).ranked
		#expect(Set(ranked.prefix(2).map(\.node)) == Set(["Fernando", "Garth"]))
	}
}

@Suite("Community detection against ground truth")
struct CommunityTests {

	/// The karate club actually split, and Zachary recorded which faction each
	/// member joined. Recovering that split is the benchmark.
	@Test("Louvain separates the instructor from the administrator")
	func separatesFactions() {
		let partition = Community.louvain(karate)
		#expect(partition["1"] != partition["34"])
	}

	@Test("Louvain reaches the modularity the literature reports for this graph")
	func modularityThreshold() {
		// Published Louvain modularity on the karate club is about 0.41–0.42.
		let partition = Community.louvain(karate)
		let score = Community.modularity(karate, partition: partition)
		#expect(score >= 0.38, "modularity \(score) is below what Louvain should reach")
		#expect(score <= 0.45, "modularity \(score) is implausibly high")
	}

	@Test("Recovers most of the actual faction split")
	func recoversGroundTruth() {
		let partition = Community.louvain(karate)
		let instructorCommunity = partition["1"]
		var agree = 0
		for node in 1...34 {
			let predictedWithInstructor = partition[String(node)] == instructorCommunity
			let actuallyWithInstructor =
				ReferenceGraphs.karateInstructorFaction.contains(node)
			if predictedWithInstructor == actuallyWithInstructor { agree += 1 }
		}
		// Louvain finds four communities rather than two, so perfect agreement
		// is not expected; recovering the broad split is.
		#expect(agree >= 24, "agreed with ground truth on only \(agree) of 34")
	}

	@Test("Every node lands in exactly one community")
	func partitionIsTotal() {
		let partition = Community.louvain(karate)
		#expect(partition.communities.count == 34)
		#expect(partition.communityCount >= 2)
		#expect(partition.communityCount <= 8)
	}

	/// Louvain ties constantly, and Swift seeds its hasher per process — so a
	/// tie broken by dictionary order gives a different partition on every
	/// *launch*, which a same-process comparison cannot see. Asserting a fixed
	/// canonical signature is what catches that.
	@Test("The same graph always produces the same partition, across processes")
	func deterministic() {
		let first = Community.louvain(karate)
		let second = Community.louvain(karate)
		#expect(first == second)

		// Community sizes, largest first — stable under renumbering, and
		// recorded here so a cross-process change fails rather than passing.
		let signature = first.groups.map(\.members.count)
		#expect(signature == [12, 11, 6, 5],
				"partition signature changed: \(signature)")

		// And the assignment itself, keyed by two members whose community
		// membership is not in doubt.
		#expect(first["1"] == first["2"])
		#expect(first["34"] == first["33"])
		#expect(first["1"] != first["34"])
	}

	@Test("Modularity of everything-in-one-community is zero")
	func trivialPartition() {
		let single = NodePartition<String>(Dictionary(
			uniqueKeysWithValues: karate.nodes.map { ($0, 0) }))
		#expect(abs(Community.modularity(karate, partition: single)) < 1e-9)
	}

	@Test("Modularity of every-node-alone is negative")
	func singletonPartition() {
		let singletons = NodePartition<String>(Dictionary(
			uniqueKeysWithValues: karate.nodes.enumerated().map { ($0.element, $0.offset) }))
		#expect(Community.modularity(karate, partition: singletons) < 0)
	}
}

@Suite("k-core")
struct KCoreTests {

	/// The karate club's maximum core is 4, a published property.
	@Test("Karate club has a maximum core of four")
	func maximumCore() {
		let cores = Community.kCore(karate)
		let peak = cores.scores.values.max() ?? 0
		#expect(peak.isEqual(to: 4), "max core \(peak)")
	}

	@Test("The kite's pendant node is in the zero or one core")
	func pendantNode() throws {
		// Jane has a single tie, to Ike.
		let cores = Community.kCore(kite)
		let jane = try #require(cores["Jane"])
		let diane = try #require(cores["Diane"])
		#expect(jane <= 1)
		#expect(diane > jane)
	}

	@Test("Core numbers never exceed degree")
	func coreBoundedByDegree() throws {
		let cores = Community.kCore(karate)
		let degrees = Centrality.degree(karate)
		for node in karate.nodes {
			let core = try #require(cores[node], "no core number for \(node)")
			let degree = try #require(degrees[node], "no degree for \(node)")
			#expect(core <= degree)
		}
	}
}

@Suite("The measures added for the TUI")
struct AdditionalMetricTests {

	/// Clustering is the complement of bridging. Heather bridges the kite's
	/// tail to its body, so her connections should know each other least.
	@Test("Clustering is lowest for the kite's bridge")
	func clusteringFindsTheBridge() {
		let scores = Centrality.clustering(kite)
		let heather = scores["Heather"] ?? 1
		let andre = scores["Andre"] ?? 0
		#expect(heather < andre, "Heather \(heather), Andre \(andre)")
	}

	@Test("A node with one tie has no clustering to speak of")
	func pendantClustering() {
		#expect(Centrality.clustering(kite)["Jane"]?.isEqual(to: 0) == true)
	}

	@Test("Clustering stays within zero and one for every node")
	func clusteringInRange() {
		for graph in [kite, karate] {
			for node in graph.nodes {
				let value = Centrality.clustering(graph)[node] ?? -1
				#expect(value >= 0 && value <= 1, "\(node) scored \(value)")
			}
		}
	}

	/// Harmonic centrality keeps working where closeness cannot: an unreachable
	/// classmate contributes nothing rather than an infinity.
	@Test("Harmonic centrality survives a disconnected graph")
	func harmonicHandlesDisconnection() throws {
		let split = WeightedGraph(unweightedEdges: [("a", "b"), ("c", "d")])
		let scores = Centrality.harmonic(split)
		let score = try #require(scores["a"])
		#expect(score.isFinite)
		#expect(score > 0)
	}

	/// Computed by hand rather than compared against the other implementation,
	/// which would only prove the two agree.
	///
	/// Jane's single tie is to Ike. Her distances to the other nine are
	/// 1, 2, 3, 3, 4, 4, 4, 4, 4, so the sum of reciprocals is
	/// 1 + 1/2 + 2/3 + 5/4 = 3.41667, and over nine that is 0.37963.
	@Test("Harmonic centrality matches a hand computation")
	func harmonicByHand() {
		let jane = Centrality.harmonic(kite)["Jane"] ?? 0
		#expect(abs(jane - 0.37963) < 0.0001, "got \(jane)")
	}

	/// They agree on the leaders and on the tail, and part company in the
	/// middle — which is the reason to have both. Closeness divides by a mean
	/// distance, so being near the far end of the graph helps; harmonic sums
	/// reciprocals, so near neighbours dominate. Heather, who joins the kite's
	/// body to its tail, is fourth on closeness and sixth on harmonic.
	@Test("Harmonic and closeness agree at the ends and differ in the middle")
	func harmonicVersusCloseness() {
		let harmonic = Centrality.harmonic(kite).ranked.map(\.node)
		let closeness = Centrality.closeness(kite).ranked.map(\.node)

		#expect(Set(harmonic.prefix(3)) == Set(closeness.prefix(3)))
		#expect(Array(harmonic.suffix(4)) == Array(closeness.suffix(4)))

		let harmonicHeather = harmonic.firstIndex(of: "Heather") ?? 0
		let closenessHeather = closeness.firstIndex(of: "Heather") ?? 0
		#expect(harmonicHeather > closenessHeather,
				"closeness should favour the bridge to the tail")
	}

	@Test("The karate club is one connected component")
	func karateIsConnected() {
		#expect(Community.connectedComponents(karate).communityCount == 1)
	}

	/// A component is not a community: a hundred classmates with no recorded
	/// tie are a hundred components, not one group.
	@Test("Isolated nodes are their own components")
	func isolatedComponents() {
		let graph = WeightedGraph(
			unweightedEdges: [("a", "b")], isolatedNodes: ["x", "y"])
		let components = Community.connectedComponents(graph)
		#expect(components.communityCount == 3)
		#expect(components["x"] != components["y"])
	}

}
