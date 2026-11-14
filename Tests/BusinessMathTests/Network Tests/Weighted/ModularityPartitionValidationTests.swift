//
//  ModularityPartitionValidationTests.swift
//  BusinessMath
//
//  Step 4, change 3 of NetworkWeightedGraph.md (ADR-009): `Community.modularity` refuses a
//  partition that does not cover exactly the graph's nodes. It used to skip a node the partition
//  left out, as if the node were not in the graph, and not to notice a node the graph does not
//  have, so a partial partition scored as though it were whole. The unweighted
//  `Graph.modularity(of:)` has always returned `nil` for both.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

/// The refusal a call throws, or `nil` if it did not throw `partitionDoesNotMatchGraph`.
private func refusal(_ body: () throws -> Void) -> (missing: [String], unknown: [String])? {
	do {
		try body()
		return nil
	} catch GraphMeasureError.partitionDoesNotMatchGraph(let missing, let unknown) {
		return (missing, unknown)
	} catch {
		return nil
	}
}

/// A frozen copy of the scoring as it stood before this change, kept as an oracle: for a complete
/// partition the new code must return exactly what the old returned. The old code skipped
/// unassigned nodes; given a complete partition it never does.
private func legacyModularity(_ graph: WeightedGraph<String>, _ partition: NodePartition<String>) -> Double {
	let total = graph.totalWeight
	guard total > 0 else { return 0 }
	var internalWeight: [Int: Double] = [:]
	var degreeSum: [Int: Double] = [:]
	for (index, node) in graph.nodes.enumerated() {
		guard let community = partition[node] else { continue }
		degreeSum[community, default: 0] += graph.weightedDegree(index)
		for (neighbour, weight) in graph.adjacency[index] {
			guard let other = partition[graph.nodes[neighbour]], other == community else { continue }
			internalWeight[community, default: 0] += weight
		}
	}
	var score = 0.0
	for community in internalWeight.keys.sorted() {
		let inside = internalWeight[community] ?? 0
		let degree = degreeSum[community] ?? 0
		score += (inside / 2) / total - pow(degree / (2 * total), 2)
	}
	for community in degreeSum.keys.sorted() where internalWeight[community] == nil {
		let degree = degreeSum[community] ?? 0
		score -= pow(degree / (2 * total), 2)
	}
	return score
}

private let twoPairs = WeightedGraph(unweightedEdges: [("a", "b"), ("c", "d"), ("b", "c")])

@Suite("Modularity partition validation")
struct ModularityPartitionValidationTests {

	@Test("A complete partition scores as before: the documented example, 1/6")
	func completePartitionScores() throws {
		let split = NodePartition(["a": 0, "b": 0, "c": 1, "d": 1])
		let value = try Community.modularity(twoPairs, partition: split)
		#expect(abs(value - 1.0 / 6.0) < 1e-12)
	}

	@Test("A partition that leaves a node out is refused, naming the node; it used to be scored as if the node were absent")
	func partialPartitionRefused() {
		let partial = NodePartition(["a": 0, "b": 0, "c": 1])
		let found = refusal { _ = try Community.modularity(twoPairs, partition: partial) }
		#expect(found?.missing == ["d"])
		#expect(found?.unknown == [])
	}

	@Test("A partition that mentions a node the graph does not have is refused, naming it")
	func foreignNodeRefused() {
		let foreign = NodePartition(["a": 0, "b": 0, "c": 1, "d": 1, "zed": 2])
		let found = refusal { _ = try Community.modularity(twoPairs, partition: foreign) }
		#expect(found?.missing == [])
		#expect(found?.unknown == ["zed"])
	}

	@Test("A partition that is both partial and foreign names both, in node order")
	func bothDefects() {
		let both = NodePartition(["b": 0, "c": 1, "y": 3, "x": 2])
		let found = refusal { _ = try Community.modularity(twoPairs, partition: both) }
		#expect(found?.missing == ["a", "d"])
		#expect(found?.unknown == ["x", "y"])
	}

	@Test("An empty partition of a non-empty graph is refused: every node is missing")
	func emptyPartitionRefused() {
		let found = refusal { _ = try Community.modularity(twoPairs, partition: NodePartition([:])) }
		#expect(found?.missing == ["a", "b", "c", "d"])
	}

