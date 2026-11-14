//
//  ComponentwiseScores.swift
//  BusinessMath
//

import Foundation

/// How one connected component of the graph was scored by ``Centrality/eigenvectorByComponent(_:maxIterations:tolerance:)``.
///
/// Carried in ``ComponentwiseScores/components`` for every component of two or more nodes, so a
/// reader can see which components converged and how each was put on the shared scale.
///
/// Encodes with the keys `anchor`, `size`, `convergence` and `scale`.
///
/// ```swift
/// let graph = try WeightedGraph(edges: [("a", "b", 1), ("b", "c", 1), ("d", "e", 1)])
/// let result = try Centrality.eigenvectorByComponent(graph)
/// print(result.components.map(\.size))   // [3, 2]
/// ```
public struct ComponentScoring<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// The lowest node of the component, which names it.
	public let anchor: Node

	/// How many nodes the component has. At least two.
	public let size: Int

	/// How this component's own iteration ended.
	public let convergence: ConvergenceReport

	/// The factor applied to the per-component scores (largest 1, as ``Centrality/eigenvector(_:maxIterations:tolerance:)``
	/// returns them) to put the component on the shared scale. Divide a score by it to get the
	/// per-component scale back. Exactly 1 for the most sharply peaked component, and for a graph
	/// of one component.
	public let scale: Double

	/// Creates the record of one component.
	///
	/// - Parameters:
	///   - anchor: The lowest node of the component.
	///   - size: How many nodes the component has.
	///   - convergence: How the component's own iteration ended.
	///   - scale: The factor that put the component on the shared scale.
	public init(anchor: Node, size: Int, convergence: ConvergenceReport, scale: Double) {
		self.anchor = anchor
		self.size = size
		self.convergence = convergence
		self.scale = scale
	}
}

extension ComponentScoring: Codable where Node: Codable {}

/// Eigenvector centrality of every node of a graph that need not be connected, with how each
/// component converged.
///
/// Stored with kind `"scores"` and the keys `scores`, `convergence` (the worst case over the
/// components), `components` and `isolatedCount`, so it decodes as ``NodeScores`` and as
/// ``DiagnosedScores`` too, and ``MetricEnvelope/convergence`` of its envelope is the aggregate.
///
/// ```swift
/// let graph = try WeightedGraph(edges: [("a", "b", 1), ("b", "c", 1)], isolatedNodes: ["z"])
/// let result = try Centrality.eigenvectorByComponent(graph)
/// print(result.scores["z"] ?? -1)   // 0.0
/// print(result.isolatedCount)       // 1
/// ```
public struct ComponentwiseScores<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// A score per node: 0 for a node with no ties of positive weight, otherwise as
	/// ``Centrality/eigenvectorByComponent(_:maxIterations:tolerance:)`` describes.
	public let scores: NodeScores<Node>

	/// The worst case over the scored components: converged only if every one did, the most passes,
	/// the largest final change. For a graph with nothing to iterate, zero passes and converged.
	public let convergence: ConvergenceReport

	/// One entry per component of two or more nodes, in order of its lowest node.
	public let components: [ComponentScoring<Node>]

	/// How many nodes had no tie of positive weight and so scored 0.
	public let isolatedCount: Int

	/// The components whose iteration stopped at the ceiling.
	public var unconverged: [ComponentScoring<Node>] {
		components.filter { !$0.convergence.converged }
	}

	/// The scores and the aggregate convergence, as the plain ``DiagnosedScores`` every other
	/// iterative metric returns, without the per-component detail.
	public var diagnosed: DiagnosedScores<Node> {
		DiagnosedScores(scores: scores, convergence: convergence)
	}

	/// Creates a result.
	///
	/// - Parameters:
	///   - scores: A score per node.
	///   - convergence: The worst case over the scored components.
	///   - components: One entry per component of two or more nodes, in order of its lowest node.
	///   - isolatedCount: How many nodes had no tie of positive weight.
	public init(
		scores: NodeScores<Node>, convergence: ConvergenceReport,
		components: [ComponentScoring<Node>], isolatedCount: Int
	) {
		self.scores = scores
		self.convergence = convergence
		self.components = components
		self.isolatedCount = isolatedCount
	}
}

extension ComponentwiseScores: Codable where Node: Codable {
	private enum Keys: String, CodingKey { case scores, convergence, components, isolatedCount }

	/// Decodes a result stored as kind `"scores"` with the keys `scores`, `convergence`, `components` and `isolatedCount`.
	///
	/// - Parameter decoder: The decoder to read from.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: Keys.self)
		self.scores = NodeScores(try container.decode([Node: Double].self, forKey: .scores))
		self.convergence = try container.decode(ConvergenceReport.self, forKey: .convergence)
		self.components = try container.decode([ComponentScoring<Node>].self, forKey: .components)
		self.isolatedCount = try container.decode(Int.self, forKey: .isolatedCount)
	}

	/// Encodes the result with the same four keys it decodes from.
	///
	/// - Parameter encoder: The encoder to write to.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: Keys.self)
		try container.encode(scores.scores, forKey: .scores)
		try container.encode(convergence, forKey: .convergence)
		try container.encode(components, forKey: .components)
		try container.encode(isolatedCount, forKey: .isolatedCount)
	}
}

extension ComponentwiseScores: MetricValue where Node: Codable {
	/// `"scores"`: this result reads as ``NodeScores`` too, and its convergence is the one ``MetricEnvelope`` reports.
	public static var kind: String { "scores" }
}
