//
//  AnyGraphMetric.swift
//  BusinessMath
//

import Foundation

/// A metric with its concrete type and result shape erased, so heterogeneous metrics can
/// live in one collection.
///
/// The result comes back as a ``MetricEnvelope``; recover the typed value with
/// ``MetricEnvelope/value(as:)``.
///
/// ```swift
/// import BusinessMath
///
/// let erased = AnyGraphMetric(DegreeMetric<String>())
/// let graph = WeightedGraph(unweightedEdges: [("a", "b")])
/// let envelope = try erased.compute(on: graph)
/// print(envelope.kind)   // "scores"
/// ```
public struct AnyGraphMetric<Node: Hashable & Comparable & Sendable & Codable>: Sendable {

	/// What this metric answers.
	public let descriptor: MetricDescriptor

	private let computation: @Sendable (WeightedGraph<Node>) throws -> MetricEnvelope

	/// Wraps a metric.
	public init<M: GraphMetric>(_ metric: M) where M.Node == Node {
		self.descriptor = M.descriptor
		self.computation = { graph in try MetricEnvelope(metric.compute(on: graph)) }
	}

	/// Computes it.
	public func compute(on graph: WeightedGraph<Node>) throws -> MetricEnvelope {
		try computation(graph)
	}
}
