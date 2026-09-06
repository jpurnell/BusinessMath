//
//  distributionJohnson.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Johnson SB, bounded

/// A Johnson SB distribution: a normal variable squeezed onto a **bounded** interval by
/// a logit transform.
///
/// The Johnson system exists to fit a distribution to a stated mean, variance, skewness
/// and kurtosis — four moments, four parameters. SB is the member used when the quantity
/// has hard limits, which in a business model is most of them: a market share, a
/// utilisation rate, a recovery percentage.
///
/// Binds Risk Solver's `PsiJohnsonSB(shape1, shape2, min, max)`, which is
/// `scipy.stats.johnsonsb(a: shape1, b: shape2, loc: min, scale: max − min)`.
///
/// ## SciPy's `scale` is the width, not the upper bound
///
/// Frontline states the interval as `min, max`; SciPy takes `loc` and `scale`, and its
/// support is `[loc, loc + scale]`. Passing `max` where `scale` belongs would place the
/// upper bound at `min + max` — right when `min` is zero, which is exactly the case a
/// quick test would use. The conversion happens in the initialiser here so a caller
/// states the bounds and cannot get it wrong.
///
/// ```
/// F(x) = Φ(a + b·ln(y/(1 − y)))            for y = (x − min)/(max − min) in (0, 1)
/// Q(u) = min + (max − min)/(1 + exp(−(Φ⁻¹(u) − a)/b))
/// ```
public struct DistributionJohnsonSB: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The first shape parameter, SciPy's `a`. Shifts the mass toward one bound; any
	/// finite value.
	public let shape1: Double

	/// The second shape parameter, SciPy's `b`. Positive — larger values concentrate the
	/// mass away from the bounds.
	public let shape2: Double

	/// The lower bound of the support.
	public let min: Double

	/// The upper bound of the support.
	public let max: Double

	private let width: Double
	private let inverseWidth: Double
	private let inverseShape2: Double

	/// Creates a bounded Johnson distribution.
	///
	/// - Parameters:
	///   - shape1: SciPy's `a`, any finite value.
	///   - shape2: SciPy's `b`, positive and finite.
	///   - min: The lower bound.
	///   - max: The upper bound, strictly greater than `min`.
	/// - Returns: `nil` if `shape2` is not positive and finite, if `shape1` is not
	///   finite, or if the bounds are not ordered and finite.
	public init?(shape1: Double, shape2: Double, min: Double, max: Double) {
		guard shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		guard min.isFinite, max.isFinite, max > min else { return nil }
		self.shape1 = shape1
		self.shape2 = shape2
		self.min = min
		self.max = max

		let span: Double = max - min
		guard span > 0 else { return nil }
		self.width = span
		self.inverseWidth = 1 / span
		self.inverseShape2 = 1 / shape2
	}

	/// P(X ≤ x), zero at or below `min` and one at or above `max`.
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let y: Double = (x - min) * inverseWidth
		// `x < max` was checked above, but the scaled `y` can still round to exactly 1
		// for an `x` within an ulp of the bound. The limit there is 1, so say so rather
		// than dividing by zero and arriving at the same answer through an infinity.
		let complement: Double = 1 - y
		guard complement > 0 else { return 1 }
		let odds: Double = y / complement
		let z: Double = shape1 + shape2 * Foundation.log(odds)
		return normalCDF(x: z)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability. Values at or outside the endpoints clamp to the
	///   bounds, which are finite here.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }
		let z: Double = inverseNormalCDF(p: p)
		let standardised: Double = (z - shape1) * inverseShape2
		// The logistic transform back onto (0, 1). `exp(-standardised)` overflows to
		// infinity for a large negative argument, where `1/(1+∞)` is 0 — the correct
		// limit, reached without a NaN.
		let y: Double = 1 / (1 + Foundation.exp(-standardised))
		return min + width * y
	}
}

// MARK: - Johnson SU, unbounded

