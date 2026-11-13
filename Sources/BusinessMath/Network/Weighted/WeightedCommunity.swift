//
//  WeightedCommunity.swift
//  BusinessMath
//

import Foundation

/// Community detection and core decomposition.
public enum Community {

	/// Modularity of a partition — how much better than chance it is.
	///
	/// Deliberately written independently of ``louvain(_:resolution:maxPasses:)``
	/// and sharing no code with it. A search that scores its own results with
	/// its own objective function cannot be checked; scoring them with a
	/// separately written function can.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - partition: The community assignment to score.
	/// - Returns: Modularity, conventionally between -0.5 and 1. Zero for a graph with no edge weight.
	///
	/// ## Current behaviour that a stricter measure would refuse
	///
	/// Recorded in ADR-007 and ported unchanged:
	///
	/// - **The partition is not validated.** A node that is absent from `partition` is skipped
	///   silently, as if it were not in the graph, and a partition that mentions nodes the
	///   graph does not have is not noticed. The unweighted `Graph.modularity(of:)` returns
	///   `nil` for both.
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("c", "d"), ("b", "c")])
	/// let split = NodePartition(["a": 0, "b": 0, "c": 1, "d": 1])
	/// print(Community.modularity(graph, partition: split))   // 0.1666...
	/// ```
	public static func modularity<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, partition: NodePartition<Node>
	) -> Double {
		let total = graph.totalWeight
		// An edgeless graph has no structure to be better than chance about.
		guard total > 0 else { return 0 }

		var internalWeight: [Int: Double] = [:]
		var degreeSum: [Int: Double] = [:]

		for (index, node) in graph.nodes.enumerated() {
			guard let community = partition[node] else { continue }
			degreeSum[community, default: 0] += graph.weightedDegree(index)
			for (neighbour, weight) in graph.adjacency[index] {
				guard let other = partition[graph.nodes[neighbour]],
					  other == community else { continue }
				internalWeight[community, default: 0] += weight
			}
		}

		var score = 0.0
		for community in internalWeight.keys.sorted() {
			let inside = internalWeight[community] ?? 0
			let degree = degreeSum[community] ?? 0
			// inside counts each internal edge twice, hence the halving.
			score += (inside / 2) / total - pow(degree / (2 * total), 2)
		}
		// Communities with no internal edges still penalise via their degree.
		for community in degreeSum.keys.sorted() where internalWeight[community] == nil {
			let degree = degreeSum[community] ?? 0
			score -= pow(degree / (2 * total), 2)
		}
		return score
	}

	/// Louvain community detection.
	///
	/// Greedy modularity optimisation: repeatedly move each node to the
	/// neighbouring community that most improves modularity, then collapse
	/// communities into nodes and repeat.
	///
	/// Node order is fixed rather than shuffled, so the same graph always
	/// yields the same partition. Louvain is order-sensitive, and a metric that
	/// silently returns a different answer each run cannot be compared across
	/// years — which is the whole point of keeping the results.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - resolution: Above 1 favours smaller communities, below 1 larger.
	///   - maxPasses: Ceiling on collapse rounds. A value below one is treated as one.
	/// - Returns: The partition, every node in exactly one community; communities are numbered
	///   in order of the lowest node they contain. A graph with no edge weight puts every node
	///   in its own community.
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [
	///     ("a", "b"), ("b", "c"), ("a", "c"),
	///     ("x", "y"), ("y", "z"), ("x", "z"),
	///     ("c", "x"),
	/// ])
	/// let partition = Community.louvain(graph)
	/// print(partition.communityCount)   // 2
	/// ```
	public static func louvain<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, resolution: Double = 1.0, maxPasses: Int = 20
	) -> NodePartition<Node> {
		let count = graph.nodeCount
		guard count > 0 else { return NodePartition([:]) }
		guard graph.totalWeight > 0 else {
			// No edges: every node is its own community, which is the honest
			// answer rather than one arbitrary lump.
			return NodePartition(Dictionary(
				uniqueKeysWithValues: graph.nodes.enumerated().map { ($0.element, $0.offset) }))
		}

		// Community membership at the finest level, followed through collapses.
		var assignment = Array(0..<count)
		var levelNodes = Array(0..<count)
		var levelAdjacency = graph.adjacency.map { $0.map { ($0.neighbour, $0.weight) } }
		var levelSelfLoops = [Double](repeating: 0, count: count)

		for _ in 0..<max(1, maxPasses) {
			let levelCount = levelNodes.count
			var community = Array(0..<levelCount)
			let degrees = (0..<levelCount).map { index in
				levelAdjacency[index].reduce(0) { $0 + $1.1 } + 2 * levelSelfLoops[index]
			}
			let totalWeight = degrees.reduce(0, +) / 2
			guard totalWeight > 0 else { break }
			var communityTotal = degrees

			var improved = false
			var moved = true
			var sweeps = 0
			while moved && sweeps < 50 {
				moved = false
				sweeps += 1
				for index in 0..<levelCount {
					let own = community[index]
					var weightTo: [Int: Double] = [:]
					for (neighbour, weight) in levelAdjacency[index] {
						weightTo[community[neighbour], default: 0] += weight
					}
					communityTotal[own] -= degrees[index]

					var bestCommunity = own
					var bestGain = (weightTo[own] ?? 0)
						- resolution * communityTotal[own] * degrees[index] / (2 * totalWeight)
					// Sorted, not raw dictionary order. Swift seeds its hasher
					// per process, so iterating a Dictionary breaks ties
					// differently on every run — and Louvain ties constantly.
					// A metric that returns a different partition each time
					// cannot be compared against its own past results, which is
					// the entire reason stored metric records exist.
					for candidate in weightTo.keys.sorted() where candidate != own {
						let weight = weightTo[candidate] ?? 0
						let gain = weight
							- resolution * communityTotal[candidate] * degrees[index]
								/ (2 * totalWeight)
						if gain > bestGain + 1e-12 {
							bestGain = gain
							bestCommunity = candidate
						}
					}
					communityTotal[bestCommunity] += degrees[index]
					if bestCommunity != own {
						community[index] = bestCommunity
						moved = true
						improved = true
					}
				}
			}
			guard improved else { break }

			// Renumber, then collapse each community into a single node.
			// Renumber in first-appearance order over the node sequence, which
			// is stable, rather than over a set.
			var renumbered: [Int: Int] = [:]
			for value in community where renumbered[value] == nil {
				renumbered[value] = renumbered.count
			}
			let compact = community.map { renumbered[$0] ?? 0 }
			for index in 0..<count {
				assignment[index] = compact[assignment[index]]
			}

			let newCount = renumbered.count
			guard newCount < levelCount else { break }
			var newAdjacency: [[Int: Double]] = Array(repeating: [:], count: newCount)
			var newSelfLoops = [Double](repeating: 0, count: newCount)
			for index in 0..<levelCount {
				let source = compact[index]
				newSelfLoops[source] += levelSelfLoops[index]
				for (neighbour, weight) in levelAdjacency[index] {
					let target = compact[neighbour]
					if source == target {
						newSelfLoops[source] += weight / 2
					} else {
						newAdjacency[source][target, default: 0] += weight
					}
				}
			}
			levelNodes = Array(0..<newCount)
			levelAdjacency = newAdjacency.map { Array($0) }
			levelSelfLoops = newSelfLoops
		}

		var result: [Node: Int] = [:]
		for (index, node) in graph.nodes.enumerated() { result[node] = assignment[index] }
		return NodePartition(result)
	}

	/// k-core decomposition — the largest `k` for which a node survives
	/// repeatedly peeling away everyone with fewer than `k` neighbours.
	///
	/// **This is the underserved measure.** A low core number means a person's
	/// ties are thin *and* their neighbours' ties are thin — a peripheral
	/// pocket rather than one isolated individual. A low score is evidence of silence
	/// in the records, not evidence of isolation.
	///
	/// Weights are ignored: a node's degree is its number of neighbours, so a zero-weight tie
	/// counts as an edge here (ADR-007).
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [
	///     ("a", "b"), ("b", "c"), ("a", "c"), ("c", "d"),
	/// ])
	/// let cores = Community.kCore(graph)
	/// print(cores["a"] ?? 0)   // 2.0
	/// print(cores["d"] ?? 0)   // 1.0
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: The core number of every node.
	public static func kCore<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		let count = graph.nodeCount
		var degree = (0..<count).map { graph.neighbourCount($0) }
		var core = [Int](repeating: 0, count: count)
		var removed = [Bool](repeating: false, count: count)

		for _ in 0..<count {
			var next = -1
			var lowest = Int.max
			for index in 0..<count where !removed[index] && degree[index] < lowest {
				lowest = degree[index]
				next = index
			}
			guard next >= 0 else { break }
			core[next] = lowest
			removed[next] = true
			for (neighbour, _) in graph.adjacency[next]
			where !removed[neighbour] && degree[neighbour] > lowest {
				degree[neighbour] -= 1
			}
		}

		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			scores[node] = Double(core[index])
		}
		return NodeScores(scores)
	}
}

extension Community {

	/// Connected components — which classmates can reach each other at all.
	///
	/// Distinct from Louvain: a community is a *denser* region of a connected
	/// graph, whereas a component is a piece with no path to the rest. Both are
	/// worth knowing, and conflating them is how a hundred people with no
	/// recorded tie end up described as a community.
	///
	/// A zero-weight tie connects its endpoints here (ADR-007).
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [("a", "b")], isolatedNodes: ["x"])
	/// let components = Community.connectedComponents(graph)
	/// print(components.communityCount)   // 2
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: The component of every node, numbered in order of the lowest node it contains.
	public static func connectedComponents<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodePartition<Node> {
		let count = graph.nodeCount
		var component = [Int](repeating: -1, count: count)
		var next = 0

		for start in 0..<count where component[start] < 0 {
			component[start] = next
			var queue = [start]
			var head = 0
			while head < queue.count {
				let node = queue[head]
				head += 1
				for (neighbour, _) in graph.adjacency[node] where component[neighbour] < 0 {
					component[neighbour] = next
					queue.append(neighbour)
				}
			}
			next += 1
		}

		var result: [Node: Int] = [:]
		for (index, node) in graph.nodes.enumerated() { result[node] = component[index] }
		return NodePartition(result)
	}
}