	@Test("An empty graph accepts the empty partition and refuses a non-empty one")
	func emptyGraph() throws {
		let empty = try WeightedGraph<String>(edges: [])
		#expect(try Community.modularity(empty, partition: NodePartition([:])).isEqual(to: 0))
		let found = refusal { _ = try Community.modularity(empty, partition: NodePartition(["a": 0])) }
		#expect(found?.unknown == ["a"])
	}

	@Test("The check comes before the no-edge shortcut: an edgeless graph with a partial partition is refused, with a full one scores zero")
	func validationPrecedesEdgelessShortcut() throws {
		let edgeless = WeightedGraph<String>(unweightedEdges: [], isolatedNodes: ["a", "b"])
		#expect(refusal { _ = try Community.modularity(edgeless, partition: NodePartition(["a": 0])) } != nil)
		#expect(try Community.modularity(edgeless, partition: NodePartition(["a": 0, "b": 1])).isEqual(to: 0))
	}

	@Test("Every assignment of each of six nodes to community 0, community 1 or nothing: refused exactly when a node is unassigned, and otherwise equal to the old scoring bit for bit")
	func exhaustive() throws {
		let graph = WeightedGraph(unweightedEdges: [
			("n0", "n1"), ("n1", "n2"), ("n2", "n0"), ("n3", "n4"), ("n4", "n5"), ("n2", "n3"),
		])
		let names = graph.nodes
		var refused = 0
		var scored = 0
		for code in 0..<729 {
			var assignment: [String: Int] = [:]
			var rest = code
			var absent: [String] = []
			for name in names {
				let digit = rest % 3
				rest /= 3
				if digit == 2 { absent.append(name) } else { assignment[name] = digit }
			}
			let partition = NodePartition(assignment)
			if absent.isEmpty {
				let value = try Community.modularity(graph, partition: partition)
				let old = legacyModularity(graph, partition)
				#expect(value.bitPattern == old.bitPattern, "code \(code)")
				scored += 1
			} else {
				let found = refusal { _ = try Community.modularity(graph, partition: partition) }
				#expect(found?.missing == absent, "code \(code)")
				refused += 1
			}
		}
		#expect(scored == 64)
		#expect(refused == 665)
	}

	@Test("A foreign key is refused however complete the rest is, over seeded random graphs and the partitions Louvain and components return")
	func foreignOverRandomGraphs() throws {
		for seed in UInt64(1)...UInt64(8) {
			let graph = try Synthetic.erdosRenyi(seed: seed, count: 30, edgeCount: 50)
			for partition in [Community.louvain(graph), Community.connectedComponents(graph)] {
				// A partition the library itself produced is always valid.
				#expect(try Community.modularity(graph, partition: partition).isFinite)
				var polluted = partition.communities
				polluted["not-a-node"] = 0
				let found = refusal { _ = try Community.modularity(graph, partition: NodePartition(polluted)) }
				#expect(found?.unknown == ["not-a-node"], "seed \(seed)")
				#expect(found?.missing == [], "seed \(seed)")
			}
		}
	}

	@Test("Community numbers are labels: negative and large numbers are fine, so only the node set is checked")
	func labelsAreArbitrary() throws {
		let relabelled = NodePartition(["a": -7, "b": -7, "c": 1_000_000, "d": 1_000_000])
		let value = try Community.modularity(twoPairs, partition: relabelled)
		#expect(abs(value - 1.0 / 6.0) < 1e-12)
	}

	@Test("The error compares by what it names")
	func errorEquality() {
		let one = GraphMeasureError.partitionDoesNotMatchGraph(missing: ["a"], unknown: [])
		#expect(one == GraphMeasureError.partitionDoesNotMatchGraph(missing: ["a"], unknown: []))
		#expect(one != GraphMeasureError.partitionDoesNotMatchGraph(missing: ["b"], unknown: []))
		#expect(one != GraphMeasureError.partitionDoesNotMatchGraph(missing: ["a"], unknown: ["z"]))
		#expect(one != GraphMeasureError.invalidDamping(1.5))
	}
}
