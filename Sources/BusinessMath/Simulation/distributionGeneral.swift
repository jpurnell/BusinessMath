//
//  distributionGeneral.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A distribution stated by its density: a piecewise-linear probability density
/// through weighted points the caller supplies.
///
/// The companion to ``DistributionCumul``. Where that one takes points on the
/// cumulative curve, this takes the *shape* of the density and normalises it — which
/// is the more natural way to say "twice as likely around here as around there"
/// without having to work out the percentiles that implies.
///
/// Binds Risk Solver's `PsiGeneral(a, b, {x₁..xₙ}, {w₁..wₙ})`.
///
/// ```swift
/// // A hump centred on 5, tailing off toward both bounds.
/// if let shape = DistributionGeneral(lower: 0, upper: 10,
///                                    values: [2, 5, 8],
///                                    weights: [1, 4, 1]) {
///     print(shape.quantile(0.5))   // 5, by symmetry
/// }
/// ```
///
/// ## Weights are relative, not probabilities
///
/// They need not sum to anything in particular. `[1, 4, 1]` and `[10, 40, 10]` describe
/// the same distribution; only the ratios matter. The curve is scaled so the area under
/// it is one.
///
/// ## The density at the bounds, which the reference does not state
///
/// Frontline defines `PsiGeneral` as "a custom continuous distribution with lower and
/// upper bounds equal to a and b … and with user specified values and corresponding
/// weights", and says it is "similar to a `PsiCumul` … where the probabilities are
/// calculated using the weights". It does not say what the density is at `a` and `b`
/// when no point is supplied there, and that changes the distribution.
///
/// **This type takes the density to be zero at any bound not given an explicit point.**
/// So `lower: 0, upper: 10, values: [2, 5, 8]` describes a density rising from zero at
/// 0, through the three weights, and falling back to zero at 10. Supplying a point at a
/// bound overrides that: `values: [0, 5, 10]` anchors the density to the weights you
/// give there.
///
/// The reason to pick this reading over constant extrapolation is that it is the one
/// the caller can override. If the intent were a non-zero density at the bound, saying
/// so takes one more point; if the convention were extrapolation, a caller wanting zero
/// at the bound would have no way to ask for it, since a point *at* the bound with
/// weight zero and constant extrapolation are the same thing. A convention that can be
/// overridden is safer than one that cannot.
///
/// Where the distinction matters to a result, state the endpoints explicitly and the
/// question does not arise.
///
/// ## The mathematics
///
/// Between consecutive knots the density is linear, so each segment contributes a
/// trapezoid of area `(w₁ + w₂)·(x₂ − x₁)/2` and the CDF over that segment is a
/// **quadratic** in `x`. Inverting it means solving that quadratic:
///
/// ```
/// F(x) = F(x₁) + [w₁·t + (w₂ − w₁)·t²/2]·(x₂ − x₁)/A ,  t = (x − x₁)/(x₂ − x₁)
/// ```
///
/// where `A` is the total unnormalised area. For a segment of constant weight the
/// quadratic term vanishes and the inverse is linear; ``quantile(_:)`` takes that
/// branch rather than dividing by a zero coefficient.
///
/// - SeeAlso: ``DistributionCumul``
public struct DistributionGeneral: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support.
	public let lower: Double

	/// The upper bound of the support.
	public let upper: Double

	/// Knot abscissae, spanning `lower` to `upper`.
	private let xs: [Double]

	/// Normalised density at each knot, so the area under the curve is one.
	private let densities: [Double]

	/// Cumulative probability at each knot. First entry 0, last exactly 1.
	private let cumulative: [Double]

	/// Creates a distribution from the shape of its density.
	///
	/// - Parameters:
	///   - lower: The lower bound.
	///   - upper: The upper bound. Must exceed `lower`.
	///   - values: Abscissae, strictly increasing, each within `lower...upper`.
	///   - weights: A relative density at each of `values`. Non-negative and finite,
	///     not all zero.
	/// - Returns: `nil` if the arrays differ in length or are empty, if anything is
	///   non-finite, if `values` is not strictly increasing or strays outside the
	///   bounds, if any weight is negative, or if the resulting curve encloses no area.
	public init?(lower: Double, upper: Double, values: [Double], weights: [Double]) {
		guard lower.isFinite, upper.isFinite, upper > lower else { return nil }
		guard !values.isEmpty, values.count == weights.count else { return nil }
		guard values.allSatisfy({ $0.isFinite }), weights.allSatisfy({ $0.isFinite }) else {
			return nil
		}
		guard values.allSatisfy({ $0 >= lower && $0 <= upper }) else { return nil }
		guard weights.allSatisfy({ $0 >= 0 }) else { return nil }
		for i in 1..<values.count where values[i] <= values[i - 1] { return nil }

		// Anchor the curve at each bound not already carrying a point — see the note on
		// the type about why the anchor is zero and why that is the overridable choice.
		var knotX = values
		var knotW = weights
		if let first = values.first, first > lower {
			knotX.insert(lower, at: 0)
			knotW.insert(0, at: 0)
		}
		if let last = values.last, last < upper {
			knotX.append(upper)
			knotW.append(0)
		}

		// Trapezoidal area under the unnormalised curve.
		var area = 0.0
		for i in 1..<knotX.count {
			let span: Double = knotX[i] - knotX[i - 1]
			let averageHeight: Double = (knotW[i] + knotW[i - 1]) / 2
			area += span * averageHeight
		}
		guard area > 0, area.isFinite else { return nil }

		// `area` is positive, guarded on the line above.
		let inverseArea: Double = 1 / area
		let normalised = knotW.map { $0 * inverseArea }

		// One reciprocal per segment; each span is positive because the abscissae
		// strictly increase and the anchors sit outside them.
		var spanReciprocals: [Double] = []
		spanReciprocals.reserveCapacity(knotX.count - 1)
		for i in 1..<knotX.count {
			let span: Double = knotX[i] - knotX[i - 1]
			guard span > 0 else { return nil }
			spanReciprocals.append(1 / span)
		}

		var running = 0.0
		var sums: [Double] = [0.0]
		sums.reserveCapacity(knotX.count)
		for i in 1..<knotX.count {
			let span: Double = knotX[i] - knotX[i - 1]
			let averageHeight: Double = (normalised[i] + normalised[i - 1]) / 2
			running += span * averageHeight
			sums.append(running)
		}
		// Pin the top. The trapezoids sum to one only to within rounding, and both
		// `cdf` and `quantile` rely on the last entry being exactly the upper limit.
		sums[sums.count - 1] = 1.0

		self.lower = lower
		self.upper = upper
		self.xs = knotX
		self.densities = normalised
		self.cumulative = sums
		self.inverseSpans = spanReciprocals
	}

	/// `1/(xs[i] − xs[i−1])` for each segment, formed in the initialiser beside the
	/// guard proving each span positive.
	private let inverseSpans: [Double]

	/// The normalised probability density at `x`, zero outside the support.
	public func pdf(_ x: Double) -> Double {
		guard x >= lower, x <= upper else { return 0 }
		for i in 1..<xs.count where x <= xs[i] {
			let position: Double = (x - xs[i - 1]) * inverseSpans[i - 1]
			let rise: Double = densities[i] - densities[i - 1]
			return densities[i - 1] + position * rise
		}
		return densities[densities.count - 1]
	}

	/// P(X ≤ x). Quadratic within each segment, because the density is linear there.
	public func cdf(_ x: Double) -> Double {
		guard x > lower else { return 0 }
		guard x < upper else { return 1 }

		for i in 1..<xs.count where x <= xs[i] {
			let span: Double = xs[i] - xs[i - 1]
			let t: Double = (x - xs[i - 1]) * inverseSpans[i - 1]
			let base: Double = densities[i - 1] * t
			let rise: Double = densities[i] - densities[i - 1]
			let curve: Double = rise * t * t / 2
			let added: Double = (base + curve) * span
			return Swift.min(cumulative[i - 1] + added, 1.0)
		}
		return 1
	}

	/// The value at which the CDF equals `p`.
	///
	/// Inverts the per-segment quadratic. Where a segment has constant density the
	/// quadratic degenerates and the linear branch is taken instead, rather than
	/// dividing by a vanishing leading coefficient.
	///
	/// - Parameter p: A probability. Values at or outside the endpoints clamp to the
	///   bounds, which are finite here.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return lower }
		guard p < 1 else { return upper }

		for i in 1..<cumulative.count where p <= cumulative[i] {
			let needed: Double = p - cumulative[i - 1]
			let span: Double = xs[i] - xs[i - 1]
			let startDensity: Double = densities[i - 1]
			let rise: Double = densities[i] - densities[i - 1]

			// Solve  startDensity·t + rise·t²/2 = needed/span  for t in [0, 1].
			let target: Double = needed * inverseSpans[i - 1]
			guard target > 0 else { return xs[i - 1] }

			if abs(rise) < 1e-15 {
				// Constant density: the segment is a rectangle. The guard makes the
				// division safe and also catches a zero-density segment, which carries
				// no mass and so is first reached at its left edge.
				guard startDensity > 0 else { return xs[i - 1] }
				let t: Double = target / startDensity
				return xs[i - 1] + span * Swift.min(t, 1.0)
			}

			// (rise/2)·t² + startDensity·t − target = 0
			let a: Double = rise / 2
			let discriminant: Double = startDensity * startDensity + 4 * a * target
			let root: Double = Swift.max(discriminant, 0).squareRoot()
			// `rise` is non-zero: the branch above handles the degenerate case.
			guard rise != 0 else { return xs[i - 1] }
			let t: Double = (root - startDensity) / rise
			let clamped: Double = Swift.min(Swift.max(t, 0), 1)
			return xs[i - 1] + span * clamped
		}
		return upper
	}
}
