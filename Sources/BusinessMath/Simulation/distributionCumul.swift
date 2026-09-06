//
//  distributionCumul.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A distribution stated by its cumulative curve: a piecewise-linear CDF through
/// points the caller supplies.
///
/// This is how a spreadsheet records an elicited distribution. An estimator is asked
/// for a handful of percentiles — "10% chance below 20, even odds below 35, 90% below
/// 60" — and those points *are* the distribution, with straight lines between them.
///
/// Binds Risk Solver's `PsiCumul(a, b, {x₁..xₙ}, {p₁..pₙ})`.
///
/// ```swift
/// if let elicited = DistributionCumul(lower: 0, upper: 100,
///                                     values: [20, 35, 60],
///                                     probabilities: [0.1, 0.5, 0.9]) {
///     print(elicited.quantile(0.5))   // 35
/// }
/// ```
///
/// ## The shape
///
/// The knots are the supplied points with `(lower, 0)` and `(upper, 1)` added, so the
/// CDF starts at zero, ends at one, and interpolates linearly between neighbours. A
/// linear CDF means a **uniform density on each segment**, and the density therefore
/// steps at each knot.
///
/// Equal consecutive probabilities are allowed and mean a gap: no mass falls in that
/// interval. ``quantile(_:)`` returns the left edge of such a flat, which is the
/// smallest `x` reaching that probability and keeps the function monotone.
///
/// - SeeAlso: ``DistributionGeneral``, which states the same kind of custom
///   distribution by its *density* instead of its cumulative curve.
public struct DistributionCumul: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support.
	public let lower: Double

	/// The upper bound of the support.
	public let upper: Double

	/// Knot abscissae, including `lower` first and `upper` last.
	private let xs: [Double]

	/// Cumulative probability at each knot, from 0 to 1.
	private let ps: [Double]

	/// Creates a distribution from points on its cumulative curve.
	///
	/// - Parameters:
	///   - lower: The lower bound, where the CDF is zero.
	///   - upper: The upper bound, where the CDF is one. Must exceed `lower`.
	///   - values: Abscissae, strictly increasing, each strictly inside the bounds.
	///   - probabilities: The CDF at each of `values`, non-decreasing and within
	///     (0, 1). Equal neighbours are allowed and mean an interval with no mass.
	/// - Returns: `nil` if the two arrays differ in length or are empty, if any value
	///   is non-finite, if `values` is not strictly increasing or strays outside the
	///   bounds, or if `probabilities` decreases or leaves the open unit interval.
	///
	///   `values` must increase *strictly*: two knots at the same abscissa would put
	///   finite mass at a point, which a continuous distribution cannot represent and
	///   which would divide by zero in the interpolation. Probabilities of exactly 0 or
	///   1 are excluded because `lower` and `upper` already carry them, and a duplicate
	///   would create a flat at the boundary that says nothing the bounds do not.
	public init?(lower: Double, upper: Double, values: [Double], probabilities: [Double]) {
		guard lower.isFinite, upper.isFinite, upper > lower else { return nil }
		guard !values.isEmpty, values.count == probabilities.count else { return nil }
		guard values.allSatisfy({ $0.isFinite }), probabilities.allSatisfy({ $0.isFinite }) else {
			return nil
		}
		guard values.allSatisfy({ $0 > lower && $0 < upper }) else { return nil }
		guard probabilities.allSatisfy({ $0 > 0 && $0 < 1 }) else { return nil }

		for i in 1..<values.count {
			guard values[i] > values[i - 1] else { return nil }
			guard probabilities[i] >= probabilities[i - 1] else { return nil }
		}

		let knotX: [Double] = [lower] + values + [upper]
		let knotP: [Double] = [0.0] + probabilities + [1.0]

		// One reciprocal per segment, formed here. Each span is positive because the
		// abscissae strictly increase and both bounds lie strictly outside them —
		// checked immediately above — so the divisions cannot fail, and the use sites
		// multiply.
		var spanReciprocals: [Double] = []
		var riseReciprocals: [Double] = []
		spanReciprocals.reserveCapacity(knotX.count - 1)
		riseReciprocals.reserveCapacity(knotX.count - 1)
		for i in 1..<knotX.count {
			let span: Double = knotX[i] - knotX[i - 1]
			guard span > 0 else { return nil }
			spanReciprocals.append(1 / span)
			// A flat segment has no rise; `quantile` takes a separate branch for it and
			// never reads this entry, so zero is a placeholder and not a reciprocal.
			let rise: Double = knotP[i] - knotP[i - 1]
			riseReciprocals.append(rise > 0 ? 1 / rise : 0)
		}

		self.lower = lower
		self.upper = upper
		self.xs = knotX
		self.ps = knotP
		self.inverseSpans = spanReciprocals
		self.inverseRises = riseReciprocals
	}

	/// `1/(xs[i] − xs[i−1])` for each segment.
	private let inverseSpans: [Double]

	/// `1/(ps[i] − ps[i−1])` for each segment, or zero where the segment is flat.
	private let inverseRises: [Double]

	/// P(X ≤ x), by linear interpolation between the knots.
	public func cdf(_ x: Double) -> Double {
		guard x > lower else { return 0 }
		guard x < upper else { return 1 }

		for i in 1..<xs.count where x <= xs[i] {
			let position: Double = (x - xs[i - 1]) * inverseSpans[i - 1]
			let rise: Double = ps[i] - ps[i - 1]
			return ps[i - 1] + position * rise
		}
		return 1
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability. Values at or outside the endpoints clamp to the
	///   bounds, which are finite here.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return lower }
		guard p < 1 else { return upper }

		for i in 1..<ps.count where p <= ps[i] {
			// A flat segment carries no mass, so every probability in it is first
			// reached at the segment's left edge. Its reciprocal is a placeholder zero
			// and must not be used.
			guard ps[i] > ps[i - 1] else { return xs[i - 1] }
			let position: Double = (p - ps[i - 1]) * inverseRises[i - 1]
			let span: Double = xs[i] - xs[i - 1]
			return xs[i - 1] + position * span
		}
		return upper
	}
}
