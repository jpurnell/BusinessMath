//
//  distributionBurr.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Burr type XII

/// A Burr type XII distribution: two shape parameters over a positive support.
///
/// The Burr family is what you reach for when one shape parameter is not enough — the
/// pair lets skewness and kurtosis be set somewhat independently, so it can be fitted to
/// data that a log-normal or Weibull cannot follow. It contains several of them as
/// special cases: `d = 1` is the log-logistic, and the Pareto and Weibull appear in
/// limits.
///
/// Binds Risk Solver's `PsiBurr12(loc, scale, shape1, shape2)`, which is
/// `scipy.stats.burr12(c: shape1, d: shape2, loc:, scale:)`.
///
/// ```
/// F(x) = 1 − (1 + y^c)^(−d)                for y = (x − loc)/scale > 0
/// Q(u) = loc + scale·((1 − u)^(−1/d) − 1)^(1/c)
/// ```
///
/// The moments exist only up to order `c·d`, so a small `c·d` gives a distribution with
/// no mean.
///
/// - SeeAlso: ``DistributionDagum``, which is Burr type **III** — a different
///   distribution reached through the same argument slots.
public struct DistributionBurr12: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support; no mass at or below it.
	public let location: Double

	/// The scale. Positive.
	public let scale: Double

	/// The first shape parameter, SciPy's `c`. Positive.
	public let shape1: Double

	/// The second shape parameter, SciPy's `d`. Positive.
	public let shape2: Double

	private let inverseScale: Double
	private let inverseShape1: Double
	private let negativeInverseShape2: Double

	/// Creates a Burr type XII distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support.
	///   - scale: The scale, positive and finite.
	///   - shape1: SciPy's `c`, positive and finite.
	///   - shape2: SciPy's `d`, positive and finite.
	/// - Returns: `nil` if any of `scale`, `shape1`, `shape2` is not positive and
	///   finite, or if `location` is not finite.
	public init?(location: Double, scale: Double, shape1: Double, shape2: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		guard shape1 > 0, shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.shape1 = shape1
		self.shape2 = shape2
		self.inverseScale = 1 / scale
		self.inverseShape1 = 1 / shape1
		self.negativeInverseShape2 = -1 / shape2
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let standardised: Double = (x - location) * inverseScale
		let raised: Double = Foundation.pow(standardised, shape1)
		return 1 - Foundation.pow(1 + raised, -shape2)
	}

	/// The value at which the CDF equals `p`.
	///
	/// ## Why `expm1` and `log1p` rather than the formula as written
	///
	/// `(1 − p)^(−1/d) − 1` is the textbook expression and it loses the answer in the
	/// lower tail. At `p = 1e-8` with `d = 3` the power is `1.0000000033…`, so
	/// subtracting one discards nine significant digits before the result is used —
	/// measured against SciPy the error was 4.7e-9 relative.
	///
	/// The same quantity is `expm1(−log1p(−p)/d)`: `log1p` keeps the precision of
	/// `1 − p` for small `p`, and `expm1` computes `eˣ − 1` without ever forming the
	/// intermediate `1` that the cancellation destroys.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		let logComplement: Double = Foundation.log1p(-p)
		let inner: Double = Foundation.expm1(logComplement * negativeInverseShape2)
		let raised: Double = Foundation.pow(inner, inverseShape1)
		return location + scale * raised
	}
}

// MARK: - Dagum, which is Burr type III

/// A Dagum distribution: Burr type **III**, used for modelling income and wealth.
///
/// Binds Risk Solver's `PsiDagum(loc, scale, shape1, shape2)`.
///
/// ## Type III and type XII share argument slots and are not the same distribution
///
/// The work list flags this and says to check before binding, so it was checked against
/// SciPy directly rather than inferred from the names:
///
/// ```
/// scipy.stats.burr    is type III   F = (1 + y^(−c))^(−d)
/// scipy.stats.burr12  is type XII   F = 1 − (1 + y^c)^(−d)
/// ```
///
/// Both take `c` then `d`, so **the argument mapping is identical and only the
/// distribution differs**. That is the shape of mistake that survives review: binding
/// `PsiDagum` to `burr12` would compile, round-trip, stay monotone, respect its support,
/// and be a different distribution. The fixture pins both at two parameter sets each.
///
/// ```
/// F(x) = (1 + y^(−c))^(−d)                 for y = (x − loc)/scale > 0
/// Q(u) = loc + scale·(u^(−1/d) − 1)^(−1/c)
/// ```
///
/// - SeeAlso: ``DistributionBurr12``
public struct DistributionDagum: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support; no mass at or below it.
	public let location: Double

	/// The scale. Positive.
	public let scale: Double

	/// The first shape parameter, SciPy's `c`. Positive.
	public let shape1: Double

	/// The second shape parameter, SciPy's `d`. Positive.
	public let shape2: Double

	private let inverseScale: Double
	private let negativeInverseShape1: Double
	private let negativeInverseShape2: Double

	/// Creates a Dagum (Burr type III) distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support.
	///   - scale: The scale, positive and finite.
	///   - shape1: SciPy's `c`, positive and finite.
	///   - shape2: SciPy's `d`, positive and finite.
	/// - Returns: `nil` if any of `scale`, `shape1`, `shape2` is not positive and
	///   finite, or if `location` is not finite.
	public init?(location: Double, scale: Double, shape1: Double, shape2: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		guard shape1 > 0, shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.shape1 = shape1
		self.shape2 = shape2
		self.inverseScale = 1 / scale
		self.negativeInverseShape1 = -1 / shape1
		self.negativeInverseShape2 = -1 / shape2
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let standardised: Double = (x - location) * inverseScale
		let raised: Double = Foundation.pow(standardised, -shape1)
		return Foundation.pow(1 + raised, -shape2)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		// `expm1` for the same reason as ``DistributionBurr12/quantile(_:)``: as `p`
		// approaches one the power approaches one, and `pow(p, -1/d) - 1` cancels away
		// the digits that carry the answer.
		let logP: Double = Foundation.log(p)
		let inner: Double = Foundation.expm1(logP * negativeInverseShape2)
		let raised: Double = Foundation.pow(inner, negativeInverseShape1)
		return location + scale * raised
	}
}
