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
	/// ## The step the documentation leaves out, since measured
	///
	/// Frontline's page gives no formula relating `c` to the shape. That gap was closed
	/// by measurement rather than argument — see
	/// ``normalSkewMedian(lowerBound:upperBound:skew:)``, which carries the numbers.
	///
	/// - Parameters:
	///   - lowerBound: `a`, the −3σ point. Must be strictly below `upperBound`.
	///   - upperBound: `b`, the +3σ point.
	///   - skew: `c`, strictly inside `(-1, 1)`. Zero is the normal. Positive skews
	///     left, negative right.
	/// - Returns: The distribution, or `nil` if the bounds are not ordered and finite
	///   or the skew is outside `(-1, 1)`.
	static func normalSkew(lowerBound: Double, upperBound: Double, skew: Double) -> DistributionMyerson? {
		guard let median = normalSkewMedian(lowerBound: lowerBound,
											upperBound: upperBound, skew: skew) else {
			return nil
		}
		return DistributionMyerson(low: lowerBound, mode: median, high: upperBound,
								   probability: Self.threeSigmaCoverage)
	}

	/// Where `PsiNormalSkew` puts the median for a given skew.
	///
	/// ```
	/// median = (a + b)/2 + c · (b − a)/2
	/// ```
	///
	/// ## Measured against Risk Solver, not inferred
	///
	/// Everything else about ``normalSkew(lowerBound:upperBound:skew:)`` comes straight
	/// from Frontline's page: that it is a Myerson, that the bounds are ±3σ, that the
	/// tail is `2Φ(-3)`. Only this map is unstated upstream, so it lives here by itself
	/// — one named function, and the only place that would need changing if the
	/// measurement below were ever contradicted.
	///
	/// `PsiNormalSkew(0, 60, 0.5)` was sampled in Excel 2010 with Risk Solver, roughly
	/// two hundred draws:
	///
	/// | | this map | per-sigma alternative | measured |
	/// |---|---|---|---|
	/// | mean | 43.4396 | 34.45 | ≈ 43.5 |
	/// | median | 45 | 35 | ≈ 45 |
	/// | standard deviation | 9.1147 | 9.91 | ≈ 9 |
	///
	/// All three agree, and the agreement is worth more than the median alone: the mean
	/// falls *below* the median — the left skew Frontline's prose describes — and that
	/// number depends on the asymmetry `(1 − c)/(1 + c)`, the tail `z = 3` and the
	/// coverage all being right at once. Matching mean, median and spread together pins
	/// the whole distribution at `c = 0.5`, not one parameter of it.
	///
	/// ## Why linear between those points
	///
	/// Two measured points — `c = 0` symmetric and `c = 0.5` above — fix a line without
	/// proving the map is linear everywhere, so the structural argument still carries
	/// the rest of the range. Under this map `c → ±1` drives the median onto a bound and
	/// collapses one arm of the Myerson to zero width, which is a real degeneracy and
	/// exactly why the endpoints are excluded. A per-sigma map would leave the median a
	/// comfortable `σ` inside the bounds at `c = ±1`, giving no reason for the interval
	/// to be open at all — and it is now also ruled out by measurement.
	///
	/// The two natural formulations agree, which is why there was no fork to choose
	/// between: placing the median linearly gives a Myerson asymmetry of
	/// `(1 − c)/(1 + c)`, and going directly for a shape ratio equal to one at `c = 0`
	/// gives the same function.
	///
	/// - Parameters:
	///   - lowerBound: `a`, the −3σ point.
	///   - upperBound: `b`, the +3σ point.
	///   - skew: `c`, strictly inside `(-1, 1)`.
	/// - Returns: The median, or `nil` if the bounds are unordered or the skew is
	///   outside its range.
	static func normalSkewMedian(lowerBound: Double, upperBound: Double, skew: Double) -> Double? {
		guard lowerBound.isFinite, upperBound.isFinite, skew.isFinite else { return nil }
		guard lowerBound < upperBound else { return nil }
		guard skew > -1, skew < 1 else { return nil }
		let midpoint: Double = (lowerBound + upperBound) / 2
		let halfRange: Double = (upperBound - lowerBound) / 2
		let offset: Double = skew * halfRange
		return midpoint + offset
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
