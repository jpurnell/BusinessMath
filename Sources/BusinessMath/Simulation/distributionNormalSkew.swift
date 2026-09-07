//
//  distributionNormalSkew.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension DistributionMyerson {

	/// The probability mass a normal places within three standard deviations of its
	/// mean, `Φ(3) − Φ(−3)` — the familiar 99.73%.
	///
	/// Computed rather than written down. Frontline's own documentation quotes the
	/// complementary tail as `0.002699796146511`, which is `2Φ(−3)` to nine figures
	/// and then diverges from it; taking the number from the normal CDF this library
	/// already has means the bounds land on ±3σ exactly rather than on whatever
	/// transcription of the constant happened to be copied.
	static var threeSigmaCoverage: Double {
		let upper: Double = normalCDF(x: 3, mean: 0, stdDev: 1)
		let lower: Double = normalCDF(x: -3, mean: 0, stdDev: 1)
		return upper - lower
	}

	/// A skewed generalisation of the normal, stated by its bounds and a single skew
	/// number.
	///
	/// Binds Risk Solver's `PsiNormalSkew(a, b, c)`.
	///
	/// ```swift
	/// let symmetric = DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: 0)
	/// let leftTailed = DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: 0.4)
	/// ```
	///
	/// ## What the bounds mean
	///
	/// They are not the support. `a` and `b` are the points a *normal* would place at
	/// −3σ and +3σ, so at `skew == 0` this is exactly `DistributionNormal` with mean
	/// `(a + b)/2` and standard deviation `(b − a)/6`. The distribution runs past both
	/// in the tails, as a normal does; calling them bounds is Frontline's usage, kept
	/// here so the binding is recognisable, and contradicted in this sentence so
	/// nobody clamps a simulation to them.
	///
	/// ## Why this is a Myerson
	///
	/// Frontline says so — "the lower and upper bounds are exactly the same as in the
	/// Myerson distribution", with the tail argument fixed rather than free. So this
	/// is a factory rather than a distribution: the recursion, the quantile and the
	/// CDF are ``DistributionMyerson``'s, and a second type carrying the same
	/// arithmetic would only be somewhere for the two to drift apart.
	///
	/// ## The one thing the documentation does not state
	///
	/// It gives no formula relating `c` to the shape, only that `c` lies strictly
	/// inside `(-1, 1)`, that zero is symmetric, and that a positive `c` skews left.
	/// This places the median linearly between the bounds:
	///
	/// ```
	/// median = (a + b)/2 + c · (b − a)/2
	/// ```
	///
	/// Two arguments for that reading. First, the two natural formulations agree: a
	/// linear median gives a Myerson asymmetry of `(1 − c)/(1 + c)`, which is also
	/// what one writes down going directly for a shape ratio that is one at `c = 0`,
	/// so there is no fork to choose between. Second, the exclusive range is the tell
	/// — `c ∈ (-1, 1)` open corresponds exactly to `median ∈ (a, b)` open under this
	/// map, where any exponential alternative would need a rate constant from nowhere
	/// and would not explain why the endpoints are excluded.
	///
	/// The direction follows and matches the documentation: a positive `c` moves the
	/// median toward `b`, which lengthens the *left* arm, which is a left skew.
	///
	/// - Parameters:
	///   - lowerBound: `a`, the −3σ point. Must be strictly below `upperBound`.
	///   - upperBound: `b`, the +3σ point.
	///   - skew: `c`, strictly inside `(-1, 1)`. Zero is the normal. Positive skews
	///     left, negative right.
	/// - Returns: The distribution, or `nil` if the bounds are not ordered and finite
	///   or the skew is outside `(-1, 1)`.
	static func normalSkew(lowerBound: Double, upperBound: Double, skew: Double) -> DistributionMyerson? {
		guard lowerBound.isFinite, upperBound.isFinite, skew.isFinite else { return nil }
		guard lowerBound < upperBound else { return nil }
		guard skew > -1, skew < 1 else { return nil }
		let midpoint: Double = (lowerBound + upperBound) / 2
		let halfRange: Double = (upperBound - lowerBound) / 2
		let offset: Double = skew * halfRange
		let median: Double = midpoint + offset
		return DistributionMyerson(low: lowerBound, mode: median, high: upperBound,
								   probability: Self.threeSigmaCoverage)
	}

	/// The standard deviation of the symmetric member, `(b − a)/6`.
	///
	/// Only the `skew == 0` case has a standard deviation this simple; it is offered
	/// because it is the check that pins what the bounds mean, and a caller
	/// reconstructing it by hand is a caller who might reconstruct it as `(b − a)/4`.
	///
	/// - Parameters:
	///   - lowerBound: `a`, the −3σ point.
	///   - upperBound: `b`, the +3σ point.
	/// - Returns: The scale a symmetric normal-skew has, or `nil` for unordered bounds.
	static func normalSkewSymmetricScale(lowerBound: Double, upperBound: Double) -> Double? {
		guard lowerBound.isFinite, upperBound.isFinite, lowerBound < upperBound else { return nil }
		let range: Double = upperBound - lowerBound
		return range / 6
	}
}
