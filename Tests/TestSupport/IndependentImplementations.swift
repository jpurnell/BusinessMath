//
//  IndependentImplementations.swift
//  TestSupport
//
//  Test-only: deliberately naive reference implementations, never part of the library target.
//

import Foundation
import BusinessMath

/// Deliberately naive implementations, used to check the fast ones.
///
/// ## Why these exist
///
/// The project does not use Python, so the cross-check cannot come from another
/// language. Independence has to come from somewhere else, and here it comes
/// from taking a *different route to the same number*: Brandes' algorithm is
/// checked against brute-force path enumeration, and power iteration against
/// direct matrix multiplication carried to convergence.
///
/// A check written the same way as the thing it checks is not a check. These
/// are written to be obviously correct rather than fast, which is exactly what
/// a reference implementation should be.
///
/// They are unsuitable for the real graph — the betweenness one is cubic — and
/// are used only against fixtures.
public enum IndependentImplementations {

	/// Betweenness by explicit enumeration of every shortest path.
	///
	/// Runs breadth-first search from every node, reconstructs all shortest
	/// paths to every other node, and counts intermediate appearances. Shares
	/// no code with ``Centrality/betweenness(_:normalized:)`` and no idea
	/// beyond the definition.
	///
	/// - Complexity: Roughly `O(n³)`. Fixtures only.
	public static func betweennessByEnumeration<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, normalized: Bool = true
	) -> NodeScores<Node> {
		let count = graph.nodeCount
		var totals = [Double](repeating: 0, count: count)
		guard count > 2 else {
			return NodeScores(Dictionary(
				uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))
		}

		for source in 0..<count {
			// All shortest paths from `source` to every node.
			var paths: [[[Int]]] = Array(repeating: [], count: count)
			paths[source] = [[source]]
			var distance = [Int](repeating: Int.max, count: count)
			distance[source] = 0

			var frontier = [source]
			while !frontier.isEmpty {
				var next: [Int] = []
				for node in frontier {
					for (neighbour, _) in graph.adjacency[node] {
						if distance[neighbour] == Int.max {
							distance[neighbour] = distance[node] + 1
							next.append(neighbour)
						}
						if distance[neighbour] == distance[node] + 1 {
							paths[neighbour].append(
								contentsOf: paths[node].map { $0 + [neighbour] })
						}
					}
				}
				frontier = next
			}

			for target in 0..<count where target != source {
				let routes = paths[target]
				guard !routes.isEmpty else { continue }
				let share = 1.0 / Double(routes.count)
				for route in routes {
					// Endpoints do not count as intermediaries.
					for node in route.dropFirst().dropLast() {
						totals[node] += share
					}
				}
			}
		}

		let pairs = Double((count - 1) * (count - 2))
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			var value = totals[index] / 2
			if normalized, pairs > 0 { value /= (pairs / 2) }
			scores[node] = value
		}
		return NodeScores(scores)
	}

	/// The dominant eigenvector by repeated dense matrix multiplication.
	///
	/// Builds the adjacency matrix explicitly and multiplies to convergence,
	/// rather than iterating over adjacency lists. Same mathematics, different
	/// route, no shared code.
	///
	/// - Complexity: `O(n²)` per iteration. Fixtures only.
	public static func eigenvectorByDenseMatrix<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, iterations: Int = 2_000
	) -> NodeScores<Node> {
		let count = graph.nodeCount
		guard count > 1 else {
			return NodeScores(count == 1 ? [graph.nodes[0]: 1] : [:])
		}

		// The largest weighted degree is added along the diagonal so the
		// iteration converges on a bipartite graph as well: A has -lambda as an
		// eigenvalue there, tying with lambda, and plain repeated
		// multiplication oscillates. A + sI has the same eigenvectors with the
		// dominant eigenvalue strictly largest, and the largest weighted degree
		// is an upper bound on lambda, so s is never too small.
		var matrix = [Double](repeating: 0, count: count * count)
		let shift = (0..<count).map { graph.weightedDegree($0) }.max() ?? 0
		for index in 0..<count { matrix[index * count + index] = shift }
		for (row, neighbours) in graph.adjacency.enumerated() {
			for (column, weight) in neighbours {
				matrix[row * count + column] = weight
			}
		}

		var vector = [Double](repeating: 1, count: count)
		for _ in 0..<max(1, iterations) {
			var product = [Double](repeating: 0, count: count)
			for row in 0..<count {
				var sum = 0.0
				for column in 0..<count {
					sum += matrix[row * count + column] * vector[column]
				}
				product[row] = sum
			}
			let norm = sqrt(product.reduce(0) { $0 + $1 * $1 })
			guard norm > 0 else { break }
			for index in 0..<count { product[index] /= norm }
			vector = product
		}

		let peak = vector.max() ?? 0
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			scores[node] = peak > 0 ? vector[index] / peak : 0
		}
		return NodeScores(scores)
	}

	/// Core numbers by literal repeated peeling.
	///
	/// Repeatedly removes every node whose surviving degree is below `k`,
	/// raising `k` when nothing more can be removed. Slower and more obviously
	/// the definition than ``Community/kCore(_:)``.
	public static func kCoreByPeeling<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		let count = graph.nodeCount
		var alive = [Bool](repeating: true, count: count)
		var core = [Int](repeating: 0, count: count)
		var k = 0

		while alive.contains(true) {
			var changed = true
			while changed {
				changed = false
				for index in 0..<count where alive[index] {
					let degree = graph.adjacency[index]
						.filter { alive[$0.neighbour] }.count
					if degree <= k {
						core[index] = k
						alive[index] = false
						changed = true
					}
				}
			}
			k += 1
			if k > count { break }
		}

		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() { scores[node] = Double(core[index]) }
		return NodeScores(scores)
	}
}
