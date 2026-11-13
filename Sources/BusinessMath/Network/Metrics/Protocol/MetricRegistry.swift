//
//  MetricRegistry.swift
//  BusinessMath
//

import Foundation

/// The metrics available to run.
///
/// ```swift
/// import BusinessMath
///
/// let registry = MetricRegistry<String>.standard
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("a", "c")])
/// let output = try registry.run("degree", on: graph)
/// print(output != nil)   // true
/// ```
public struct MetricRegistry<Node: Hashable & Comparable & Sendable & Codable>: Sendable {

	private let metrics: [String: AnyGraphMetric<Node>]

	/// Creates a registry. If two metrics share an identifier the first wins.
	public init(_ metrics: [AnyGraphMetric<Node>]) {
		self.metrics = Dictionary(
			metrics.map { ($0.descriptor.identifier, $0) },
			uniquingKeysWith: { first, _ in first }
		)
	}

	/// Adds a metric, returning a new registry.
	public func registering<M: GraphMetric>(_ metric: M) -> MetricRegistry<Node>
	where M.Node == Node {
		MetricRegistry(Array(metrics.values) + [AnyGraphMetric(metric)])
	}

	/// Everything available, by identifier.
	public var available: [MetricDescriptor] {
		metrics.values.map(\.descriptor).sorted { $0.identifier < $1.identifier }
	}

	/// One metric, or `nil` if no such identifier is registered.
	public func metric(for identifier: String) -> AnyGraphMetric<Node>? {
		metrics[identifier]
	}

	/// Runs one metric.
	///
	/// - Returns: The output, or `nil` if the identifier is unknown.
	public func run(_ identifier: String, on graph: WeightedGraph<Node>) throws -> MetricEnvelope? {
		try metrics[identifier]?.compute(on: graph)
	}

	/// Runs one metric and records everything needed to interpret it later.
	///
	/// The generic counterpart of a provenance-carrying run: the caller's own description of
	/// how the graph was built travels as an opaque `Codable` ``MetricRecord/context``.
	///
	/// - Parameters:
	///   - identifier: Which metric.
	///   - graph: The graph.
	///   - context: The caller's provenance for the graph, carried unread.
	///   - now: The clock, injected so runs are reproducible in tests.
	/// - Returns: The record, or `nil` if the identifier is unknown.
	public func record<Context: Codable & Sendable & Hashable>(
		_ identifier: String,
		on graph: WeightedGraph<Node>,
		context: Context,
		now: Date
	) throws -> MetricRecord<Context>? {
		guard let metric = metrics[identifier] else { return nil }
		return MetricRecord(
			metric: metric.descriptor.identifier,
			metricVersion: metric.descriptor.version,
			context: context,
			computedAt: now,
			output: try metric.compute(on: graph)
		)
	}

	/// The metrics shipped with this build.
	///
	/// Only metrics that need no configuration are listed. ``SeedSelector`` is deliberately
	/// absent: it needs a diffusion model, a budget, a trial count and a seed, none of which
	/// has a default worth hiding. Register it yourself with ``registering(_:)``.
	public static var standard: MetricRegistry<Node> {
		MetricRegistry([
			AnyGraphMetric(DegreeMetric<Node>()),
			AnyGraphMetric(EigenvectorMetric<Node>()),
			AnyGraphMetric(PageRankMetric<Node>()),
			AnyGraphMetric(BetweennessMetric<Node>()),
			AnyGraphMetric(ClosenessMetric<Node>()),
			AnyGraphMetric(KCoreMetric<Node>()),
			AnyGraphMetric(LouvainMetric<Node>()),
			AnyGraphMetric(HarmonicMetric<Node>()),
			AnyGraphMetric(ClusteringMetric<Node>()),
			AnyGraphMetric(ComponentsMetric<Node>()),
			AnyGraphMetric(BurtConstraint<Node>()),
		])
	}
}
