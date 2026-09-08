//
//  ProjectionAndCommunityTests.swift
//  BusinessMath
//
//  Bipartite projection, modularity, and Louvain.
//
//  ## Modularity has an identity to check against
//
//  Putting every node in one community gives **exactly zero**, and not approximately:
//  the observed edge weight sums to `2m` and the expected weight sums to `(2m)²/2m`, so
//  `Q = 1 − 1`. Any error in the degree bookkeeping, the `2m` normalisation, or the
//  community test breaks it, and no reference implementation is needed to notice.
//
//  Putting every node alone gives a negative number, which is the other end of the same
//  identity — a partition can be worse than no partition at all.
//
//  ## The projection's edge case is a person, not a number
//
//  Eve belongs to a basket nobody else does. She has no edges after projection, and the
//  natural implementation drops her — silently losing a customer from a segmentation.
//  `isolatedMembersSurvive` exists because that failure looks like nothing at all.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Projection and community")
struct ProjectionAndCommunityTests {

	private static let memberships: [String: Set<String>] = [
		"Alice": ["b1", "b2", "b3"],
		"Bob": ["b1", "b2"],
		"Carol": ["b2", "b3", "b4"],
		"Dave": ["b4"],
		"Eve": ["b5"],
	]

	/// Two triangles joined through a single bridge, undirected.
	private static var bridged: Graph<String> {
		let pairs: [(String, String)] = [
			("a", "b"), ("a", "c"), ("b", "c"), ("c", "d"),
			("d", "e"), ("e", "f"), ("e", "g"), ("f", "g"),
		]
		var edges: [(String, String)] = []
		for (from, to) in pairs { edges.append((from, to)); edges.append((to, from)) }
		return Graph(edges: edges)
	}

	// MARK: - Projection

