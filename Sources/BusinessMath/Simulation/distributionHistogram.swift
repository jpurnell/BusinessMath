//
//  distributionHistogram.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A histogram distribution: equal-width bins over `[min, max]`, each with a weight.
///
/// The shape you have when the evidence is a bar chart. Binds Risk Solver's
/// `PsiHistogram(a, b, {w₁..wₙ})`.
///
/// ```swift
/// // Four quarters of the range, with the third the most likely.
/// if let demand = DistributionHistogram(min: 0, max: 100, weights: [1, 3, 5, 2]) {
///     print(demand.quantile(0.5))   // 55.0
///     print(demand.mean)            // 54.545...
/// }
/// ```
///
/// ## What it is
///
/// Piecewise uniform. Within a bin the density is flat, so the CDF is piecewise linear
/// and the quantile is its exact inverse — no root-finding, and every value returned
/// lies inside the stated range by construction.
///
/// The weights are relative and need not sum to anything in particular; they are
/// normalised on the way in. A zero weight is allowed and means exactly what it says:
/// that bin cannot occur, and the quantile function steps across it. All-zero is
/// refused, because a distribution with no mass is not a distribution.
///
/// ## Why not just a `DistributionCumul`
///
/// ``DistributionCumul`` takes a *cumulative* curve at arbitrary abscissae; this takes
/// *densities* on a uniform grid. The two are convertible, and the conversion is
/// exactly the arithmetic below — but a caller holding bar heights should not have to
/// integrate them by hand, and a caller holding a cumulative curve should not have to
/// difference it.
public struct DistributionHistogram: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support.
	public let min: Double

	/// The upper bound of the support.
	public let max: Double

	/// The bin weights as supplied, before normalisation.
	public let weights: [Double]

	/// Cumulative probability at each bin edge, `0` first and `1` last.
	private let cumulative: [Double]

	/// The width of one bin, and its reciprocal.
	private let binWidth: Double
	private let inverseBinWidth: Double

	/// Creates a histogram distribution.
	///
	/// - Parameters:
	///   - min: The lower bound.
	///   - max: The upper bound, strictly greater than `min`.
	///   - weights: One relative weight per equal-width bin, all non-negative and at
	///     least one positive.
	/// - Returns: `nil` if the range has no width, if any weight is negative or not
	///   finite, or if every weight is zero.
	public init?(min: Double, max: Double, weights: [Double]) {
		guard min.isFinite, max.isFinite, max > min else { return nil }
		guard !weights.isEmpty else { return nil }
		guard weights.allSatisfy({ $0 >= 0 && $0.isFinite }) else { return nil }

		let total: Double = weights.reduce(0, +)
		guard total > 0 else { return nil }

		let span: Double = max - min
		guard span > 0 else { return nil }
		let width: Double = span / Double(weights.count)
		guard width > 0 else { return nil }

		var edges = [Double](repeating: 0, count: weights.count + 1)
		var running = 0.0
		for (index, weight) in weights.enumerated() {
			running += weight
			// Divided by the total, which the guard above proves positive.
			edges[index + 1] = running / total
		}
		// The last edge is 1 by construction; set it exactly so a quantile at p near 1
		// cannot fall off the end through accumulated rounding.
		edges[weights.count] = 1

		self.min = min
		self.max = max
		self.weights = weights
		self.cumulative = edges
		self.binWidth = width
		self.inverseBinWidth = 1 / width
	}

	/// The number of bins.
	public var binCount: Int { weights.count }

	/// The mean, `Σ wᵢ·midpointᵢ / Σ wᵢ`.
	public var mean: Double {
		var total = 0.0
		for index in 0..<weights.count {
			let probability: Double = cumulative[index + 1] - cumulative[index]
			let left: Double = min + Double(index) * binWidth
			let midpoint: Double = left + binWidth / 2
			total += probability * midpoint
		}
		return total
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value; outside `[min, max]` this returns 0 or 1.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let offset: Double = x - min
		let position: Double = offset * inverseBinWidth
		var index = Int(position)
		if index >= weights.count { index = weights.count - 1 }
		let left: Double = min + Double(index) * binWidth
		let within: Double = (x - left) * inverseBinWidth
		let base: Double = cumulative[index]
		let rise: Double = cumulative[index + 1] - base
		return base + rise * within
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, inside `[min, max]`.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }

		// The first bin whose cumulative edge reaches `p`. A zero-weight bin has equal
		// edges and is stepped over, which is what "that bin cannot occur" means.
		var index = 0
		while index < weights.count, cumulative[index + 1] < p { index += 1 }
		if index >= weights.count { index = weights.count - 1 }

		let base: Double = cumulative[index]
		let rise: Double = cumulative[index + 1] - base
		let left: Double = min + Double(index) * binWidth
		guard rise > 0 else { return left }
		let within: Double = (p - base) / rise
		return left + within * binWidth
	}
}
