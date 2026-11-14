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

	/// A partition handed to ``Community/modularity(_:partition:)`` that does not cover exactly the
	/// graph's nodes.
	///
	/// `missing` names the graph's nodes the partition leaves out, in node order; `unknown` names the
	/// nodes the partition mentions that the graph does not have, in order. Both are rendered with
	/// `String(describing:)`. Scoring a partial partition as if the missing nodes were not in the
	/// graph, or ignoring foreign ones, gave a number for a different question than the one asked.
	case partitionDoesNotMatchGraph(missing: [String], unknown: [String])

	/// Eigenvector centrality on a graph that is not connected.
	///
	/// `components` is the number of connected components, reading ties of positive weight only (a
	/// zero-weight tie carries nothing through the iteration). The leading eigenvector lives on the
	/// component with the largest eigenvalue and every other node decays toward zero, so the scores
	/// would say "unimportant" about people who are merely not comparable. Score the components
	/// separately (see ``Community/connectedComponents(_:)``) or use ``Centrality/pageRank(_:damping:maxIterations:tolerance:)``,
	/// which is defined on a disconnected graph.
	case disconnectedGraph(components: Int)

	/// Two errors are equal if they are the same case carrying the same values; two `NaN` dampings are equal.
	public static func == (lhs: GraphMeasureError, rhs: GraphMeasureError) -> Bool {
		switch (lhs, rhs) {
		case (.invalidDamping(let left), .invalidDamping(let right)):
			return (left.isNaN && right.isNaN) || left.isEqual(to: right)
		case (.partitionDoesNotMatchGraph(let leftMissing, let leftUnknown),
			  .partitionDoesNotMatchGraph(let rightMissing, let rightUnknown)):
			return leftMissing == rightMissing && leftUnknown == rightUnknown
		case (.disconnectedGraph(let left), .disconnectedGraph(let right)):
			return left == right
		default:
			return false
		}
	}
}
