//
//  UnweightedLouvainTieMarginTests.swift
//  BusinessMath
//
//  Step 4, change 4 of NetworkWeightedGraph.md (ADR-009): the unweighted `Graph.louvainCommunities`
//  moves a node only if another community beats the best so far by more than the weighted
//  Louvain's 1e-12 margin, expressed in the unweighted gain's units. Without it, a tie that is exact
//  on paper is decided by floating-point rounding, and the two implementations split `random3` of
//  the cross-check differently.
//

import Foundation
import Testing
import SwiftDeterminism
import TestSupport
@testable import BusinessMath

@Suite("Unweighted Louvain move margin")
struct UnweightedLouvainTieMarginTests {

	/// `twiceEdges` is 20 and the node's degree 2, so the gain of a community is
	/// `links / 20 - total * 2 / 400` and the weighted code's 1e-12 margin (in units of links) is
	/// 5e-14 here. Community 1 has `shortfall` less total degree than community 0, so its gain
	/// exceeds community 0's by `shortfall / 200`.
	private func chosen(shortfall: Double) -> Int {
		Graph<String>.bestCommunity(
			for: 0, links: [0: 1, 1: 1], communityDegree: [0: 2, 1: 2 - shortfall],
			nodeDegree: 2, twiceEdges: 20)
	}

	@Test("A candidate better by less than the margin does not take the node: a gain of 1e-14 is a tie")
	func belowMarginStays() {
		#expect(chosen(shortfall: 2e-12) == 0)
	}

	@Test("A candidate better by 4e-14, just under the 5e-14 margin, still does not take it")
	func justBelowMarginStays() {
		#expect(chosen(shortfall: 8e-12) == 0)
	}

	@Test("A candidate better by 6e-14, just over the margin, takes it")
	func justAboveMarginMoves() {
		#expect(chosen(shortfall: 1.2e-11) == 1)
	}

	@Test("A clearly better candidate takes it")
	func clearlyBetterMoves() {
		#expect(chosen(shortfall: 2e-9) == 1)
	}

	@Test("An exactly tied candidate does not take it, and a worse one does not either")
	func tiesAndWorseStay() {
		#expect(chosen(shortfall: 0) == 0)
		#expect(chosen(shortfall: -1) == 0)
	}

	@Test("The margin scales with 2m: the same relative shortfall decides the same way on a graph ten times larger")
	func marginScalesWithGraphSize() {
		// twiceEdges 200: the margin is 5e-15 and the gain difference is shortfall * 2 / 40000.
		func pick(_ shortfall: Double) -> Int {
			Graph<String>.bestCommunity(
				for: 0, links: [0: 10, 1: 10], communityDegree: [0: 20, 1: 20 - shortfall],
				nodeDegree: 2, twiceEdges: 200)
		}
		// difference 1e-15 (shortfall 2e-11) is below 5e-15; 1e-14 (shortfall 2e-10) is above it.
		#expect(pick(2e-11) == 0)
		#expect(pick(2e-10) == 1)
	}

	/// Measured before the margin existed: of seeds 1 to 400, five (39, 132, 270, 275, 297) were split
	/// differently by the two implementations; after it, none of 1 to 5,000 are.
	@Test("Across 400 seeded random connected graphs the two Louvain implementations find the same communities")
	func seededSweepAgrees() {
		var disagreements: [UInt64] = []
		for seed in UInt64(1)...UInt64(400) {
			let edges = randomConnected(seed: seed, count: 10 + Int(seed % 30), extra: Int(seed % 40))
			var adjacency: [String: [String]] = [:]
			for (a, b) in edges {
				adjacency[a, default: []].append(b)
				adjacency[b, default: []].append(a)
			}
			guard let plain = Graph(adjacency: adjacency).louvainCommunities() else { continue }
			let weighted = Community.louvain(WeightedGraph(unweightedEdges: edges))
			if Set(plain) != Set(weighted.groups.map { Set($0.members) }) { disagreements.append(seed) }
		}
		#expect(disagreements.isEmpty, "seeds that disagree: \(disagreements)")
	}
}

private func label(_ index: Int) -> String { index < 10 ? "v0" + String(index) : "v" + String(index) }

/// A random connected graph: a random spanning tree plus extra chords, without duplicates.
private func randomConnected(seed: UInt64, count: Int, extra: Int) -> [(String, String)] {
	var rng = SplitMix64(seed: seed)
	var seen = Set<[Int]>()
	var edges: [(String, String)] = []
	func add(_ a: Int, _ b: Int) {
		guard a != b else { return }
		let key = a < b ? [a, b] : [b, a]
		guard seen.insert(key).inserted else { return }
		edges.append((label(a), label(b)))
	}
	for node in 1..<count { add(node, Int.random(in: 0..<node, using: &rng)) }
	for _ in 0..<extra { add(Int.random(in: 0..<count, using: &rng), Int.random(in: 0..<count, using: &rng)) }
	return edges
}
