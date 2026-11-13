//
//  NodeValueTests.swift
//  BusinessMath
//
//  NodeScores, NodePartition, NodeSelection: ordering, limits, empty and non-finite inputs,
//  and seeded properties. Ported from SwiftGraphMetrics (ValueTests, RegistryTests'
//  NodeScores suite, the value-type mutation audit) and extended. Synthetic data only.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

/// Scores drawn from quarters, so ties are common and every value is exact in binary.
private func randomScores(seed: UInt64, count: Int) -> NodeScores<String> {
	let rng = SeededRNG(seed: seed)
	var table: [String: Double] = [:]
	for index in 0..<count {
		table["n\(index)"] = (rng.next() * 6).rounded(.down) / 4
	}
	return NodeScores(table)
}

@Suite("Node values: kinds and NodeScores")
struct NodeScoresTests {

	@Test("Kinds are stable strings")
	func kinds() {
		#expect(NodeScores<String>.kind == "scores")
		#expect(NodePartition<String>.kind == "partition")
		#expect(NodeSelection<String>.kind == "selection")
		#expect(DiagnosedScores<String>.kind == "scores")
		#expect(NodeScores<Int>.kind == "scores")
	}

	@Test("Ranks descending with ties broken by node ascending, whatever the insertion order")
	func rankingOrder() {
		let scores = NodeScores(["d": 1, "b": 5, "a": 5, "c": 1, "e": 9])
		#expect(scores.ranked.map(\.node) == ["e", "a", "b", "c", "d"])
		#expect(scores.ranked.map(\.score) == [9, 5, 5, 1, 1])
		let small = NodeScores(["b": 1, "a": 1, "c": 2])
		#expect(small.ranked.map(\.node) == ["c", "a", "b"])
	}

	@Test("Top and bottom read from opposite ends")
	func topAndBottom() {
		let scores = NodeScores(["a": 3, "b": 2, "c": 1])
		#expect(scores.top(2).map(\.node) == ["a", "b"])
		#expect(scores.bottom(2).map(\.node) == ["c", "b"])
		#expect(scores.top(1).map(\.node) == ["a"])
		#expect(scores.bottom(1).map(\.node) == ["c"])
		#expect(scores.top(2).map(\.score) == [3, 2])
		#expect(scores.bottom(2).map(\.score) == [1, 2])
	}

	@Test("Limits: zero and negative are empty, exact count is everything, more is clamped")
	func limits() {
		let scores = NodeScores(["a": 3, "b": 2, "c": 1])
		#expect(scores.top(0).isEmpty)
		#expect(scores.bottom(0).isEmpty)
		#expect(scores.top(-1).isEmpty)
		#expect(scores.bottom(-5).isEmpty)
		#expect(scores.top(3).map(\.node) == ["a", "b", "c"])
		#expect(scores.bottom(3).map(\.node) == ["c", "b", "a"])
		#expect(scores.top(50).count == 3)
		#expect(scores.bottom(50).count == 3)
		#expect(scores.top(Int.max).count == 3)
		#expect(scores.bottom(Int.min).isEmpty)
	}

	@Test("Bottom breaks ties in the reverse of ranked order")
	func bottomTies() {
		let scores = NodeScores(["a": 1, "b": 1, "c": 1])
		#expect(scores.ranked.map(\.node) == ["a", "b", "c"])
		#expect(scores.bottom(2).map(\.node) == ["c", "b"])
	}

	@Test("An empty table ranks to nothing and looks up nil")
	func empty() {
		let scores = NodeScores<String>([:])
		#expect(scores.ranked.isEmpty)
		#expect(scores.top(3).isEmpty)
		#expect(scores.bottom(3).isEmpty)
		#expect(scores["a"] == nil)
	}

	@Test("Subscript reads one node's score")
	func lookup() {
		let scores = NodeScores(["a": 3.5])
		#expect(scores["a"]?.isEqual(to: 3.5) == true)
		#expect(scores["zzz"] == nil)
	}

