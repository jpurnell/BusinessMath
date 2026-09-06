//
//  distributionExtremeValue.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Gumbel, right-skewed

/// The distribution of the **maximum** of many samples: a Gumbel with a long right tail.
///
/// Extreme value type I. Where a normal describes an average, this describes a record —
/// the largest flood in a century, the worst loss in a portfolio's history — and it is
/// the limit that block maxima converge to whatever the underlying distribution was,
/// provided its tail is not too heavy.
///
/// Binds Risk Solver's `PsiMaxExtreme(m, s)`, which is `scipy.stats.gumbel_r(loc: m,
/// scale: s)`.
///
/// ```swift
/// if let annualMax = DistributionMaxExtreme(location: 10, scale: 3) {
///     print(annualMax.quantile(0.99))   // the hundred-year level
/// }
/// ```
///
/// ```
/// F(x) = exp(−exp(−(x − m)/s))
/// Q(u) = m − s·ln(−ln u)
/// ```
///
/// - SeeAlso: ``DistributionMinExtreme``, the distribution of the *minimum*, which is a
///   different distribution and not this one negated.
public struct DistributionMaxExtreme: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The mode of the distribution, Frontline's `m`.
	public let location: Double

	/// The scale, Frontline's `s`. Positive.
	public let scale: Double

	/// `1/scale`, formed in the initialiser beside the guard that proves it non-zero.
	private let inverseScale: Double

	/// Creates a right-skewed Gumbel distribution.
	///
	/// - Parameters:
	///   - location: The mode.
	///   - scale: The scale, positive and finite.
	/// - Returns: `nil` if `scale` is not positive and finite, or `location` not finite.
	public init?(location: Double, scale: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.inverseScale = 1 / scale
	}

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let standardised: Double = (x - location) * inverseScale
		return Foundation.exp(-Foundation.exp(-standardised))
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). The support is unbounded, so the
	///   endpoints return ∓infinity rather than a NaN.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		let doubleLog: Double = Foundation.log(-Foundation.log(p))
		return location - scale * doubleLog
	}
}

// MARK: - Gumbel, left-skewed

/// The distribution of the **minimum** of many samples: a Gumbel with a long left tail.
///
/// Binds Risk Solver's `PsiMinExtreme(m, s)`, which is `scipy.stats.gumbel_l(loc: m,
/// scale: s)`.
///
/// ```
/// F(x) = 1 − exp(−exp((x − m)/s))
/// Q(u) = m + s·ln(−ln(1 − u))
/// ```
///
/// ## Not the maximum negated
///
/// The work list is explicit: *"Distinct from PsiMaxExtreme; do not implement one and
/// negate."* The two are mirror images **about the origin, not about their own
/// location**, so `−MaxExtreme(m, s)` is `MinExtreme(−m, s)` — negating the draw
/// silently moves the mode to the wrong side of zero. It agrees only when `m` is zero,
/// which is exactly the case a quick test is most likely to use. Each is implemented
/// from its own quantile here, and the fixture checks both against SciPy at a non-zero
/// location for that reason.
///
/// - SeeAlso: ``DistributionMaxExtreme``
public struct DistributionMinExtreme: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The mode of the distribution, Frontline's `m`.
	public let location: Double

	/// The scale, Frontline's `s`. Positive.
	public let scale: Double

	/// `1/scale`, formed in the initialiser beside the guard that proves it non-zero.
	private let inverseScale: Double

	/// Creates a left-skewed Gumbel distribution.
	///
	/// - Parameters:
	///   - location: The mode.
	///   - scale: The scale, positive and finite.
	/// - Returns: `nil` if `scale` is not positive and finite, or `location` not finite.
	public init?(location: Double, scale: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.inverseScale = 1 / scale
	}

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let standardised: Double = (x - location) * inverseScale
		return 1 - Foundation.exp(-Foundation.exp(standardised))
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). The support is unbounded, so the
	///   endpoints return ∓infinity rather than a NaN.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		// `log(onePlus:)` keeps the precision that `log(1 - p)` loses for small p, and
		// the tail is where an extreme value distribution is actually read.
		let logComplement: Double = Foundation.log1p(-p)
		let doubleLog: Double = Foundation.log(-logComplement)
		return location + scale * doubleLog
	}
}

// MARK: - Fréchet

/// A Fréchet distribution: extreme value type II, heavy-tailed.
///
/// The limit for block maxima drawn from a heavy-tailed parent — where a Gumbel assumes
/// the parent's tail decays exponentially, this one does not, and the difference shows
/// up precisely in the extreme quantiles a risk model is built to read.
///
/// Binds Risk Solver's `PsiFrechet(loc, scale, shape)`. **SciPy calls it `invweibull`,
/// not `frechet`** — the name in the reference is not the name of the distribution.
///
/// ```
/// F(x) = exp(−((x − loc)/scale)^(−shape))     for x > loc
/// Q(u) = loc + scale·(−ln u)^(−1/shape)
/// ```
///
/// The mean exists only for `shape > 1` and the variance only for `shape > 2`; below
/// those the moments diverge, which is a property of the distribution rather than a
/// limitation here.
public struct DistributionFrechet: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support; the distribution has no mass at or below it.
	public let location: Double

	/// The scale. Positive.
	public let scale: Double

	/// The tail index. Positive — smaller values give a heavier tail.
	public let shape: Double

	/// `1/scale` and `−1/shape`, formed beside the guards proving them non-zero.
	private let inverseScale: Double
	private let negativeInverseShape: Double

	/// Creates a Fréchet distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support.
	///   - scale: The scale, positive and finite.
	///   - shape: The tail index, positive and finite.
	/// - Returns: `nil` if `scale` or `shape` is not positive and finite, or if
	///   `location` is not finite.
	public init?(location: Double, scale: Double, shape: Double) {
		guard location.isFinite, scale > 0, scale.isFinite, shape > 0, shape.isFinite else {
			return nil
		}
		self.location = location
		self.scale = scale
		self.shape = shape
		self.inverseScale = 1 / scale
		self.negativeInverseShape = -1 / shape
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let standardised: Double = (x - location) * inverseScale
		let raised: Double = Foundation.pow(standardised, -shape)
		return Foundation.exp(-raised)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`, the lower bound; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		let negativeLog: Double = -Foundation.log(p)
		let raised: Double = Foundation.pow(negativeLog, negativeInverseShape)
		return location + scale * raised
	}
}
