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
	/// The Louvain method, in both of its phases. **Local moving:** repeatedly move each
	/// node to the neighbouring community that most improves modularity, until no move
	/// helps. **Contraction:** collapse each community into a single weighted super-node
	/// (edges between two communities summed into one weighted edge, edges inside a
	/// community becoming a self-weight) and run local moving again on the smaller graph.
	/// The two phases alternate until a round of local moving changes nothing or
	/// `maxPasses` rounds have run.
	///
	/// Contraction is what lets whole communities merge. A single node cannot make that
	/// move — leaving its own densely connected group for a neighbouring one loses more
	/// than it gains — but a super-node standing for the whole group can. On a ring of
	/// twelve triangles joined by single edges, local moving alone stops at one community
	/// per triangle with `Q = 3/4 − 1/12 ≈ 0.667`, while contraction pairs adjacent
	/// triangles and reaches `Q = 7/8 − 2/12 ≈ 0.708`.
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
	/// Nodes are visited in ``nodes`` order, which ``Graph`` fixed at construction, and at
	/// every level super-nodes are numbered by the lowest original node they contain. A
	/// node moves only when another community is better by more than a margin (`1e-12 / 2m`,
	/// the weighted ``Community/louvain(_:resolution:maxPasses:)``'s `1e-12` in this gain's units),
	/// so a tie that is exact on paper is not decided by rounding, and candidates are
	/// examined in ascending community number, so ties resolve the same way on every run.
	/// A greedy method that visited nodes in `Dictionary` order would give different
	/// partitions on different runs of the same program — correct-looking every time and
	/// never the same twice. The communities are returned ordered by their lowest node.
	///
	/// - Parameter maxPasses: How many contraction rounds to allow; a value below 1 is treated as 1. Each round is a full
	///   local-moving phase followed by a contraction; the loop also stops as soon as a
	///   phase moves nothing.
	/// - Returns: The communities, or `nil` for a graph with no edges, which has no
	///   modularity to maximise.
	func louvainCommunities(maxPasses: Int = 20) -> [Set<Node>]? {
		guard !nodes.isEmpty, edgeCount > 0 else { return nil }

		let view = undirectedView(of: nodes)
		guard view.twiceEdges > 0 else { return nil }
		let twiceEdges = view.twiceEdges

		// Level 0: one super-node per original node, in `nodes` order.
		var index: [Node: Int] = [:]
		for (position, node) in nodes.enumerated() { index[node] = position }
		var level = LouvainLevel(count: nodes.count)
		for (position, node) in nodes.enumerated() {
			for other in (view.adjacency[node] ?? []).sorted() {
				guard let target = index[other] else { continue }
				if target == position {
					level.selfWeight[position] += 1
				} else {
					level.neighbours[position].append((target, 1))
				}
			}
		}

		// Which super-node of the current level each original node sits inside.
		var membership = Array(0..<nodes.count)

		for _ in 0..<Swift.max(maxPasses, 1) {
			let label = Self.localMoving(level, twiceEdges: twiceEdges)
			guard let (contracted, renumber) = level.contracted(by: label) else { break }
			for position in membership.indices {
				membership[position] = renumber[label[membership[position]]] ?? membership[position]
			}
			level = contracted
		}

		var grouped: [Int: Set<Node>] = [:]
		for (position, node) in nodes.enumerated() {
			grouped[membership[position], default: []].insert(node)
		}
		let communities = grouped.keys.sorted().compactMap { grouped[$0] }
		return communities.isEmpty ? nil : communities
	}

	/// One level of the contraction: a weighted graph whose nodes are numbered `0..<count`.
	///
	/// `neighbours` excludes the node itself; weight a node has to itself — edges inside the
	/// community it stands for, each counted from both ends, plus any self-loop — lives in
	/// `selfWeight`. The degree of a node is its self-weight plus its neighbour weights,
	/// which is what keeps `2m` unchanged from one level to the next.
	private struct LouvainLevel {
		var neighbours: [[(node: Int, weight: Double)]]
		var selfWeight: [Double]

		init(count: Int) {
			neighbours = Array(repeating: [], count: count)
			selfWeight = Array(repeating: 0, count: count)
		}

		var count: Int { selfWeight.count }

		func degree(of node: Int) -> Double {
			var total: Double = selfWeight[node]
			for edge in neighbours[node] { total += edge.weight }
			return total
		}

		/// The graph with each group of `label` collapsed to one node.
		///
		/// - Parameter label: A group number for every node of this level.
		/// - Returns: The contracted level and the renumbering of group numbers to
		///   `0..<groups` (by lowest member), or `nil` if every node is alone, in which
		///   case there is nothing to contract.
		func contracted(by label: [Int]) -> (LouvainLevel, [Int: Int])? {
			var renumber: [Int: Int] = [:]
			for group in label where renumber[group] == nil { renumber[group] = renumber.count }
			guard renumber.count < count else { return nil }

			var next = LouvainLevel(count: renumber.count)
			var between: [[Int: Double]] = Array(repeating: [:], count: renumber.count)
			for node in 0..<count {
				guard let from = renumber[label[node]] else { continue }
				next.selfWeight[from] += selfWeight[node]
				for edge in neighbours[node] {
					guard let to = renumber[label[edge.node]] else { continue }
					if to == from {
						next.selfWeight[from] += edge.weight
					} else {
						between[from][to, default: 0] += edge.weight
					}
				}
			}
			for from in 0..<renumber.count {
				next.neighbours[from] = between[from].sorted { $0.key < $1.key }
					.map { (node: $0.key, weight: $0.value) }
			}
			return (next, renumber)
		}
	}

	/// Local moving: starting from every node alone, move nodes to their best neighbouring
	/// community until a full sweep moves none.
	///
	/// - Parameters:
	///   - level: The weighted graph at this level.
	///   - twiceEdges: `2m` for the whole graph, unchanged by contraction.
	/// - Returns: A community number for every node, each drawn from `0..<level.count`.
	private static func localMoving(_ level: LouvainLevel, twiceEdges: Double) -> [Int] {
		var label = Array(0..<level.count)
		var communityDegree: [Int: Double] = [:]
		var degree = [Double](repeating: 0, count: level.count)
		for node in 0..<level.count {
			degree[node] = level.degree(of: node)
			communityDegree[node] = degree[node]
		}

		// Each sweep that moves a node strictly raises modularity, so this terminates; the
		// bound is a backstop against floating-point ties, not part of the method.
		for _ in 0..<1000 {
			var moved = false
			for node in 0..<level.count {
				let current = label[node]
				let k = degree[node]
				var links: [Int: Double] = [:]
				for edge in level.neighbours[node] { links[label[edge.node], default: 0] += edge.weight }
				communityDegree[current, default: 0] -= k

				let bestGroup = bestCommunity(
					for: current, links: links, communityDegree: communityDegree,
					nodeDegree: k, twiceEdges: twiceEdges)

				communityDegree[bestGroup, default: 0] += k
				if bestGroup != current {
					label[node] = bestGroup
					moved = true
				}
			}
			if !moved { break }
		}
		return label
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

	/// The margin, in units of edge weight, by which a candidate community must beat the best so far
	/// to take a node: the same `1e-12` the weighted ``Community/louvain(_:resolution:maxPasses:)`` uses.
	static var moveMargin: Double { 1e-12 }

	/// Which community a node belongs in, given what it links to.
	///
	/// Staying put is the baseline rather than a special case: `current` is scored on the
	/// same footing as every candidate, so a node moves only when another community is
	/// better by more than a margin of `1e-12 / 2m`, the weighted Louvain's `1e-12` expressed in
	/// this gain's units (ADR-009). Without a margin a tie that is exact on paper is decided by
	/// floating-point rounding, and the two implementations split such a graph differently.
	/// Candidates are visited in sorted order so ties resolve the same way
	/// on every run, whatever order the graph was assembled in.
	///
	/// - Parameters:
	///   - current: The node's present community.
	///   - links: Edge weight from this node into each candidate community.
	///   - communityDegree: Total degree of each community, with this node already removed.
	///   - nodeDegree: This node's degree.
	///   - twiceEdges: `2m` for the whole graph.
	/// - Returns: The community with the greatest modularity gain.
	static func bestCommunity(
		for current: Int,
		links: [Int: Double],
		communityDegree: [Int: Double],
		nodeDegree: Double,
		twiceEdges: Double
	) -> Int {
		// The weighted Louvain moves a node only if a candidate beats the best so far by more than
		// 1e-12 in units of edge weight (`Community.louvain`). This gain is that quantity divided by
		// 2m, so the same margin is `1e-12 / 2m`: the two implementations then call the same moves ties.
		let threshold: Double = twiceEdges > 0 ? moveMargin / twiceEdges : 0
		var bestGroup = current
		var bestGain = modularityGain(links: links[current] ?? 0,
									  communityDegree: communityDegree[current] ?? 0,
									  nodeDegree: nodeDegree, twiceEdges: twiceEdges)
		for (group, weight) in links.sorted(by: { $0.key < $1.key }) where group != current {
			let gain = modularityGain(links: weight,
									  communityDegree: communityDegree[group] ?? 0,
									  nodeDegree: nodeDegree, twiceEdges: twiceEdges)
			if gain > bestGain + threshold {
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
