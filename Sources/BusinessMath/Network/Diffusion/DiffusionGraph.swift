//
//  DiffusionGraph.swift
//  BusinessMath
//

import Foundation

/// A graph flattened for fast cascade simulation.
///
/// ``WeightedGraph`` keeps an array of small arrays, which is convenient and slow to walk
/// millions of times. This holds the same adjacency in compressed-row form — one contiguous
/// array of neighbours and one of weights — plus the two derived quantities every diffusion
/// model needs, so a simulation never recomputes them per trial.
///
/// Build one once per graph and hand it to many simulations.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let flat = DiffusionGraph(graph)
/// print(flat.nodeCount)                       // 3
/// print(flat.neighbours(of: 1).count)         // 2
/// ```
public struct DiffusionGraph: Sendable {

	/// How many nodes.
	public let nodeCount: Int

	/// `offsets[i]..<offsets[i + 1]` indexes node `i`'s entries in ``targets`` and
	/// ``weights``. Has `nodeCount + 1` entries.
	public let offsets: [Int]

	/// Neighbour indices, grouped by source node.
	public let targets: [Int]

	/// Edge weights, parallel to ``targets``.
	public let weights: [Double]

	/// Each node's weighted degree, the sum of its edge weights.
	public let weightedDegree: [Double]

	/// The largest single edge weight, or `0` for a graph without edges.
	public let maxWeight: Double

	/// Flattens a graph.
	public init<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) {
		let n = graph.nodeCount
		var offsets = [Int](repeating: 0, count: n + 1)
		var targets: [Int] = []
		var weights: [Double] = []
		var degrees = [Double](repeating: 0, count: n)
		var largest = 0.0
		targets.reserveCapacity(graph.edgeCount * 2)
		weights.reserveCapacity(graph.edgeCount * 2)
		for node in 0..<n {
			for edge in graph.adjacency[node] {
				targets.append(edge.neighbour)
				weights.append(edge.weight)
				degrees[node] += edge.weight
				largest = max(largest, edge.weight)
			}
			offsets[node + 1] = targets.count
		}
		self.nodeCount = n
		self.offsets = offsets
		self.targets = targets
		self.weights = weights
		self.weightedDegree = degrees
		self.maxWeight = largest
	}

	/// The neighbour indices of one node, or an empty range if `node` is out of bounds.
	public func neighbours(of node: Int) -> ArraySlice<Int> {
		guard node >= 0, node < nodeCount else { return [] }
		return targets[offsets[node]..<offsets[node + 1]]
	}
}
