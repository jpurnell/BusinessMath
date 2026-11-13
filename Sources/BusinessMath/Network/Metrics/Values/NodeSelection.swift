//
//  NodeSelection.swift
//  BusinessMath
//

import Foundation

/// An ordered choice of nodes, each with the gain it added when it was picked.
///
/// The result shape for metrics that choose a *set* — seeds for a campaign, sites for a
/// facility — rather than score everyone. Order matters: the first pick is the best single
/// choice, and each later ``Pick/marginalGain`` is what that pick added given the ones
/// before it. Stored as an array of a small `Codable` struct rather than an array of
/// tuples, because tuples cannot conform to `Codable`.
///
/// ```swift
/// let selection = NodeSelection(picks: [("a", 3.0), ("b", 1.5)])
/// print(selection.nodes)       // ["a", "b"]
/// print(selection.totalGain)   // 4.5
/// ```
///
/// Conforms to ``MetricValue`` (kind `"selection"`) when `Node` is `Codable`.
public struct NodeSelection<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// One chosen node and what it added.
	public struct Pick: Sendable, Hashable {
		/// The chosen node.
		public let node: Node
		/// What this pick added beyond the picks before it.
		public let marginalGain: Double

		/// Creates a pick.
		public init(node: Node, marginalGain: Double) {
			self.node = node
			self.marginalGain = marginalGain
		}
	}

	/// The picks, in the order they were made.
	public let picks: [Pick]

	/// Creates a selection from picks already in order.
	public init(_ picks: [Pick]) { self.picks = picks }

	/// Creates a selection from `(node, marginalGain)` pairs already in order.
	public init(picks: [(node: Node, marginalGain: Double)]) {
		self.picks = picks.map { Pick(node: $0.node, marginalGain: $0.marginalGain) }
	}

	/// The chosen nodes, in pick order.
	public var nodes: [Node] { picks.map(\.node) }

	/// The sum of every pick's marginal gain.
	public var totalGain: Double { picks.reduce(0) { $0 + $1.marginalGain } }
}

extension NodeSelection.Pick: Codable where Node: Codable {}

extension NodeSelection: Codable where Node: Codable {}

extension NodeSelection: MetricValue where Node: Codable {
	/// `"selection"`.
	public static var kind: String { "selection" }
}
