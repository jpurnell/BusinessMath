//
//  WeightedGraph.swift
//  BusinessMath
//

import Foundation

/// Why a weighted graph could not be built.
///
/// Every case is a weight that would make a measure answer with a plausible-looking wrong
/// number: a `NaN` weight makes a probabilistic spread model fire with certainty, a negative
/// weight makes a node's weighted degree cancel to zero, and an infinite weight swamps
/// everything else.
///
/// ```swift
/// do {
///     _ = try WeightedGraph(edges: [("a", "b", -1.0)])
/// } catch let error as GraphError {
///     print(error)   // invalidWeight(from: "a", to: "b", weight: -1.0)
/// }
/// ```
public enum GraphError: Error, Equatable, Sendable {
	/// An edge weight that is `NaN`, infinite or negative. Zero is allowed: it is a recorded
	/// tie that carries no strength.
	case invalidWeight(from: String, to: String, weight: Double)
	/// Finite weights whose sum is not finite: duplicate edges merged, a node's weighted
	/// degree, or the graph's total weight.
	case weightSumOverflow
}

/// An undirected weighted graph held in memory.
///
/// ```swift
/// let graph = try WeightedGraph(edges: [("a", "b", 1.0), ("b", "c", 1.0)])
/// graph.nodeCount              // 3
/// graph.degree(of: "b")        // Optional(2.0)
/// ```
///
/// ## Why in memory
///
/// The graphs this was built for have about 1,100 nodes and 15,000 edges. Holding the
/// adjacency directly makes each measure a pure function of a value type, which is what lets
/// results be checked against published figures rather than against each other.
///
/// ## Node type
///
/// `Node` appears only at the boundary: in ``nodes``, ``indexOf`` and the initialisers.
/// Inside, adjacency is index-based, so the algorithms neither know nor care what a node
/// is. `Comparable` gives a stable node order, which is what makes every result reproducible
/// across runs.
///
/// ## Relationship to ``Graph``
///
/// ``Graph`` is directed and unweighted; `WeightedGraph` is undirected and weighted. They sit
/// side by side, and ``init(_:)-(Graph<Node>)`` and ``Graph/init(_:)`` convert between them.
public struct WeightedGraph<Node: Hashable & Comparable & Sendable>: Sendable {

	/// Node identifiers, in stable sorted order.
	public let nodes: [Node]

	/// Position of each node in ``nodes``.
	public let indexOf: [Node: Int]

	/// For each node, its neighbours as `(index, weight)`, sorted by neighbour index.
	public let adjacency: [[(neighbour: Int, weight: Double)]]

	/// Sum of all edge weights, counting each undirected edge once.
	public let totalWeight: Double

	/// How many nodes.
	public var nodeCount: Int { nodes.count }

	/// How many undirected edges.
	public let edgeCount: Int

	/// Builds a graph from undirected weighted edges.
	///
	/// Duplicate pairs are merged by summing their weights; self-loops are
	/// dropped, because a tie to oneself is not a tie.
	///
	/// ## Weights are validated here, once
	///
	/// Every measure downstream trusts that a weight is a finite, non-negative number, so this
	/// is the one place that checks. A weight of zero is legal (a recorded tie that carries no
	/// strength); `NaN`, infinities and negative weights are not, and neither is a set of
	/// finite weights whose merged sum, a node's weighted degree or the total overflows.
	/// Self-loops are checked before they are dropped.
	///
	/// ```swift
	/// let graph = try WeightedGraph(
	///     edges: [("a", "b", 1.5), ("b", "a", 2.5)],
	///     isolatedNodes: ["x"])
	/// graph.edgeCount      // 1
	/// graph.totalWeight    // 4.0
	/// ```
	///
	/// - Parameters:
	///   - edges: `(from, to, weight)` triples in either direction.
	///   - isolatedNodes: Nodes with no edges at all. They must be passed
	///     explicitly, because an edge list cannot mention them, and dropping
	///     them would quietly remove exactly the nodes an analysis most often
	///     exists to find.
	/// - Throws: ``GraphError/invalidWeight(from:to:weight:)`` for a `NaN`, infinite or
	///   negative weight; ``GraphError/weightSumOverflow`` if the weights sum past the largest
	///   finite number.
	public init(edges: [(Node, Node, Double)], isolatedNodes: [Node] = []) throws {
		for (from, to, weight) in edges {
			guard weight.isFinite, weight >= 0 else {
				throw GraphError.invalidWeight(
					from: String(describing: from), to: String(describing: to), weight: weight)
			}
		}
		self.init(unchecked: edges, isolatedNodes: isolatedNodes)
		// Each weight is finite, but a sum of finite numbers need not be: duplicates merge by
		// summing, and a node's degree and the total are sums too.
		guard totalWeight.isFinite, adjacency.indices.allSatisfy({ weightedDegree($0).isFinite }) else {
			throw GraphError.weightSumOverflow
		}
	}

