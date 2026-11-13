//
//  GraphBridges.swift
//  BusinessMath
//

import Foundation

extension WeightedGraph {

	/// Builds an undirected weighted graph from a directed ``Graph``.
	///
	/// Each directed edge `a -> b` becomes one undirected tie `a - b` of weight one; edges
	/// listed in both directions are one tie, not two. Every vertex is kept, including ones
	/// with no edges. Self-loops are dropped, as ``WeightedGraph/init(edges:isolatedNodes:)``
	/// drops them.
	///
	/// The direction of every edge is lost, and so are repeated weights (there are none in a
	/// `Graph`): the result is the undirected closure of the input.
	///
	/// ```swift
	/// let directed = Graph(edges: [("a", "b"), ("b", "c")])
	/// let weighted = WeightedGraph(directed)
	/// weighted.edgeCount     // 2
	/// weighted.totalWeight   // 2.0
	/// ```
	///
	/// - Parameter graph: Any directed graph.
	public init(_ graph: Graph<Node>) {
		var seen: Set<[Node]> = []
		var pairs: [(Node, Node)] = []
		for from in graph.nodes {
			for to in graph.neighbors(of: from) where from != to {
				let key = from < to ? [from, to] : [to, from]
				if seen.insert(key).inserted { pairs.append((key[0], key[1])) }
			}
		}
		self.init(unweightedEdges: pairs, isolatedNodes: graph.nodes)
	}
}

extension Graph {

	/// Builds a directed ``Graph`` from an undirected ``WeightedGraph``, lossily.
	///
	/// Each undirected tie becomes two directed edges, `a -> b` and `b -> a`. **The weights are
	/// dropped**: a tie of weight 0.001 and one of weight 1,000 become the same edge, and a
	/// zero-weight tie becomes an ordinary edge. Every node is kept, including isolated ones.
	/// Use this only to hand the structure to an algorithm that ignores weights.
	///
	/// ```swift
	/// let weighted = try WeightedGraph(edges: [("a", "b", 7.5)])
	/// let graph = Graph(weighted)
	/// graph.neighbors(of: "a")   // ["b"]
	/// graph.neighbors(of: "b")   // ["a"]
	/// ```
	///
	/// - Parameter weighted: Any weighted graph.
	public init(_ weighted: WeightedGraph<Node>) {
		var map: [Node: [Node]] = [:]
		for (index, node) in weighted.nodes.enumerated() {
			map[node] = weighted.adjacency[index].map { weighted.nodes[$0.neighbour] }
		}
		self.init(adjacency: map)
	}
}
