//
//  EigenvectorByComponent.swift
//  BusinessMath
//

import Foundation

extension Centrality {

	/// Eigenvector centrality scored separately in every connected component and put on one scale.
	///
	/// ``eigenvector(_:maxIterations:tolerance:)`` refuses a graph that is not connected, because the
	/// leading eigenvector lives on one component and every other node decays toward zero, which
	/// reads as "unimportant" instead of "not comparable". This runs the same iteration
	/// (``eigenvectorConvergence(_:maxIterations:tolerance:)``) once per component and puts the
	/// results on one scale, so it can answer a graph with many components and many nodes that have
	/// no ties at all. It is the measure the refusal's documentation points to (ADR-010).
	///
	/// ## What a score means
	///
	/// - **Components** are read through ties of positive weight, the reading `eigenvector` uses to
	///   decide connectivity. A tie of weight zero does not connect.
	/// - **A node with no tie of positive weight scores exactly 0**: no ties, no centrality. This is a
	///   defined value, not the 1 that `eigenvector` gives a one-node graph. Such nodes are counted in
	///   ``ComponentwiseScores/isolatedCount``, not listed.
	/// - **Within a component** the scores are `eigenvector`'s, in the same ratios, so the order inside
	///   a component is exact.
	/// - **Across components** the scale is a convention. Eigenvectors of separate components are
	///   defined only up to an independent factor each. Here every component is scaled so that the
	///   mean square of its scores, taken over its own members, is the same in every component, and
	///   then all are scaled together so the largest score is exactly 1. In terms of the
	///   per-component scores `s` (largest 1) and `rms = sqrt(mean(s^2))` of a component, a node
	///   scores `s * min(rms over components) / rms`. A typical member of any component scores about
	///   the same; a hub scores high in proportion to how much more sharply peaked its component is.
	///   It is not a measurement of how much more important one component is than another. The factor
	///   applied is stored per component (``ComponentScoring/scale``), so the per-component scale can
	///   be recovered by dividing by it.
	/// - **One component and no isolated node**: bit-identical to `eigenvector`, with its convergence
	///   report, so this is a strict extension of `eigenvector-centrality` version 5.
	///
	/// ## Convergence
	///
	/// ``ComponentwiseScores/convergence`` is the worst case over the components that were iterated:
	/// converged only if every one did, the most passes, the largest final change. The detail is in
	/// ``ComponentwiseScores/components``, one entry per component of two or more nodes. For a graph
	/// with nothing to iterate it is zero passes and converged.
	///
	/// ## What it throws, and what it does not say
	///
	/// - It throws only what ``eigenvectorConvergence(_:maxIterations:tolerance:)`` and
	///   ``WeightedGraph/init(edges:isolatedNodes:)`` throw on a component. A component is connected
	///   by construction, so ``GraphMeasureError/disconnectedGraph(components:)`` is not reachable, and
	///   a graph whose weights were accepted by `WeightedGraph` is not refused here.
	/// - **The overflow limit is inherited, not new.** For weights so large that their squares
	///   overflow (about 1e154 and above) `eigenvectorConvergence` returns all zeros and reports
	///   convergence (ADR-009 item 5 records that it predates the refusal). A component like that
	///   scores 0 here, keeps a scale of 1, and is not counted as isolated; it is the same silence as
	///   in `eigenvector`, not an additional one. At the other end (weights of about 1e-200 and below,
	///   measured) the squares underflow and every node of the component scores 1, also reported as
	///   converged. Rescale the weights first (the measure is invariant to a common factor).
	/// - A `maxIterations` below one is run as one and reported as one; `tolerance` is taken as given.
	///
	/// - Parameters:
	///   - graph: The graph. It need not be connected.
	///   - maxIterations: Iteration ceiling for each component. Never fewer than one pass is run.
	///   - tolerance: Convergence threshold on the L1 change per pass, for each component.
	/// - Returns: The scores, and how each component converged.
	/// - Throws: What the per-component iteration and the subgraph construction throw; see above.
	///
	/// ```swift
	/// let graph = try WeightedGraph(
	///     edges: [("a", "b", 1), ("b", "c", 1), ("d", "e", 1)], isolatedNodes: ["z"])
	/// let result = try Centrality.eigenvectorByComponent(graph)
	/// print(result.scores["b"] ?? 0)   // 1.0
	/// print(result.scores["z"] ?? 0)   // 0.0
	/// print(result.components.count)   // 2
	/// ```
	public static func eigenvectorByComponent<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, maxIterations: Int = 200, tolerance: Double = 1e-10
	) throws -> ComponentwiseScores<Node> {
		let ceiling = max(1, maxIterations)
		let groups = positiveTieComponents(graph)
		let scored = groups.filter { $0.count > 1 }
		let isolated = groups.count - scored.count

		// Nothing to iterate: no node has a tie of positive weight.
		guard !scored.isEmpty else {
			return ComponentwiseScores(
				scores: NodeScores(Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) })),
				convergence: ConvergenceReport(
					iterations: 0, converged: true, residual: 0, tolerance: tolerance, maxIterations: ceiling),
				components: [], isolatedCount: isolated)
		}

		// One component and no isolate: the whole graph, as eigenvector scores it.
		if scored.count == 1 && isolated == 0 {
			let run = try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: tolerance)
			let report = ConvergenceReport(
				iterations: run.iterations, converged: run.converged, residual: run.residual,
				tolerance: tolerance, maxIterations: ceiling)
			return ComponentwiseScores(
				scores: run.scores, convergence: report,
				components: [ComponentScoring(anchor: graph.nodes[0], size: graph.nodeCount, convergence: report, scale: 1)],
				isolatedCount: 0)
		}

		return try scoreScaledComponents(
			of: graph, groups: scored, isolated: isolated,
			maxIterations: maxIterations, tolerance: tolerance, ceiling: ceiling)
	}

	/// Scores each component of two or more nodes on its own subgraph and puts them on the shared scale.
	private static func scoreScaledComponents<Node: Hashable & Comparable & Sendable>(
		of graph: WeightedGraph<Node>, groups scored: [[Int]], isolated: Int,
		maxIterations: Int, tolerance: Double, ceiling: Int
	) throws -> ComponentwiseScores<Node> {
		var parts: [(members: [Int], scores: [Double], report: ConvergenceReport, rms: Double)] = []
		for members in scored {
			let sub = try subgraph(of: graph, members: members)
			let run = try eigenvectorConvergence(sub, maxIterations: maxIterations, tolerance: tolerance)
			let values = sub.nodes.map { run.scores[$0] ?? 0 }
			let meanSquare = values.reduce(0) { $0 + $1 * $1 } / Double(max(1, values.count))
			parts.append((
				members, values,
				ConvergenceReport(
					iterations: run.iterations, converged: run.converged, residual: run.residual,
					tolerance: tolerance, maxIterations: ceiling),
				meanSquare.squareRoot()))
		}

		// A component's rms is at least 1 / sqrt(size) because its largest score is 1, unless the
		// iteration overflowed and returned zeros (see the documentation above); such a component
		// keeps a scale of 1 and stays at 0, and if every component is like that there is no
		// smallest rms to scale by.
		let smallest: Double? = parts.map(\.rms).filter { $0 > 0 }.min()
		var scores: [Node: Double] = [:]
		for node in graph.nodes { scores[node] = 0 }
		var details: [ComponentScoring<Node>] = []
		for part in parts {
			let scale: Double
			if let smallest, part.rms > 0 {
				scale = smallest / part.rms
			} else {
				scale = 1
			}
			for (offset, index) in part.members.enumerated() {
				scores[graph.nodes[index]] = part.scores[offset] * scale
			}
			details.append(ComponentScoring(
				anchor: graph.nodes[part.members[0]], size: part.members.count,
				convergence: part.report, scale: scale))
		}

		let worst = ConvergenceReport(
			iterations: parts.map(\.report.iterations).max() ?? 0,
			converged: parts.allSatisfy { $0.report.converged },
			residual: parts.map(\.report.residual).max() ?? 0,
			tolerance: tolerance, maxIterations: ceiling)
		return ComponentwiseScores(
			scores: NodeScores(scores), convergence: worst,
			components: details, isolatedCount: isolated)
	}


	/// The connected components of the graph read through ties of positive weight, each as the
	/// indices of its nodes in ascending order, ordered by their lowest node. A node with no tie
	/// of positive weight is a component of one.
	static func positiveTieComponents<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>
	) -> [[Int]] {
		var seen = [Bool](repeating: false, count: graph.nodeCount)
		var groups: [[Int]] = []
		for start in 0..<graph.nodeCount where !seen[start] {
			seen[start] = true
			var members = [start]
			var head = 0
			while head < members.count {
				let node = members[head]
				head += 1
				for (neighbour, weight) in graph.adjacency[node] where weight > 0 && !seen[neighbour] {
					seen[neighbour] = true
					members.append(neighbour)
				}
			}
			groups.append(members.sorted())
		}
		return groups
	}

	/// The graph restricted to `members`, keeping only ties of positive weight.
	private static func subgraph<Node: Hashable & Comparable & Sendable>(
		of graph: WeightedGraph<Node>, members: [Int]
	) throws -> WeightedGraph<Node> {
		var edges: [(Node, Node, Double)] = []
		for index in members {
			for (neighbour, weight) in graph.adjacency[index] where weight > 0 && index < neighbour {
				edges.append((graph.nodes[index], graph.nodes[neighbour], weight))
			}
		}
		return try WeightedGraph(edges: edges)
	}
}
