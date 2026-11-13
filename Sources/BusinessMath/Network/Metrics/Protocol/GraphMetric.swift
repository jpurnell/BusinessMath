//
//  GraphMetric.swift
//  BusinessMath
//

import Foundation

/// One metric that can be run over a graph.
///
/// ## Why a protocol rather than a switch
///
/// A record like this is meant to be useful for decades. The algorithms will change in
/// that time — some of the ones here are already decades old and better ones will arrive.
/// A protocol lets a new metric be added by conforming to it, without editing a
/// switch statement that every existing call site depends on.
///
/// Results carry ``MetricDescriptor/version``, so a score computed in 2026 can
/// still be compared honestly against one computed in 2045 by a different
/// method.
///
/// ## Node type
///
/// `Node` must be `Codable` on top of what ``WeightedGraph`` needs, because a result is
/// stored in a ``MetricEnvelope`` and a result keyed by nodes can only be stored if its
/// nodes can.
///
/// ```swift
/// import BusinessMath
///
/// struct NodeCount: MetricValue {
///     static var kind: String { "node-count" }
///     let count: Int
/// }
///
/// struct CountMetric: GraphMetric {
///     static let descriptor = MetricDescriptor(
///         identifier: "node-count", version: 1, title: "Node Count",
///         interpretation: "How many nodes there are.",
///         highMeans: "A large graph.", lowMeans: "A small graph.")
///     func compute(on graph: WeightedGraph<String>) throws -> NodeCount {
///         NodeCount(count: graph.nodeCount)
///     }
/// }
/// ```
public protocol GraphMetric: Sendable {

	/// What the graph's nodes are.
	associatedtype Node: Hashable & Comparable & Sendable & Codable

	/// What this metric produces.
	associatedtype Output: MetricValue

	/// What this metric answers.
	static var descriptor: MetricDescriptor { get }

	/// Computes it.
	///
	/// - Parameter graph: The graph to measure.
	func compute(on graph: WeightedGraph<Node>) throws -> Output
}

extension GraphMetric {
	/// The descriptor, from an instance.
	public var descriptor: MetricDescriptor { Self.descriptor }
}
