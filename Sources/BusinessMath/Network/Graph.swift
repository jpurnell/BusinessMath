//
//  Graph.swift
//  BusinessMath
//

import Foundation

/// A directed graph with a deterministic vertex and edge ordering.
///
/// ```swift
/// let graph = Graph(adjacency: ["a": ["b"], "b": ["c"], "c": ["a"]])
/// graph.stronglyConnectedComponents        // [["a", "b", "c"]]
/// graph.topologicalSort()                  // nil — it is cyclic
/// ```
///
/// ## Sortedness is a property of the type, not a precondition on the call
///
/// `Dictionary` and `Set` iteration order in Swift is not stable across runs, so any graph
/// algorithm that reads them directly produces output whose *order* varies between
/// otherwise identical runs. The answer is to sort once, here, at construction: `nodes` and
/// every adjacency list are sorted, and every algorithm in this module inherits the
/// guarantee without asking for it.
///
/// That is a deliberate choice over the alternative, which is to document the requirement
/// and hope. `Model Definition` carried a Tarjan implementation whose doc comment said each
/// adjacency list *is assumed already sorted* — true of its one caller, and a silent
/// correctness hazard the moment the function became public, because a caller passing
/// unsorted adjacency would get non-deterministic component ordering with no error, no
/// warning, and output that looks entirely correct on any single run.
///
/// The cost is `O(E log E)` once per graph rather than once per algorithm, and a
/// `Comparable` requirement on the node type. Both are worth it. `Comparable` is not
/// decoration here — it is the thing the determinism guarantee rests on.
///
/// ## Domain-neutral
///
/// An account dependency graph, a customer journey, a supply chain and a co-purchase
/// network are the same structure. This lives in `Network/` so that none of them has to
/// import another's domain to traverse it.
public struct Graph<Node: Hashable & Comparable & Sendable>: Sendable {

	/// Each vertex mapped to its out-neighbours, every list sorted.
	public let adjacency: [Node: [Node]]

	/// Every vertex, sorted. This is the iteration order every algorithm here uses.
	public let nodes: [Node]

	/// Builds a graph from an adjacency map.
	///
	/// - Parameters:
	///   - adjacency: Each vertex mapped to the vertices it points at. Need not be
	///     sorted; it will be.
	///   - includeUnlistedTargets: Whether a target that has no entry of its own becomes
	///     a vertex. `true` — the default, and the reading most callers expect — makes
	///     `["a": ["b"]]` a two-vertex graph with a sink at `b`.
	///
	///     `false` keeps only the keys, and drops edges pointing outside them. That is
	///     what a dependency graph wants: in `Model Definition` a name nothing defines is
	///     *supplied data* rather than a vertex, and an edge to it cannot take part in a
	///     cycle. Passing `false` states that reading rather than leaving the algorithm
	///     to guess it.
	public init(adjacency: [Node: [Node]], includeUnlistedTargets: Bool = true) {
		var vertices = Set(adjacency.keys)
		if includeUnlistedTargets {
			for targets in adjacency.values { vertices.formUnion(targets) }
		}
		var normalised: [Node: [Node]] = [:]
		normalised.reserveCapacity(vertices.count)
		for vertex in vertices {
			let targets = adjacency[vertex] ?? []
			// Dropping edges to non-vertices here rather than skipping them in every
			// traversal keeps the stored graph closed, so no algorithm needs the special
			// case and none of them can forget it.
			normalised[vertex] = targets.filter { vertices.contains($0) }.sorted()
		}
		self.adjacency = normalised
		self.nodes = vertices.sorted()
	}

	/// Builds a graph from a list of directed edges. Every mentioned node is a vertex.
	///
	/// - Parameter edges: Source-to-target pairs. Duplicates collapse.
	public init(edges: [(Node, Node)]) {
		var map: [Node: [Node]] = [:]
		for (from, to) in edges {
			map[from, default: []].append(to)
			if map[to] == nil { map[to] = [] }
		}
		for (vertex, targets) in map {
			var seen: Set<Node> = []
			map[vertex] = targets.filter { seen.insert($0).inserted }
		}
		self.init(adjacency: map)
	}

	/// The out-neighbours of a vertex, sorted.
	///
	/// - Parameter node: Any value. A vertex not in the graph has no neighbours.
	/// - Returns: The sorted out-neighbours, or an empty array.
	public func neighbors(of node: Node) -> [Node] {
		adjacency[node] ?? []
	}

	/// How many vertices.
	public var nodeCount: Int { nodes.count }

	/// How many directed edges.
	public var edgeCount: Int {
		adjacency.values.reduce(0) { $0 + $1.count }
	}

	/// The out-degree of a vertex.
	///
	/// - Parameter node: Any value.
	/// - Returns: How many edges leave it; zero if it is not a vertex.
	public func outDegree(of node: Node) -> Int {
		neighbors(of: node).count
	}

	/// The in-degree of every vertex, computed in one pass.
	///
	/// A dictionary rather than a per-node query because answering one at a time is
	/// `O(E)` each, and every caller that wants one in-degree wants all of them.
	public var inDegrees: [Node: Int] {
		var degrees: [Node: Int] = [:]
		for node in nodes { degrees[node] = 0 }
		for node in nodes {
			for target in neighbors(of: node) {
				degrees[target, default: 0] += 1
			}
		}
		return degrees
	}

	/// The same graph with every edge reversed.
	///
	/// A dependency graph traversed forwards answers "what does this need"; reversed, it
	/// answers "what breaks if this changes". Both come up, and neither is more natural
	/// than the other.
	public var reversed: Graph<Node> {
		var map: [Node: [Node]] = [:]
		for node in nodes { map[node] = [] }
		for node in nodes {
			for target in neighbors(of: node) {
				map[target, default: []].append(node)
			}
		}
		return Graph(adjacency: map)
	}
}
