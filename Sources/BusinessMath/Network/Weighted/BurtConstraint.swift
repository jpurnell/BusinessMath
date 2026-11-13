//
//  BurtConstraint.swift
//  BusinessMath
//

import Foundation

/// Brokerage measures over a ``WeightedGraph``.
///
/// ## What brokerage asks
///
/// Centrality asks how well connected a node is. Brokerage asks a different question: do a
/// node's contacts know each other? A node whose contacts are strangers to one another sits
/// across a *structural hole*, and is the only route between them. A node whose contacts
/// all know each other is embedded in a closed group and brings its contacts nothing they
/// did not already have.
///
/// ``constraint(_:)`` measures that, following Burt (1992).
public enum Brokerage {

	/// Burt's constraint for every node that has at least one tie.
	///
	/// On the undirected weighted graph, with `p_ij = w_ij / Σ_k w_ik` the share of node
	/// `i`'s total tie strength that goes to `j`, and `N(i)` the contacts of `i` (the nodes
	/// it has a tie of **positive** weight to):
	///
	/// ```
	/// c_i = Σ_{j ∈ N(i)} ( p_ij + Σ_{q ∈ N(i), q ≠ j} p_iq · p_qj )²
	/// ```
	///
	/// The inner sum is the strength of `i`'s indirect investment in `j`, through contacts
	/// who are themselves tied to `j`. Constraint is high when most of a node's strength is
	/// tied up in one contact, or in contacts that are tied to each other.
	///
	/// ## Reading the result
	///
	/// **Low** constraint: the node's contacts are not connected to each other, so the node
	/// spans structural holes. **High** constraint: the node's contacts are packed together
	/// or concentrated in one tie. Constraint measures structure. It says nothing about
	/// how much influence a node has, and a node with a single contact scores exactly 1
	/// whoever that contact is.
	///
	/// ## Zero-weight ties are not ties
	///
	/// A tie recorded with weight zero carries no strength, so its endpoint is not a contact:
	/// adding a zero-weight edge to a graph changes no node's constraint. This follows Burt
	/// (1992), where contacts are the people a node has a tie to, and it is the same reading
	/// that omits a node whose every tie is zero. It differs from `networkx.constraint`, which
	/// counts a zero-weight neighbour as a contact that receives only indirect investment
	/// (for `a-b = 1, a-c = 0, b-c = 1` it gives `a` the constraint 1.25; this gives 1).
	/// The dense-matrix oracle in the tests reads it the same way. See ADR-007.
	///
	/// ## Isolated nodes
	///
	/// A node with no ties (or whose ties carry no weight, so the shares `p_ij` are
	/// undefined) has no constraint. It is **omitted** from the result. Scoring it 0 would
	/// read as the best broker in the graph, and `NaN` cannot be encoded.
	///
	/// ## Cost
	///
	/// `O(Σ deg²)`: for each node, each contact's adjacency list is scanned once against a
	/// reusable index-based scratch array, with no per-pair dictionary lookups.
	///
	/// ```swift
	/// // A hub joining three people who do not know each other: 1/3.
	/// let star = WeightedGraph(unweightedEdges: [("hub", "a"), ("hub", "b"), ("hub", "c")])
	/// let scores = Brokerage.constraint(star)
	/// print(scores["hub"] ?? 0)   // 0.3333...
	/// print(scores["a"] ?? 0)     // 1.0
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: Constraint per node, omitting nodes with no usable ties.
	public static func constraint<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>
	) -> NodeScores<Node> {
		let count = graph.nodeCount
		guard count > 0 else { return NodeScores([:]) }

		let strengths = (0..<count).map { graph.weightedDegree($0) }

		// Scratch space reused across nodes. `direct[j]` holds p_ij for the node `i` being
		// processed, and `stamp[j] == i` marks j as a neighbour of i without clearing.
		var direct = [Double](repeating: 0, count: count)
		var indirect = [Double](repeating: 0, count: count)
		var stamp = [Int](repeating: -1, count: count)

		var scores: [Node: Double] = [:]
		for i in 0..<count {
			let strength = strengths[i]
			// Division safety: no weighted tie means no defined constraint. The graph guarantees
			// every weight is finite and non-negative, so the strength is finite.
			guard strength > 0 else { continue }

			// Contacts are the neighbours with a tie of positive weight; a zero-weight tie is
			// not a tie (ADR-007). Every later loop skips them, and a contact's own strength is
			// at least the weight of its tie to `i`, so it is positive and safe to divide by.
			for (j, weight) in graph.adjacency[i] where weight > 0 {
				stamp[j] = i
				direct[j] = weight / strength
				indirect[j] = 0
			}
			for (q, weightIQ) in graph.adjacency[i] where weightIQ > 0 {
				let share = direct[q]
				let strengthQ = strengths[q]
				for (j, weightQJ) in graph.adjacency[q] where j != i && stamp[j] == i {
					indirect[j] += share * (weightQJ / strengthQ)
				}
			}

			var total = 0.0
			for (j, weight) in graph.adjacency[i] where weight > 0 {
				let investment = direct[j] + indirect[j]
				total += investment * investment
			}
			scores[graph.nodes[i]] = total
		}
		return NodeScores(scores)
	}
}

/// Burt's constraint — who spans structural holes.
///
/// A ``GraphMetric`` wrapper over ``Brokerage/constraint(_:)``. Low constraint marks a
/// broker, a node whose contacts are not connected to one another; high constraint marks
/// a node embedded in a tight cluster. Nodes with no ties are omitted from the scores.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try BurtConstraint<String>().compute(on: graph)
/// print(scores["b"] ?? 0)   // 0.5, the middle of a path is the broker
/// print(scores["a"] ?? 0)   // 1.0
/// ```
public struct BurtConstraint<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "burt-constraint", version: 1, title: "Burt's Constraint",
			interpretation: "How far a node's contacts are tied to each other, after Burt "
				+ "(1992). It measures the structure around a person, not their influence.",
			highMeans: "Embedded: most of this person's ties go to one contact or to "
				+ "contacts who know each other, so they reach little that their contacts "
				+ "do not already reach. This does not mean they are unimportant or "
				+ "uninfluential, only that their position is closed.",
			lowMeans: "Spans structural holes: their contacts are largely unconnected to "
				+ "one another, so they are a broker between groups. This does not mean "
				+ "they are influential, well liked or well connected, and a person with "
				+ "few ties can score low. People with no recorded ties are omitted, "
				+ "not scored."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Brokerage.constraint(graph)
	}
}
