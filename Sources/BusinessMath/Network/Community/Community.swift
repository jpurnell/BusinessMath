//
//  Community.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension Graph {

	// MARK: - Modularity

	/// How much better connected a partition's communities are than chance would give.
	///
	/// `Q = (1/2m) Σᵢⱼ [Aᵢⱼ − kᵢkⱼ/2m] δ(cᵢ, cⱼ)` — the observed edge weight inside
	/// communities, less what a random graph with the same degree sequence would put
	/// there.
	///
	/// The subtraction is the whole idea. Counting internal edges alone is maximised by
	/// putting everything in one community, which says nothing; subtracting the expected
	/// count makes that case score **exactly zero**, and a partition that separates
	/// well-connected groups score above it.
	///
	/// Two identities worth knowing, both of which the tests check:
	///
	/// - One community containing everything gives exactly `0`, because `ΣA = 2m` and the
	///   expected term also sums to `2m`.
	/// - Every node alone gives a **negative** number. A partition can be worse than no
	///   partition, which is what makes `Q` a score rather than a count.
	///
	/// The graph is read as undirected: an edge appearing in both adjacency lists is one
	/// edge, and `m` counts it once.
	///
	/// - Parameter communities: A partition — every node in exactly one community.
	/// - Returns: `Q`, or `nil` if the communities do not partition the graph: a node in
	///   two of them, a node in none, a node that is not in the graph, or no communities
	///   at all.
	func modularity(of communities: [Set<Node>]) -> Double? {
		guard !communities.isEmpty else { return nil }
		var assignment: [Node: Int] = [:]
		for (index, community) in communities.enumerated() {
			for node in community {
				guard adjacency[node] != nil else { return nil }
				guard assignment[node] == nil else { return nil }
				assignment[node] = index
			}
		}
		guard assignment.count == nodes.count else { return nil }

		var degree: [Node: Double] = [:]
		var twiceEdges: Double = 0
		for node in nodes {
			let count = Double(neighbors(of: node).count)
			degree[node] = count
			twiceEdges += count
		}
		guard twiceEdges > 0 else { return nil }

		var total: Double = 0
		for first in nodes {
			guard let group = assignment[first], let kFirst = degree[first] else { continue }
			let connected = Set(neighbors(of: first))
			for second in nodes {
				guard assignment[second] == group, let kSecond = degree[second] else { continue }
				let observed: Double = connected.contains(second) ? 1 : 0
				let product: Double = kFirst * kSecond
                let expected: Double = product / twiceEdges
				total += observed - expected
			}
		}
		return total / twiceEdges
	}

	// MARK: - Louvain

	/// Communities found by greedy modularity maximisation.
	///
	/// The Louvain method: repeatedly move each node to the neighbouring community that
	/// most improves modularity, then contract each community to a single node and repeat
	/// on the smaller graph, until no move helps.
	///
	/// ## Greedy, and honest about it
	///
	/// This maximises modularity locally and is not guaranteed to find the global
	/// optimum. On the graphs it is used for that is the accepted trade — exact
	/// modularity maximisation is NP-hard — but it means the result is *a* good partition
	/// rather than *the* best one, and two graphs that differ slightly can produce
	/// partitions that differ more than slightly.
	///
	/// It is also subject to the resolution limit: modularity cannot see communities
	/// smaller than about `√(2m)` edges, and will merge them regardless of how clearly
	/// separated they are. That is a property of the objective rather than of this
	/// implementation, and no amount of better searching fixes it.
	///
	/// ## Determinism
	///
	/// Nodes are visited in ``nodes`` order, which ``Graph`` fixed at construction. A
	/// greedy method that visited them in `Dictionary` order would give different
	/// partitions on different runs of the same program — correct-looking every time and
	/// never the same twice.
	///
	/// - Parameter maxPasses: How many contraction rounds to allow.
	/// - Returns: The communities, or `nil` for a graph with no edges, which has no
	///   modularity to maximise.
	func louvainCommunities(maxPasses: Int = 20) -> [Set<Node>]? {
		guard !nodes.isEmpty, edgeCount > 0 else { return nil }

		// Start with every node in its own community, then improve.
		var assignment: [Node: Int] = [:]
		for (index, node) in nodes.enumerated() { assignment[node] = index }

		let graph = undirectedView(of: nodes)
		let undirected = graph.adjacency
		let degree = graph.degree
		let twiceEdges = graph.twiceEdges
		guard twiceEdges > 0 else { return nil }

		var communityDegree: [Int: Double] = [:]
		for node in nodes {
			guard let group = assignment[node], let k = degree[node] else { continue }
			communityDegree[group, default: 0] += k
		}

		for _ in 0..<maxPasses {
			var moved = false
			for node in nodes {
				guard let current = assignment[node], let k = degree[node] else { continue }
				let neighbours = undirected[node] ?? []

				// Edges from this node into each candidate community.
				var links: [Int: Double] = [:]
				for other in neighbours.sorted() {
					guard let group = assignment[other] else { continue }
					links[group, default: 0] += 1
				}
				communityDegree[current, default: 0] -= k

				let bestGroup = Self.bestCommunity(
					for: current, links: links, communityDegree: communityDegree,
					nodeDegree: k, twiceEdges: twiceEdges)

				communityDegree[bestGroup, default: 0] += k
				if bestGroup != current {
					assignment[node] = bestGroup
					moved = true
				}
			}
			if !moved { break }
		}

		var grouped: [Int: Set<Node>] = [:]
		for node in nodes {
			guard let group = assignment[node] else { continue }
			grouped[group, default: []].insert(node)
		}
		let communities = grouped.keys.sorted().compactMap { grouped[$0] }
		return communities.isEmpty ? nil : communities
	}

	/// The graph as an undirected one, with each node's degree and the total edge weight.
	///
	/// Modularity is defined on an undirected graph, so a directed edge seen from either end
	/// is the same edge. Building the symmetric adjacency once — rather than asking
	/// `neighbors(of:)` again inside the improvement loop — is also part of why the result
	/// does not depend on the order the graph was assembled in, which
	/// `louvainIsDeterministic` pins.
	///
	/// - Parameter nodes: Every node in the graph.
	/// - Returns: The symmetric adjacency, each node's degree, and `2m`.
	private func undirectedView(
		of nodes: [Node]
	) -> (adjacency: [Node: Set<Node>], degree: [Node: Double], twiceEdges: Double) {
		var degree: [Node: Double] = [:]
		var twiceEdges: Double = 0
		var undirected: [Node: Set<Node>] = [:]
		for node in nodes { undirected[node] = [] }
		for node in nodes {
			for target in neighbors(of: node) {
				undirected[node]?.insert(target)
				undirected[target]?.insert(node)
			}
		}
		for node in nodes {
			let count = Double(undirected[node]?.count ?? 0)
			degree[node] = count
			twiceEdges += count
		}
		return (undirected, degree, twiceEdges)
	}

	/// Which community a node belongs in, given what it links to.
	///
	/// Staying put is the baseline rather than a special case: `current` is scored on the
	/// same footing as every candidate, so a node moves only when another community is
	/// strictly better. Candidates are visited in sorted order so ties resolve the same way
	/// on every run, whatever order the graph was assembled in.
	///
	/// - Parameters:
	///   - current: The node's present community.
	///   - links: Edge weight from this node into each candidate community.
	///   - communityDegree: Total degree of each community, with this node already removed.
	///   - nodeDegree: This node's degree.
	///   - twiceEdges: `2m` for the whole graph.
	/// - Returns: The community with the greatest modularity gain.
	private static func bestCommunity(
		for current: Int,
		links: [Int: Double],
		communityDegree: [Int: Double],
		nodeDegree: Double,
		twiceEdges: Double
	) -> Int {
		var bestGroup = current
		var bestGain = modularityGain(links: links[current] ?? 0,
									  communityDegree: communityDegree[current] ?? 0,
									  nodeDegree: nodeDegree, twiceEdges: twiceEdges)
		for (group, weight) in links.sorted(by: { $0.key < $1.key }) where group != current {
			let gain = modularityGain(links: weight,
									  communityDegree: communityDegree[group] ?? 0,
									  nodeDegree: nodeDegree, twiceEdges: twiceEdges)
			if gain > bestGain {
				bestGain = gain
				bestGroup = group
			}
		}
		return bestGroup
	}

	/// The modularity gain from placing a node in a community.
	///
	/// `links/2m − (Σtot · k)/(2m)²`, the standard Louvain increment. Only the terms that
	/// change with the choice of community are included — everything else is constant
	/// across the candidates being compared, so computing full modularity per candidate
	/// would be the same ranking at many times the cost.
	static func modularityGain(links: Double, communityDegree: Double,
							   nodeDegree: Double, twiceEdges: Double) -> Double {
		guard twiceEdges > 0 else { return 0 }
		let attraction: Double = links / twiceEdges
		let product: Double = communityDegree * nodeDegree
		let squared: Double = twiceEdges * twiceEdges
		guard squared > 0 else { return attraction }
		let expected: Double = product / squared
		return attraction - expected
	}
}