	@Test("Negative and infinite scores order as numbers do")
	func extremes() {
		let scores = NodeScores([
			"a": -2.0, "b": Double.infinity, "c": -Double.infinity, "d": 0.0, "e": -0.0,
		])
		let order = scores.ranked.map(\.node)
		#expect(order.first == "b")
		#expect(order.last == "c")
		// Zero and negative zero compare equal, so they tie and fall back to node order.
		#expect(order == ["b", "d", "e", "a", "c"])
	}

	@Test("A NaN score still ranks every node once, and cannot be stored in an envelope")
	func nanScore() throws {
		let scores = NodeScores(["a": Double.nan, "b": 1, "c": 2, "d": Double.nan, "e": 0.5])
		let ranked = scores.ranked
		#expect(ranked.count == 5)
		#expect(Set(ranked.map(\.node)) == ["a", "b", "c", "d", "e"])
		#expect(scores.top(2).count == 2)
		#expect(scores.bottom(9).count == 5)
		// JSON cannot represent NaN or infinity, so a stored result never holds one.
		#expect(throws: (any Error).self) { try MetricEnvelope(scores) }
		#expect(throws: (any Error).self) { try JSONEncoder().encode(scores) }
		#expect(throws: (any Error).self) { try MetricEnvelope(NodeScores(["a": Double.infinity])) }
		#expect(throws: (any Error).self) { try MetricEnvelope(NodeScores(["a": -Double.infinity])) }
	}

	@Test("Seeded: ranked is a permutation, non-increasing, ties ascending; top and bottom agree",
		arguments: [UInt64(1), 2, 3, 4, 5, 6, 7, 8])
	func rankingProperties(seed: UInt64) {
		let scores = randomScores(seed: seed, count: 40)
		let ranked = scores.ranked
		#expect(ranked.count == 40)
		#expect(Set(ranked.map(\.node)) == Set(scores.scores.keys))
		for (before, after) in zip(ranked, ranked.dropFirst()) {
			#expect(before.score >= after.score, "seed \(seed)")
			if before.score == after.score {
				#expect(before.node < after.node, "seed \(seed)")
			}
		}
		for entry in ranked {
			#expect(scores[entry.node] == entry.score, "seed \(seed)")
		}
		for limit in [0, 1, 7, 39, 40, 41] {
			let top = scores.top(limit)
			let bottom = scores.bottom(limit)
			let expected = min(limit, 40)
			#expect(top.count == expected, "seed \(seed) limit \(limit)")
			#expect(bottom.count == expected, "seed \(seed) limit \(limit)")
			#expect(top.map(\.node) == ranked.prefix(expected).map(\.node), "seed \(seed)")
			#expect(bottom.map(\.node) == ranked.suffix(expected).reversed().map(\.node), "seed \(seed)")
		}
	}

	@Test("Seeded: the ranking does not depend on dictionary construction order",
		arguments: [UInt64(11), 12, 13, 14])
	func orderIndependence(seed: UInt64) {
		let scores = randomScores(seed: seed, count: 30)
		let rebuilt = NodeScores(Dictionary(uniqueKeysWithValues: scores.scores.sorted { $0.key > $1.key }))
		#expect(rebuilt == scores)
		#expect(rebuilt.ranked.map(\.node) == scores.ranked.map(\.node))
	}
}

@Suite("Node values: NodePartition and NodeSelection")
struct PartitionAndSelectionTests {

	@Test("Partition groups are largest first with members sorted")
	func groups() {
		let partition = NodePartition(["a": 0, "b": 1, "c": 1, "d": 1, "e": 2, "f": 2])
		#expect(partition.communityCount == 3)
		#expect(partition.groups.map(\.community) == [1, 2, 0])
		#expect(partition.groups.map(\.members) == [["b", "c", "d"], ["e", "f"], ["a"]])
		#expect(partition["a"] == 0)
		#expect(partition["zzz"] == nil)
	}

