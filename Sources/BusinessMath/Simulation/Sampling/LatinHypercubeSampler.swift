//
//  LatinHypercubeSampler.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// A Latin hypercube design: every dimension stratified, every stratum used once.
///
/// For `n` points in `d` dimensions, each dimension is cut into `n` equal strata and
/// each stratum contributes exactly one point. Within a dimension the strata are
/// visited in a random order, and the orders are drawn independently per dimension —
/// which is what makes the design cover the cube rather than its diagonal.
///
/// The guarantee is one-dimensional and worth stating precisely: **every marginal is
/// perfectly stratified, and no claim is made about joint coverage.** That is already
/// a large improvement for a simulation whose output is dominated by a few inputs,
/// which is the common case, and it is why Latin hypercube is the sampling method
/// people ask for first.
///
/// ## Correlated runs
///
/// This composes with ``MonteCarloSimulation``'s correlated path at no cost. That path
/// uses Iman–Conover: draw each marginal independently, sort, then reorder by
/// correlated ranks. Reordering permutes a marginal sample without changing which
/// values are in it, so a stratified marginal stays stratified through the
/// reordering — which is why Latin hypercube and rank correlation are the standard
/// pairing.
///
/// ## Example
///
/// ```swift
/// let design = LatinHypercubeSampler(dimension: 3, seed: 20_260_904)
/// let points = design.points(count: 1_000)
/// // Every [k/1000, (k+1)/1000) holds exactly one point, in each of the 3 dimensions.
/// ```
public struct LatinHypercubeSampler: QuasiRandomPointSet {

	/// How many coordinates each point carries.
	public let dimension: Int

	/// The seed for the stratum permutation and the within-stratum jitter.
	public let seed: UInt64

	/// Creates a Latin hypercube design.
	///
	/// - Parameters:
	///   - dimension: How many coordinates each point carries. Must be positive.
	///   - seed: Makes the design reproducible. Required — see
	///     ``SamplingMethod/latinHypercube``.
	public init(dimension: Int, seed: UInt64) {
		self.dimension = Swift.max(1, dimension)
		self.seed = seed
	}

	/// `count` points forming a Latin hypercube design.
	///
	/// - Parameter count: The number of points, which is also the number of strata.
	/// - Returns: A `count` × ``dimension`` array with coordinates strictly inside `(0, 1)`.
	public func points(count: Int) -> [[Double]] {
		guard count > 0 else { return [] }

		var generator = Xoshiro256StarStar(seed: seed)
		let strata = Double(count)

		// Column-major while building: a permutation belongs to a dimension, not to a
		// point.
		var columns: [[Double]] = []
		columns.reserveCapacity(dimension)

		for _ in 0..<dimension {
			var order = Array(0..<count)
			// Fisher–Yates, from the seeded generator so the design is reproducible.
			if count > 1 {
				for index in stride(from: count - 1, to: 0, by: -1) {
					let swapWith = Int(generator.next(upperBound: UInt64(index + 1)))
					order.swapAt(index, swapWith)
				}
			}

			var column: [Double] = []
			column.reserveCapacity(count)
			for stratum in order {
				// Somewhere inside the stratum, never on either edge.
				let offset = Double.openUnitRandom(using: &generator)
				column.append((Double(stratum) + offset) / strata)
			}
			columns.append(column)
		}

		return (0..<count).map { point in
			columns.map { $0[point] }
		}
	}
}
