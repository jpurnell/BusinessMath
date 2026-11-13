//
//  MetricRecord.swift
//  BusinessMath
//

import Foundation

/// A metric result with everything needed to reproduce or interpret it.
///
/// ``context`` is whatever the caller needs to know later about how the graph was built —
/// a projection configuration, an archive snapshot, a data version. The package does not
/// interpret it; it only carries it, as an opaque `Codable` value, so a score is never
/// stored without the provenance that makes it comparable.
///
/// ```swift
/// import BusinessMath
/// import Foundation
///
/// struct Provenance: Codable, Sendable, Hashable { let snapshot: String }
/// let graph = WeightedGraph(unweightedEdges: [("a", "b")])
/// let record = try MetricRegistry<String>.standard.record(
///     "degree", on: graph, context: Provenance(snapshot: "2026-08-21"), now: Date())
/// print(record?.metricVersion ?? 0)   // 1
/// ```
public struct MetricRecord<Context: Codable & Sendable & Hashable>: Sendable, Codable, Hashable {

	/// Which metric.
	public let metric: String

	/// Which version of it — bumped when the mathematics changes.
	public let metricVersion: Int

	/// The caller's provenance for the graph, carried unread.
	public let context: Context

	/// When it ran.
	public let computedAt: Date

	/// What it produced.
	public let output: MetricEnvelope

	/// Creates a record.
	public init(
		metric: String, metricVersion: Int, context: Context,
		computedAt: Date, output: MetricEnvelope
	) {
		self.metric = metric
		self.metricVersion = metricVersion
		self.context = context
		self.computedAt = computedAt
		self.output = output
	}
}
