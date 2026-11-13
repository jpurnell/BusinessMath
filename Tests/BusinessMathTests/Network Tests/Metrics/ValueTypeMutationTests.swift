//
//  ValueTypeMutationTests.swift
//  BusinessMath
//
//  Written from SwiftGraphMetrics's mutation audit of the first metrics: the value types, the
//  registry listing and the envelope. The reference-implementation half of that file is
//  ReferenceImplementationMutationTests. Ported unchanged in substance; some cases repeat
//  NodeValueTests on purpose, because the audit ran against the registry-era code.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Mutation audit: value types, registry listing and envelope")
struct ValueTypeMutationTests {

	@Test("bottom(0) is empty, and bottom reads the lowest first")
	func bottomZero() {
		let scores = NodeScores(["a": 3, "b": 2, "c": 1])
		#expect(scores.bottom(0).isEmpty)
		#expect(scores.top(0).isEmpty)
		#expect(scores.bottom(1).map(\.node) == ["c"])
		#expect(scores.bottom(3).map(\.node) == ["c", "b", "a"])
	}

	@Test("Ranking is by score descending, ties by node ascending, whatever the insertion order")
	func rankingOrder() {
		let scores = NodeScores(["d": 1, "b": 5, "a": 5, "c": 1, "e": 9])
		#expect(scores.ranked.map(\.node) == ["e", "a", "b", "c", "d"])
		#expect(scores.ranked.map(\.score) == [9, 5, 5, 1, 1])
	}

	/// Two groups of the same size are ordered by community number, ascending.
	@Test("Groups of equal size are ordered by community number")
	func equalSizedGroups() {
		let partition = NodePartition(["a": 7, "b": 7, "c": 2, "d": 2, "e": 5, "f": 5, "g": 9])
		#expect(partition.groups.map(\.community) == [2, 5, 7, 9])
		#expect(partition.groups.map { $0.members.count } == [2, 2, 2, 1])
		#expect(partition.groups.first?.members == ["c", "d"])
	}

	@Test("The registry lists its metrics in identifier order")
	func availableIsSorted() {
		let identifiers = MetricRegistry<String>.standard.available.map(\.identifier)
		#expect(identifiers == identifiers.sorted())
		#expect(identifiers.count == Set(identifiers).count)
		#expect(identifiers.first == "betweenness-centrality")
	}

	/// A null payload is a legitimate JSON value and must survive a round trip.
	@Test("A null payload decodes as null and re-encodes")
	func nullPayload() throws {
		let json = #"{"kind":"nothing","payload":null}"#
		let envelope = try JSONDecoder().decode(MetricEnvelope.self, from: Data(json.utf8))
		#expect(envelope.payload == .null)
		let again = try JSONDecoder().decode(
			MetricEnvelope.self, from: try JSONEncoder().encode(envelope))
		#expect(again == envelope)
		#expect(try JSONDecoder().decode(JSONValue.self, from: Data("null".utf8)) == .null)
		#expect(try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8)) == .bool(true))
		#expect(try JSONDecoder().decode(JSONValue.self, from: Data("1.5".utf8)) == .number(1.5))
		#expect(try JSONDecoder().decode(JSONValue.self, from: Data("[null,\"x\"]".utf8))
			== .array([.null, .string("x")]))
	}

	@Test("Edge count and neighbour order are those of the sorted, merged edge list")
	func graphInvariants() throws {
		let g = try WeightedGraph(edges: [("c", "a", 1.0), ("b", "a", 2.0), ("a", "d", 1.0), ("b", "c", 1.0)])
		#expect(g.edgeCount == 4)
		let a = try #require(g.indexOf["a"])
		let b = try #require(g.indexOf["b"])
		#expect(g.adjacency[a].map(\.neighbour) == [1, 2, 3])
		#expect(g.adjacency[b].map(\.neighbour) == [0, 2])
		#expect(g.totalWeight.isEqual(to: 5))
	}
}
