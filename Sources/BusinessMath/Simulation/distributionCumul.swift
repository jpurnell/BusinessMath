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
		guard Self.knotsAreWellFormed(lower: lower, upper: upper,
									  values: values, probabilities: probabilities) else {
			return nil
		}

		let knotX: [Double] = [lower] + values + [upper]
		let knotP: [Double] = [0.0] + probabilities + [1.0]
		guard let reciprocals = Self.segmentReciprocals(xs: knotX, ps: knotP) else { return nil }

		self.lower = lower
		self.upper = upper
		self.xs = knotX
		self.ps = knotP
		self.inverseSpans = reciprocals.spans
		self.inverseRises = reciprocals.rises
	}

	/// Whether the supplied points describe a cumulative curve at all.
	///
	/// Split out of the initialiser because seven conditions in a row is the whole of
	/// its branching, and reading them together — rather than interleaved with the
	/// arithmetic that follows — is the point of stating them.
	private static func knotsAreWellFormed(lower: Double, upper: Double,
										   values: [Double],
										   probabilities: [Double]) -> Bool {
		guard lower.isFinite, upper.isFinite, upper > lower else { return false }
		guard !values.isEmpty, values.count == probabilities.count else { return false }
		guard values.allSatisfy({ $0.isFinite }) else { return false }
		guard probabilities.allSatisfy({ $0.isFinite }) else { return false }
		guard values.allSatisfy({ $0 > lower && $0 < upper }) else { return false }
		guard probabilities.allSatisfy({ $0 > 0 && $0 < 1 }) else { return false }

		let strictlyIncreasing = zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
		let nonDecreasing = zip(probabilities, probabilities.dropFirst()).allSatisfy { $0 <= $1 }
		return strictlyIncreasing && nonDecreasing
	}

	/// One reciprocal per segment, formed once so ``cdf(_:)`` and ``quantile(_:)``
	/// multiply instead of dividing.
	///
	/// Each span is positive because the abscissae strictly increase and both bounds lie
	/// strictly outside them, which ``knotsAreWellFormed(lower:upper:values:probabilities:)``
	/// has already established — the guard below restates it where the division happens.
	///
	/// - Returns: `nil` if any span is non-positive, which would mean the invariant is
	///   broken rather than that the caller passed something odd.
	private static func segmentReciprocals(xs: [Double], ps: [Double])
		-> (spans: [Double], rises: [Double])? {
		var spans: [Double] = []
		var rises: [Double] = []
		spans.reserveCapacity(xs.count - 1)
		rises.reserveCapacity(xs.count - 1)
		for i in 1..<xs.count {
			let span: Double = xs[i] - xs[i - 1]
			guard span > 0 else { return nil }
			spans.append(1 / span)
			// A flat segment has no rise; `quantile` takes a separate branch for it and
			// never reads this entry, so zero is a placeholder and not a reciprocal.
			let rise: Double = ps[i] - ps[i - 1]
			rises.append(rise > 0 ? 1 / rise : 0)
		}
		return (spans, rises)
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
