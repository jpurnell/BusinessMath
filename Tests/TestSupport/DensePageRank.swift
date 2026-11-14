//
//  DensePageRank.swift
//  BusinessMath
//
//  Test support, not library code. PageRank by a dense linear solve, sharing nothing with
//  `Centrality.pageRank`'s iteration, so a convergence claim can be checked against the exact
//  fixed point rather than against the loop's own later iterates.
//

import Foundation
import BusinessMath

extension IndependentImplementations {

	/// The PageRank fixed point by Gaussian elimination with partial pivoting.
	///
	/// Solves `(I - d M) x = (1 - d) / n` where `M` is the column-stochastic transition matrix
	/// (a tie's share is its weight over the source's weighted degree; a node with no weighted
	/// tie spreads its mass uniformly over every node, itself included). This is the same model
	/// `Centrality.pageRank` iterates, written as a direct solve.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - damping: The damping, in `[0, 1)`.
	/// - Returns: The exact scores, summing to one, in `graph.nodes` order.
	/// - Complexity: `O(n^3)`. Fixtures only.
	public static func pageRankByDenseSolve<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, damping: Double
	) -> [Double] {
		let count = graph.nodeCount
		guard count > 0 else { return [] }
		let size = Double(count)

		// Row-major augmented matrix [A | b].
		var matrix = [[Double]](repeating: [Double](repeating: 0, count: count + 1), count: count)
		for row in 0..<count {
			matrix[row][row] = 1
			matrix[row][count] = (1 - damping) / size
		}
		for source in 0..<count {
			let degree = graph.weightedDegree(source)
			if degree > 0 {
				for (target, weight) in graph.adjacency[source] {
					matrix[target][source] -= damping * weight / degree
				}
			} else {
				for target in 0..<count { matrix[target][source] -= damping / size }
			}
		}

		for column in 0..<count {
			var pivot = column
			for row in column..<count where abs(matrix[row][column]) > abs(matrix[pivot][column]) {
				pivot = row
			}
			matrix.swapAt(column, pivot)
			let lead = matrix[column][column]
			guard lead != 0 else { continue }
			for row in 0..<count where row != column {
				let factor = matrix[row][column] / lead
				guard factor != 0 else { continue }
				for entry in column...count { matrix[row][entry] -= factor * matrix[column][entry] }
			}
		}
		return (0..<count).map { matrix[$0][count] / matrix[$0][$0] }
	}
}
