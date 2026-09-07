//
//  distributionPareto2.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A Pareto Type II — the Lomax distribution, a Pareto shifted to start at zero.
///
/// Binds Risk Solver's `PsiPareto2(b, q)`, scale then shape, and is
/// `scipy.stats.lomax(q, scale: b)`.
///
/// The ordinary Pareto starts at its scale parameter, which makes it awkward for a
/// quantity that can be arbitrarily small — an insurance loss, a waiting time, a file
/// size. Type II starts at zero and keeps the heavy tail.
///
/// ```swift
/// if let loss = DistributionPareto2(scale: 3, shape: 1.5) {
///     print(loss.quantile(0.9))   // 10.924766500838
///     print(loss.mean)            // 6.0 — finite only because shape > 1
/// }
/// ```
///
/// ## The formulas
///
/// ```
/// F(x) = 1 − (1 + x/b)^(−q)          x ≥ 0
/// Q(p) = b·((1 − p)^(−1/q) − 1)
/// ```
///
/// Both elementary, so §2.2 of the coverage proposal applies: the formula is the
/// reference and no cross-check against another implementation is needed. The
/// relationship to ``DistributionPareto`` is a shift of `b`, which is why this is its
/// own type rather than an initialiser on that one — shifting the support is not a
/// re-parameterisation, and a caller asking for one should not silently get the other.
///
/// ## What is finite
///
/// The mean is `b/(q − 1)` and exists only for `q > 1`; the variance needs `q > 2`.
/// Both report `nil` outside those ranges rather than an infinity, because an
/// infinity propagates silently into a risk measure and a `nil` does not.
public struct DistributionPareto2: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The scale, `b`. Positive.
	public let scale: Double

	/// The shape, `q`. Positive; larger means a lighter tail.
	public let shape: Double

	/// `1/shape` and `1/scale`, formed beside the guards proving them non-zero.
	private let inverseShape: Double
	private let inverseScale: Double

	/// Creates a Pareto Type II.
	///
	/// - Parameters:
	///   - scale: `b`, strictly positive.
	///   - shape: `q`, strictly positive.
	/// - Returns: `nil` unless both are positive and finite.
	public init?(scale: Double, shape: Double) {
		guard scale > 0, scale.isFinite, shape > 0, shape.isFinite else { return nil }
		self.scale = scale
		self.shape = shape
		self.inverseShape = 1 / shape
		self.inverseScale = 1 / scale
	}

	/// The mean, `b/(q − 1)`, or `nil` when `q ≤ 1` and it does not exist.
	public var mean: Double? {
		let excess: Double = shape - 1
		guard excess > 0 else { return nil }
		return scale / excess
	}

	/// The variance, or `nil` when `q ≤ 2` and it does not exist.
	public var variance: Double? {
		let excess: Double = shape - 2
		guard excess > 0 else { return nil }
		let onePast: Double = shape - 1
		guard onePast > 0 else { return nil }
		let squared: Double = scale * scale
		let numerator: Double = squared * shape
		let denominator: Double = onePast * onePast * excess
		guard denominator > 0 else { return nil }
		return numerator / denominator
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value; negative returns 0, since the support starts at zero.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x > 0 else { return 0 }
		guard x.isFinite else { return 1 }
		let scaled: Double = x * inverseScale
		// `log1p`/`expm1` rather than `1 − (1 + z)^-q`: for a small `x` the power is a
		// hair under one and the subtraction loses most of its significant digits.
		let logTerm: Double = Foundation.log1p(scaled)
		let exponent: Double = -shape * logTerm
		return -Foundation.expm1(exponent)
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, non-negative.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return 0 }
		guard p < 1 else { return .infinity }
		// Same cancellation, mirrored: `(1 − p)^(−1/q) − 1` for a small `p` is a small
		// difference of numbers near one.
		let survival: Double = Foundation.log1p(-p)
		let exponent: Double = -survival * inverseShape
        let growth: Double = Foundation.expm1(exponent)
		return scale * growth
	}
}