	@Test("Shared-membership counts are the projection's simplest weighting")
	func projectionByCount() throws {
		let projected = try #require(BipartiteProjection(memberships: Self.memberships,
														 weighting: .sharedCount))
		let expected: [(String, String, Double)] = [
			("Alice", "Bob", 2), ("Alice", "Carol", 2),
			("Bob", "Carol", 1), ("Carol", "Dave", 1),
		]
		var checked = 0
		for (a, b, weight) in expected {
			let got = projected.weight(between: a, and: b)
			#expect(Swift.abs(got - weight) < 1e-12, "\(a)–\(b): \(got), expected \(weight)")
			// Projection is symmetric: sharing is not directional.
			#expect(Swift.abs(projected.weight(between: b, and: a) - got) < 1e-12,
					"\(a)–\(b) is not symmetric")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 pairs were checked")
		// Alice and Dave share nothing.
		#expect(projected.weight(between: "Alice", and: "Dave") == 0)
	}

	@Test("Jaccard and cosine weightings match an independent computation")
	func projectionWeightings() throws {
		let jaccard = try #require(BipartiteProjection(memberships: Self.memberships,
													   weighting: .jaccard))
		let cosine = try #require(BipartiteProjection(memberships: Self.memberships,
													  weighting: .cosine))
		let expected: [(String, String, Double, Double)] = [
			("Alice", "Bob", 0.6666666667, 0.8164965809),
			("Alice", "Carol", 0.5, 0.6666666667),
			("Bob", "Carol", 0.25, 0.4082482905),
			("Carol", "Dave", 0.3333333333, 0.5773502692),
		]
		var checked = 0
		for (a, b, jac, cos) in expected {
			#expect(Swift.abs(jaccard.weight(between: a, and: b) - jac) < 1e-9,
					"\(a)–\(b) jaccard \(jaccard.weight(between: a, and: b))")
			#expect(Swift.abs(cosine.weight(between: a, and: b) - cos) < 1e-9,
					"\(a)–\(b) cosine \(cosine.weight(between: a, and: b))")
			checked += 1
		}
		#expect(checked == 4)
	}

	@Test("A member who shares nothing survives the projection")
	func isolatedMembersSurvive() throws {
		// Eve is in a basket of her own. She has no edges, and dropping her would remove a
		// customer from a segmentation without any error — the count would simply be one
		// lower than the data, which nothing downstream is placed to notice.
		let projected = try #require(BipartiteProjection(memberships: Self.memberships,
														 weighting: .sharedCount))
		#expect(projected.members.contains("Eve"), "Eve was dropped: \(projected.members)")
		#expect(projected.members.count == 5, "got \(projected.members.count) members")
		#expect(projected.neighbors(of: "Eve").isEmpty, "Eve should have no edges")
	}

	@Test("Projection refuses input it cannot project")
	func projectionRefusals() {
		let empty: [String: Set<String>] = [:]
		#expect(BipartiteProjection(memberships: empty, weighting: .jaccard) == nil)
		// A member with no memberships has no basis for similarity with anyone, and a
		// Jaccard denominator of zero is not a similarity of zero.
		#expect(BipartiteProjection(memberships: ["A": Set<String>(), "B": ["x"]],
									weighting: .jaccard) == nil)
	}

	// MARK: - Modularity

	@Test("One community scores exactly zero, by identity")
	func modularityOfOneCommunity() throws {
		// Σ A = 2m and Σ k·k/(2m) = 2m, so Q = 1 − 1. Exact, and it needs no reference.
		let all = Set(Self.bridged.nodes)
		let q = try #require(Self.bridged.modularity(of: [all]))
		#expect(Swift.abs(q) < 1e-12, "one community scored \(q), not zero")
	}

	@Test("Modularity matches an independent computation")
	func modularityValues() throws {
		let graph = Self.bridged
		let split: [Set<String>] = [["a", "b", "c", "d"], ["e", "f", "g"]]
		let mirrored: [Set<String>] = [["a", "b", "c"], ["d", "e", "f", "g"]]
		let singletons: [Set<String>] = graph.nodes.map { [$0] }

		let good = try #require(graph.modularity(of: split))
		#expect(Swift.abs(good - 0.3671875) < 1e-10, "split scored \(good)")
		// The graph is symmetric about the bridge, so which side d joins cannot matter.
		let other = try #require(graph.modularity(of: mirrored))
		#expect(Swift.abs(good - other) < 1e-12,
				"a symmetric graph gave \(good) and \(other) for mirrored partitions")
		// Every node alone is worse than no partition at all.
		let apart = try #require(graph.modularity(of: singletons))
		#expect(Swift.abs(apart - (-0.1484375)) < 1e-10, "singletons scored \(apart)")
		#expect(apart < 0, "a partition can be worse than nothing, got \(apart)")
	}

	@Test("Modularity refuses a partition that is not one")
	func modularityRefusals() {
		let graph = Self.bridged
		// A node in two communities.
		#expect(graph.modularity(of: [["a", "b"], ["b", "c"]]) == nil)
		// A node in none.
		#expect(graph.modularity(of: [["a", "b"]]) == nil)
		// A node that is not in the graph.
		#expect(graph.modularity(of: [Set(graph.nodes).union(["ghost"])]) == nil)
		#expect(graph.modularity(of: []) == nil)
	}

	// MARK: - Louvain

	@Test("Louvain finds the two clusters the graph obviously has")
	func louvainFindsTheSplit() throws {
		let graph = Self.bridged
		let communities = try #require(graph.louvainCommunities())
		#expect(communities.count == 2, "got \(communities.count) communities: \(communities)")

		// Every node placed exactly once.
		let placed = communities.reduce(into: Set<String>()) { $0.formUnion($1) }
		#expect(placed == Set(graph.nodes), "partition covered \(placed)")
		let total = communities.reduce(0) { $0 + $1.count }
		#expect(total == graph.nodes.count, "a node was placed twice")

		// The two triangles must not be split across communities.
		for triangle in [Set(["a", "b", "c"]), Set(["e", "f", "g"])] {
			let holding = communities.filter { !$0.isDisjoint(with: triangle) }
			#expect(holding.count == 1, "triangle \(triangle) was split across \(holding)")
		}
		let quality = try #require(graph.modularity(of: communities))
		#expect(Swift.abs(quality - 0.3671875) < 1e-9,
				"Louvain reached Q = \(quality), the optimum here is 0.3671875")
	}

	@Test("Louvain is deterministic whatever order the graph was built in")
	func louvainIsDeterministic() {
		// Greedy modularity maximisation visits nodes in some order and the answer can
		// depend on it, which is why the node order is fixed by `Graph` rather than left
		// to Dictionary iteration. Four insertion orders, one answer.
		let pairs: [(String, String)] = [
			("a", "b"), ("a", "c"), ("b", "c"), ("c", "d"),
			("d", "e"), ("e", "f"), ("e", "g"), ("f", "g"),
		]
		var results: [[Set<String>]] = []
		for shift in 0..<4 {
			var rotated = pairs
			let cut = shift % rotated.count
			rotated = Array(rotated[cut...] + rotated[..<cut])
			var edges: [(String, String)] = []
			for (from, to) in rotated { edges.append((from, to)); edges.append((to, from)) }
			if let found = Graph(edges: edges).louvainCommunities() {
				results.append(found.map { $0 }.sorted { ($0.min() ?? "") < ($1.min() ?? "") })
			}
		}
		#expect(results.count == 4, "only \(results.count) runs produced communities")
		for (index, result) in results.enumerated() {
			#expect(result == results[0], "ordering \(index) gave \(result)")
		}
	}

	@Test("A graph with no structure is not forced into communities")
	func louvainOnStructurelessGraphs() {
		// A single triangle is one community and splitting it lowers modularity, so a
		// method that always returns more than one is reporting structure that is not
		// there.
		var edges: [(String, String)] = []
		for (from, to) in [("x", "y"), ("y", "z"), ("x", "z")] {
			edges.append((from, to)); edges.append((to, from))
		}
		let triangle = Graph(edges: edges)
		let found = triangle.louvainCommunities()
		#expect(found?.count == 1, "a clique should be one community, got \(found ?? [])")
		// A graph with no edges has no modularity to maximise.
		#expect(Graph(adjacency: ["a": [], "b": []]).louvainCommunities() == nil)
	}
}
