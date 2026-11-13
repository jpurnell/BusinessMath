//
//  MetricValue.swift
//  BusinessMath
//

import Foundation

/// A result a metric can return.
///
/// ## An open set
///
/// Results are a protocol rather than an enum so that a project can add a result shape —
/// a chosen set of sites, a routing table — without editing this package. The built-in
/// shapes are ``NodeScores`` (kind `"scores"`), ``NodePartition`` (`"partition"`) and
/// ``NodeSelection`` (`"selection"`); ``DiagnosedScores`` is scores that also record how an
/// iteration ended, and files under `"scores"` too.
///
/// ``kind`` is the stable name a stored result is filed under in a ``MetricEnvelope``. It
/// is part of the persisted format: renaming one orphans every result already stored
/// under it.
///
/// ```swift
/// struct NodeCount: MetricValue {
///     static var kind: String { "node-count" }
///     let count: Int
/// }
/// ```
public protocol MetricValue: Sendable, Codable, Hashable {

	/// The stable name this shape is stored under.
	static var kind: String { get }
}
