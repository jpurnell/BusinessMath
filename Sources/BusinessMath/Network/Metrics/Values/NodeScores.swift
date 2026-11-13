//
//  NodeScores.swift
//  BusinessMath
//

import Foundation

/// A score per node.
///
/// ```swift
/// let scores = NodeScores(["a": 3, "b": 1, "c": 2])
/// print(scores.top(1).map(\.node))   // ["a"]
/// ```
///
/// Conforms to ``MetricValue`` (kind `"scores"`) when `Node` is `Codable`.
public struct NodeScores<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// Score by node.
	public let scores: [Node: Double]

	/// Creates a score table.
	public init(_ scores: [Node: Double]) { self.scores = scores }

	/// Nodes ordered by descending score, ties broken by node order so the
	/// ordering is stable across runs.
	public var ranked: [(node: Node, score: Double)] {
		scores.sorted {
			$0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
		}.map { (node: $0.key, score: $0.value) }
	}

	/// The highest-scoring nodes.
	public func top(_ count: Int) -> [(node: Node, score: Double)] {
		Array(ranked.prefix(max(0, count)))
	}

	/// The lowest-scoring nodes — for a metric where low means underserved.
	public func bottom(_ count: Int) -> [(node: Node, score: Double)] {
		Array(ranked.suffix(max(0, count)).reversed())
	}

	/// The score for one node.
	public subscript(node: Node) -> Double? { scores[node] }
}

extension NodeScores: Codable where Node: Codable {}

extension NodeScores: MetricValue where Node: Codable {
	/// `"scores"`.
	public static var kind: String { "scores" }
}