	@Test("Groups of equal size are ordered by community number, ascending")
	func equalSizedGroups() {
		let partition = NodePartition(["a": 7, "b": 7, "c": 2, "d": 2, "e": 5, "f": 5, "g": 9])
		#expect(partition.groups.map(\.community) == [2, 5, 7, 9])
		#expect(partition.groups.map { $0.members.count } == [2, 2, 2, 1])
		#expect(partition.groups.map(\.members) == [["c", "d"], ["e", "f"], ["a", "b"], ["g"]])
	}

	@Test("An empty partition has no groups and no communities")
	func emptyPartition() {
		let partition = NodePartition<String>([:])
		#expect(partition.groups.isEmpty)
		#expect(partition.communityCount == 0)
		#expect(partition["a"] == nil)
	}

	@Test("Negative community numbers are ordinary identifiers")
	func negativeCommunity() {
		let partition = NodePartition(["a": -1, "b": -1, "c": 0])
		#expect(partition.communityCount == 2)
		#expect(partition.groups.map(\.community) == [-1, 0])
		#expect(partition["a"] == -1)
	}

	@Test("Seeded: groups partition the nodes exactly and are ordered by size then number",
		arguments: [UInt64(1), 2, 3, 4, 5])
	func groupProperties(seed: UInt64) {
		let rng = SeededRNG(seed: seed)
		var table: [String: Int] = [:]
		for index in 0..<50 { table["n\(index)"] = Int(rng.next() * 6) }
		let partition = NodePartition(table)
		let groups = partition.groups
		#expect(groups.count == partition.communityCount)
		#expect(groups.flatMap(\.members).sorted() == table.keys.sorted())
		for group in groups {
			#expect(group.members == group.members.sorted())
			#expect(group.members.allSatisfy { partition[$0] == group.community })
		}
		for (before, after) in zip(groups, groups.dropFirst()) {
			let sizeBefore = before.members.count
			let sizeAfter = after.members.count
			#expect(sizeBefore >= sizeAfter, "seed \(seed)")
			if sizeBefore == sizeAfter {
				#expect(before.community < after.community, "seed \(seed)")
			}
		}
	}

	@Test("A selection keeps its picks in order with their marginal gains")
	func selection() {
		let selection = NodeSelection<String>(picks: [("b", 3.5), ("a", 1.25)])
		#expect(selection.picks.map(\.node) == ["b", "a"])
		#expect(selection.nodes == ["b", "a"])
		let gains: [Double] = selection.picks.map(\.marginalGain)
		#expect(gains.count == 2)
		#expect(gains.first?.isEqual(to: 3.5) == true)
		#expect(gains.last?.isEqual(to: 1.25) == true)
		#expect(selection.totalGain.isEqual(to: 4.75))
	}

	@Test("The two initialisers agree, and an empty selection is empty")
	func initialisers() {
		let pairs = NodeSelection<String>(picks: [("b", 3.5), ("a", 1.25)])
		let picks = NodeSelection<String>([
			NodeSelection<String>.Pick(node: "b", marginalGain: 3.5),
			NodeSelection<String>.Pick(node: "a", marginalGain: 1.25),
		])
		#expect(pairs == picks)
		let empty = NodeSelection<String>(picks: [])
		#expect(empty.nodes.isEmpty)
		#expect(empty.picks.isEmpty)
		#expect(empty.totalGain.isEqual(to: 0))
		#expect(empty == NodeSelection<String>([]))
	}

	@Test("Order is part of identity")
	func orderMatters() {
		let one = NodeSelection<String>(picks: [("a", 1), ("b", 2)])
		let two = NodeSelection<String>(picks: [("b", 2), ("a", 1)])
		#expect(one != two)
		#expect(one.totalGain.isEqual(to: two.totalGain))
	}
}