/// A Johnson SU distribution: a normal variable stretched by an inverse hyperbolic sine,
/// giving an **unbounded** support with adjustable tails.
///
/// The member of the Johnson system for a quantity with no natural limits but tails
/// heavier or lighter than a normal's — a return series, a forecast error. Like SB it
/// takes four parameters and so can be fitted to four moments.
///
/// Binds Risk Solver's `PsiJohnsonSU(shape1, shape2, loc, scale)`, which is
/// `scipy.stats.johnsonsu(a: shape1, b: shape2, loc:, scale:)`. Unbounded, so `loc` and
/// `scale` are the ordinary pair — unlike ``DistributionJohnsonSB``, where `scale` is a
/// width derived from stated bounds.
///
/// ```
/// F(x) = Φ(a + b·asinh(y))                 for y = (x − loc)/scale
/// Q(u) = loc + scale·sinh((Φ⁻¹(u) − a)/b)
/// ```
public struct DistributionJohnsonSU: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The first shape parameter, SciPy's `a`, which controls skewness. Any finite value.
	public let shape1: Double

	/// The second shape parameter, SciPy's `b`, which controls kurtosis. Positive.
	public let shape2: Double

	/// The location.
	public let location: Double

	/// The scale. Positive.
	public let scale: Double

	private let inverseScale: Double
	private let inverseShape2: Double

	/// Creates an unbounded Johnson distribution.
	///
	/// - Parameters:
	///   - shape1: SciPy's `a`, any finite value.
	///   - shape2: SciPy's `b`, positive and finite.
	///   - location: The location, any finite value.
	///   - scale: The scale, positive and finite.
	/// - Returns: `nil` if `shape2` or `scale` is not positive and finite, or if
	///   `shape1` or `location` is not finite.
	public init?(shape1: Double, shape2: Double, location: Double, scale: Double) {
		guard shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.shape1 = shape1
		self.shape2 = shape2
		self.location = location
		self.scale = scale
		self.inverseScale = 1 / scale
		self.inverseShape2 = 1 / shape2
	}

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let y: Double = (x - location) * inverseScale
		let z: Double = shape1 + shape2 * Foundation.asinh(y)
		return normalCDF(x: z)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). The support is unbounded, so the
	///   endpoints return ∓infinity.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		let z: Double = inverseNormalCDF(p: p)
		let standardised: Double = (z - shape1) * inverseShape2
		return location + scale * Foundation.sinh(standardised)
	}
}

// MARK: - Birnbaum–Saunders

/// A Birnbaum–Saunders distribution: the classic model for time to failure by fatigue.
///
/// Derived from a physical argument rather than fitted convenience — cracks grow by a
/// random increment each cycle, and failure comes when the accumulated damage crosses a
/// threshold. The central limit theorem applied to that accumulation gives this law, so
/// it comes with a story about why the data should follow it.
///
/// Binds Risk Solver's `PsiFatigueLife(loc, scale, shape)`, which is
/// `scipy.stats.fatiguelife(c: shape, loc:, scale:)`.
///
/// ```
/// F(x) = Φ((√y − 1/√y)/c)                  for y = (x − loc)/scale > 0
/// Q(u) = loc + scale·(c·z/2 + √((c·z/2)² + 1))²      where z = Φ⁻¹(u)
/// ```
///
/// The quantile is the positive root of the quadratic that inverts the CDF's
/// `√y − 1/√y`, which is why it appears as a square of a sum rather than something
/// simpler.
public struct DistributionFatigueLife: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support; no mass at or below it.
	public let location: Double

	/// The scale, which is also the median when `location` is zero. Positive.
	public let scale: Double

	/// The shape, SciPy's `c`. Positive — larger values give a more dispersed lifetime.
	public let shape: Double

	private let inverseScale: Double
	private let inverseShape: Double

	/// Creates a Birnbaum–Saunders distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support.
	///   - scale: The scale, positive and finite.
	///   - shape: SciPy's `c`, positive and finite.
	/// - Returns: `nil` if `scale` or `shape` is not positive and finite, or if
	///   `location` is not finite.
	public init?(location: Double, scale: Double, shape: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		guard shape > 0, shape.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.shape = shape
		self.inverseScale = 1 / scale
		self.inverseShape = 1 / shape
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let y: Double = (x - location) * inverseScale
		let root: Double = y.squareRoot()
		guard root > 0 else { return 0 }
		let difference: Double = root - 1 / root
		return normalCDF(x: difference * inverseShape)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		let z: Double = inverseNormalCDF(p: p)
		let half: Double = shape * z / 2
		let root: Double = (half * half + 1).squareRoot()
		let y: Double = (half + root) * (half + root)
		return location + scale * y
	}
}
