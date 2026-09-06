//
//  distributionLogLogisticAndReciprocal.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Log-logistic

/// A log-logistic distribution: a variable whose logarithm is logistic.
///
/// Stands to the logistic as the log-normal stands to the normal. Used for survival and
/// time-to-event modelling, where its advantage over the log-normal is a closed-form
/// CDF — the hazard rate can be written down rather than integrated.
///
/// Binds Risk Solver's `PsiLogLogistic(gamma, beta, alpha)`. **SciPy calls it `fisk`**,
/// and orders the arguments differently: `fisk(c: alpha, loc: gamma, scale: beta)`.
/// Frontline's order is location, scale, shape.
///
/// ```
/// F(x) = 1 / (1 + ((x − γ)/β)^(−α))     for x > γ
/// Q(u) = γ + β·(u/(1 − u))^(1/α)
/// ```
///
/// The mean exists only for `alpha > 1`; below that the tail is too heavy.
public struct DistributionLogLogistic: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support, Frontline's `gamma`.
	public let location: Double

	/// The scale, Frontline's `beta`, which is also the median when `location` is zero.
	/// Positive.
	public let scale: Double

	/// The shape, Frontline's `alpha`. Positive — larger values concentrate the mass.
	public let shape: Double

	/// `1/scale` and `1/shape`, formed beside the guards proving them non-zero.
	private let inverseScale: Double
	private let inverseShape: Double

	/// Creates a log-logistic distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support, Frontline's `gamma`.
	///   - scale: The scale, Frontline's `beta`. Positive and finite.
	///   - shape: The shape, Frontline's `alpha`. Positive and finite.
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
		self.inverseShape = 1 / shape
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let standardised: Double = (x - location) * inverseScale
		let raised: Double = Foundation.pow(standardised, -shape)
		return 1 / (1 + raised)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		let odds: Double = p / (1 - p)
		let raised: Double = Foundation.pow(odds, inverseShape)
		return location + scale * raised
	}
}

// MARK: - Reciprocal / log-uniform

/// A log-uniform distribution: uniform on the **logarithm** of the value.
///
/// The right prior for a quantity whose order of magnitude is uncertain. Uniform on
/// [1, 1000] puts 90% of its mass above 100; log-uniform on the same range puts equal
/// mass in [1, 10], [10, 100] and [100, 1000], which is usually what "somewhere between
/// one and a thousand, no idea where" actually means.
///
/// Binds Risk Solver's `PsiReciprocal(min, max)`. **SciPy renamed `reciprocal` to
/// `loguniform`** — the old name is the one Frontline kept, and the work list flags the
/// rename because a fixture generated against the wrong one would silently be the wrong
/// distribution.
///
/// The density is proportional to `1/x`, which is where the older name comes from.
///
/// ```
/// F(x) = ln(x/min) / ln(max/min)
/// Q(u) = min·(max/min)^u
/// ```
public struct DistributionReciprocal: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support. Strictly positive — the logarithm of zero is not
	/// defined, so a log-uniform cannot reach it.
	public let min: Double

	/// The upper bound of the support.
	public let max: Double

	/// `ln(max/min)`, the normalising constant, and its reciprocal. Both formed in the
	/// initialiser beside the guard proving `max > min`.
	private let logRange: Double
	private let inverseLogRange: Double

	/// `1/min`, so ``cdf(_:)`` multiplies rather than divides.
	private let inverseMin: Double

	/// Creates a log-uniform distribution on `[min, max]`.
	///
	/// - Parameters:
	///   - min: The lower bound. Must be **strictly positive**.
	///   - max: The upper bound, strictly greater than `min`.
	/// - Returns: `nil` unless `0 < min < max` with both finite. A lower bound of zero
	///   is rejected rather than clamped: the density goes as `1/x`, so the mass near
	///   zero diverges and there is no distribution to return.
	public init?(min: Double, max: Double) {
		guard min > 0, min.isFinite, max.isFinite, max > min else { return nil }
		self.min = min
		self.max = max

		// `min` is positive, guarded on the first line of this initialiser.
		self.inverseMin = 1 / min
		let span: Double = Foundation.log(max / min)
		guard span > 0, span.isFinite else { return nil }
		self.logRange = span
		self.inverseLogRange = 1 / span
	}

	/// P(X ≤ x), zero below the support and one above it.
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let position: Double = Foundation.log(x * inverseMin)
		return position * inverseLogRange
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability. Values at or outside the endpoints clamp to the
	///   bounds, which are finite here.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }
		return min * Foundation.exp(p * logRange)
	}
}