	/// Builds the graph from edges whose weights the caller has already vetted.
	private init(unchecked edges: [(Node, Node, Double)], isolatedNodes: [Node]) {
		var merged: [Node: [Node: Double]] = [:]
		var names: Set<Node> = Set(isolatedNodes)

		for (from, to, weight) in edges {
			names.insert(from)
			names.insert(to)
			guard from != to else { continue }
			merged[from, default: [:]][to, default: 0] += weight
			merged[to, default: [:]][from, default: 0] += weight
		}

		let sortedNames = names.sorted()
		self.nodes = sortedNames
		var positions: [Node: Int] = [:]
		positions.reserveCapacity(sortedNames.count)
		for (offset, name) in sortedNames.enumerated() { positions[name] = offset }
		self.indexOf = positions

		var lists: [[(neighbour: Int, weight: Double)]] = Array(
			repeating: [], count: sortedNames.count)
		var total = 0.0
		for (name, neighbours) in merged {
			guard let index = positions[name] else { continue }
			lists[index] = neighbours.compactMap { neighbour, weight in
				guard let other = positions[neighbour] else { return nil }
				return (neighbour: other, weight: weight)
			}.sorted { $0.neighbour < $1.neighbour }
			total += neighbours.values.reduce(0, +)
		}
		self.adjacency = lists
		// Each undirected edge was counted from both ends.
		self.totalWeight = total / 2
		self.edgeCount = lists.reduce(0) { $0 + $1.count } / 2
	}

	/// Builds an unweighted graph, every edge weighing one.
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// graph.totalWeight    // 2.0
	/// ```
	///
	/// - Parameters:
	///   - unweightedEdges: Undirected `(from, to)` pairs.
	///   - isolatedNodes: Nodes with no edges at all.
	public init(unweightedEdges: [(Node, Node)], isolatedNodes: [Node] = []) {
		// Weight 1 is always valid, so this path needs no validation and cannot throw.
		self.init(
			unchecked: unweightedEdges.map { ($0.0, $0.1, 1.0) },
			isolatedNodes: isolatedNodes)
	}

	/// The weighted degree of a node, or `nil` if it is not in the graph.
	///
	/// - Parameter node: Any value.
	/// - Returns: The sum of the weights of the node's ties, or `nil` for an unknown node.
	public func degree(of node: Node) -> Double? {
		guard let index = indexOf[node] else { return nil }
		return weightedDegree(index)
	}

	/// The weighted degree of a node by index.
	///
	/// - Parameter index: A position in ``nodes``. Must be in range.
	/// - Returns: The sum of the weights of the node's ties.
	public func weightedDegree(_ index: Int) -> Double {
		adjacency[index].reduce(0) { $0 + $1.weight }
	}

	/// How many neighbours a node has, ignoring weights.
	///
	/// - Parameter index: A position in ``nodes``. Must be in range.
	/// - Returns: The number of distinct neighbours.
	public func neighbourCount(_ index: Int) -> Int { adjacency[index].count }
}
