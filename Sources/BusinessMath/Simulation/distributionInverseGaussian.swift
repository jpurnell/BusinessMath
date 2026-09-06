//
//  distributionInverseGaussian.swift
//  BusinessMath
//

import Foundation
import Numerics

/// An inverse Gaussian distribution: the first time Brownian motion with drift reaches a
/// fixed level.
///
/// "Inverse" refers to the relationship, not to a reciprocal — a normal describes how far
/// a process has travelled in a fixed *time*, and this describes how much *time* it takes
/// to travel a fixed distance. That makes it the natural law for a duration driven by an
/// accumulating process: time to failure, time to a sales target, time to a threshold.
///
/// Binds Risk Solver's `PsiInvNormal(mu, lambda)`.
///
/// ## SciPy's first argument is the ratio, not the mean
///
/// `scipy.stats.invgauss` is parameterised as `invgauss(mu/lambda, scale: lambda)` — its
/// first argument is the **ratio** `μ/λ`, and the mean is recovered as `mu × scale`.
/// Passing Frontline's `mu` straight into it produces a different distribution, one
/// whose mean is `μ·λ` rather than `μ`. The work list flags this row as needing explicit
/// conversion; the conversion lives in the fixture generator and this type takes `mu`
/// and `lambda` as Frontline states them.
///
/// ```
/// F(x) = Φ(√(λ/x)·(x/μ − 1)) + exp(2λ/μ)·Φ(−√(λ/x)·(x/μ + 1))
/// ```
///
/// ## The quantile has no closed form
///
/// There is no elementary inverse of that CDF, so ``quantile(_:)`` bisects. The CDF is
/// strictly increasing on the support, which makes bisection unconditionally
/// convergent — Newton would be faster but can leave the support on a bad step, and a
/// quantile that occasionally returns a negative duration is worse than one that takes
/// a few more iterations. The step count is derived from the numeric type rather than
/// chosen, so it reaches full precision for whatever `T` is in use.
public struct DistributionInverseGaussian: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The mean, Frontline's `mu`. Positive.
	public let mu: Double

	/// The shape, Frontline's `lambda`. Positive — larger values make the distribution
	/// more symmetric and more concentrated.
	public let lambda: Double

	private let inverseMu: Double

	/// Creates an inverse Gaussian distribution.
	///
	/// - Parameters:
	///   - mu: The mean, positive and finite.
	///   - lambda: The shape, positive and finite.
	/// - Returns: `nil` if either is not positive and finite.
	public init?(mu: Double, lambda: Double) {
		guard mu > 0, mu.isFinite, lambda > 0, lambda.isFinite else { return nil }
		self.mu = mu
		self.lambda = lambda
		self.inverseMu = 1 / mu
	}

	/// P(X ≤ x), zero at or below the origin.
	public func cdf(_ x: Double) -> Double {
		guard x > 0 else { return 0 }
		let root: Double = (lambda / x).squareRoot()
		let ratio: Double = x * inverseMu
		let lower: Double = normalCDF(x: root * (ratio - 1))
		let upper: Double = normalCDF(x: -root * (ratio + 1))
		// `exp(2λ/μ)` overflows for a large ratio, but it multiplies a normal tail that
		// underflows faster, and the product's true value is negligible there. Guarding
		// on the exponent keeps `inf × 0` from becoming a NaN.
		let exponent: Double = 2 * lambda * inverseMu
		guard exponent < 700 else { return lower }
		return lower + Foundation.exp(exponent) * upper
	}

	/// The value at which the CDF equals `p`, found by bisection.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is zero, the
	///   lower bound of the support; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return 0 }
		guard p < 1 else { return .infinity }

		// Bracket by doubling out from the mean. The CDF is increasing, so the first
		// point whose CDF exceeds `p` is an upper bound and the one before it a lower.
		var low: Double = 0
		var high: Double = mu
		var guard_ = 0
		while cdf(high) < p, guard_ < 200 {
			low = high
			high *= 2
			guard_ += 1
			if !high.isFinite { return .infinity }
		}

		// Enough halvings to exhaust the significand for this type — derived, not chosen.
		let steps = bisectionStepsToFullPrecision(of: Double.self)
		for _ in 0..<steps {
			let middle: Double = (low + high) / 2
			// The interval has closed to adjacent representable values; halving again
			// would return one of the endpoints for ever.
			if middle <= low || middle >= high { break }
			if cdf(middle) < p {
				low = middle
			} else {
				high = middle
			}
		}
		return (low + high) / 2
	}
}
