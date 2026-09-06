//
//  DistributionPoisson.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/24/25.
//

import Foundation
import Numerics

/// A Poisson distribution: the count of events in a fixed interval, when events occur
/// at a constant average rate and independently of the time since the last one.
///
/// Binds Risk Solver's `PsiPoisson(lambda)`.
///
/// ```swift
/// if let arrivals = DistributionPoisson(lambda: 3.5) {
///     var rng = DeterministicRNG(seed: 42)
///     let count = arrivals.next(using: &rng)   // a draw, reproducible from the seed
///     let p = arrivals.pmf(2)                  // P(X = 2)
///     print(count, p)
/// }
/// ```
///
/// ## What this replaces
///
/// A type of this name existed and did none of this. It conformed to
/// `RandomNumberGenerator` — backwards, since a generator *supplies* uniform bits and a
/// distribution *consumes* them — and its two methods were both wrong. `random()`
/// returned `poisson(x, µ: Double(x))`, the probability mass at `x` for a rate of `x`,
/// which ignored the stored rate entirely and returned a probability where a draw was
/// wanted. `next()` then converted that probability to `UInt64`, and since a
/// probability lies in [0, 1] the result was **zero almost every time**. It was
/// internal and unreferenced, so nothing depended on the behaviour.
///
/// - SeeAlso: ``poisson(_:µ:)``, ``poissonCDF(_:µ:)``
public struct DistributionPoisson: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The rate parameter λ, which is both the mean and the variance.
	public let lambda: Double

	/// Creates a Poisson distribution with rate `lambda`.
	///
	/// - Parameter lambda: The mean number of events per interval. Must be finite and
	///   non-negative; `0` is the degenerate distribution with all mass at zero.
	/// - Returns: `nil` if `lambda` is negative, infinite or NaN. Rejecting these at
	///   construction means every other method on the type can assume a usable rate,
	///   rather than each having to describe its own failure.
	public init?(lambda: Double) {
		guard lambda.isFinite, lambda >= 0 else { return nil }
		self.lambda = lambda
	}

	/// P(X = k) = e^(−λ)·λ^k / k!, zero below the support.
	public func pmf(_ k: Int) -> Double {
		poisson(k, µ: lambda)
	}

	/// P(X ≤ k), zero below the support and approaching one above it.
	public func cdf(_ k: Int) -> Double {
		guard k >= 0 else { return 0 }
		return poissonCDF(Double(k), µ: lambda)
	}

	/// The smallest `k` for which `cdf(k) >= p`.
	///
	/// Accumulates the mass from zero rather than calling ``cdf(_:)`` per candidate,
	/// which would make the search quadratic. Monotone in `p` by construction, which
	/// the protocol requires because quasi-random sampling inverts through here.
	///
	/// - Parameter p: A probability. Values at or below zero give `0`; values at or
	///   above one give the largest `k` the search reaches.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 0 }
		// The degenerate distribution has every quantile at zero.
		guard lambda > 0 else { return 0 }

		// Ten standard deviations past the mean, plus a floor for small rates. The
		// Poisson tail beyond this is far below the resolution of a Double, so the
		// bound costs nothing and guarantees termination for p >= 1.
		let spread: Double = 10.0 * lambda.squareRoot()
		let ceiling: Int = Int(lambda + spread) + 40

		var cumulative = 0.0
		for k in 0...ceiling {
			cumulative += pmf(k)
			if cumulative >= p { return k }
		}
		return ceiling
	}
}
