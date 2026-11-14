//
//  ComponentwiseEigenvectorMetric.swift
//  BusinessMath
//

import Foundation

/// Eigenvector centrality scored separately in every connected component and put on one scale.
///
/// Unlike ``EigenvectorMetric`` (`eigenvector-centrality` version 5), which refuses a graph that is
/// not connected, this answers one, at the price of a cross-component scale that is a convention:
/// see ``Centrality/eigenvectorByComponent(_:maxIterations:tolerance:)``. A connected graph with no
/// isolated node scores bit for bit as ``EigenvectorMetric`` does, with its convergence report.
///
/// Version 1. The stored payload is kind `"scores"` with the keys `scores`, `convergence` (the worst
/// case over the components), `components` and `isolatedCount`, so a reader of plain ``NodeScores``
/// or ``DiagnosedScores`` still works. A different cross-component convention would be version 2, not
/// an edit of this one.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("d", "e")])
/// let result = try ComponentwiseEigenvectorMetric<String>().compute(on: graph)
/// print(result.convergence.converged)   // true
/// print(result.components.count)        // 2
/// ```
public struct ComponentwiseEigenvectorMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {

	/// The identifier stored with every result of this metric.
	public static var identifier: String { "eigenvector-centrality-by-component" }

	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: identifier, version: 1, title: "Eigenvector Centrality (by component)",
			interpretation: "Who is connected to well-connected classmates, scored within each "
				+ "connected group of classmates and then put on one scale. Unlike plain "
				+ "eigenvector centrality it can run on a class with many separate groups.",
			highMeans: "Well connected inside their own group, in a group whose ties are "
				+ "concentrated on a few people. Order inside a group is exact; order between "
				+ "groups follows a convention (a typical member of any group scores alike), so "
				+ "a small group's hub is not comparable to a large group's.",
			lowMeans: "Peripheral inside their group. Exactly zero means no ties at all, which "
				+ "is silence in the records and not a finding that the person is unimportant."
		)
	}

	/// The iteration ceiling for each component.
	public let maxIterations: Int

	/// The convergence threshold for each component.
	public let tolerance: Double

	/// Creates the metric.
	///
	/// - Parameters:
	///   - maxIterations: Iteration ceiling for each component.
	///   - tolerance: Convergence threshold on the L1 change per pass, for each component.
	public init(maxIterations: Int = 200, tolerance: Double = 1e-10) {
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	/// Computes it over the graph.
	///
	/// - Parameter graph: The graph. It need not be connected.
	/// - Returns: The scores and how each component converged.
	public func compute(on graph: WeightedGraph<Node>) throws -> ComponentwiseScores<Node> {
		try Centrality.eigenvectorByComponent(graph, maxIterations: maxIterations, tolerance: tolerance)
	}
}
