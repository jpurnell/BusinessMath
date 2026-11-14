//
//  GraphMeasureError.swift
//  BusinessMath
//

import Foundation

/// Why a measure over a ``WeightedGraph`` refused its input.
///
/// ``GraphError`` is about building a graph (a weight that is not a finite non-negative number).
/// This is about asking a question of one: an argument or a pairing of arguments the measure
/// cannot answer honestly. Each case replaces a behaviour that used to return a plausible-looking
/// number instead (ADR-007, closed in ADR-009), so catching it is the explicit form of what
/// the old code did without saying so.
///
/// `Equatable` treats two `NaN` damping values as equal, so a test or a caller can match the
/// error it expects.
///
/// ```swift
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// do {
///     _ = try Centrality.pageRank(graph, damping: 1.5)
/// } catch GraphMeasureError.invalidDamping(let value) {
///     print(value)   // 1.5
/// }
/// ```
public enum GraphMeasureError: Error, Equatable, Sendable {

	/// A PageRank damping that is `NaN`, infinite, negative or at least one.
	///
	/// Damping is the probability of following a tie rather than teleporting, so it lives in
	/// `[0, 1)`. At one there is no teleporting and no unique fixed point on a graph with more
	/// than one component; the iteration contracts by a factor of exactly the damping, so it would
	/// not contract at all.
	case invalidDamping(Double)

	public static func == (lhs: GraphMeasureError, rhs: GraphMeasureError) -> Bool {
		switch (lhs, rhs) {
		case (.invalidDamping(let left), .invalidDamping(let right)):
			return (left.isNaN && right.isNaN) || left.isEqual(to: right)
		}
	}
}
