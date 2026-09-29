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
	/// - Parameter lambda: The mean number of events per interval. Must be finite,
	///   non-negative, and no larger than 2^53; `0` is the degenerate distribution with
	///   all mass at zero.
	/// - Returns: `nil` if `lambda` is negative, infinite, NaN, or too large to name a
	///   distinct count. Rejecting these at construction means every other method on the
	///   type can assume a usable rate, rather than each having to describe its own failure.
	public init?(lambda: Double) {
		// The magnitude bound is not decoration, and it is why this guard screens more than
		// finiteness. `quantile(_:)` forms `Int(lambda + 10 * sqrt(lambda)) + 40`, and
		// `Int(_:)` *traps* above `Int.max` — so `lambda: 1e19` did not give a bad count, it
		// took the process down, with no value to inspect and nothing to catch. The bound is
		// 2^53 rather than `Int.max` because 2^53 is where a `Double` stops being able to
		// tell this rate from the next integer count: beyond it λ can no longer name a point
		// in the distribution's own support, so there is nothing to sample or invert.
		let largestDistinctCount = 0x1p53
		guard lambda.isFinite, lambda >= 0, lambda <= largestDistinctCount else { return nil }
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
	/// Accumulates the mass term by term rather than calling ``cdf(_:)`` per candidate,
	/// which would make the search quadratic. Monotone in `p` by construction, which
	/// the protocol requires because quasi-random sampling inverts through here.
	///
	/// ## Why the sum does not start at zero
	///
	/// It used to, and that made the search **O(λ)** — for `lambda: 1e12` the loop ran a
	/// million million times before reaching any count with mass on it. `init(lambda:)`
	/// closed the trap that the same rate used to spring (`Int(_:)` above `Int.max`), so
	/// what was left was not a crash but a hang, which is worse to diagnose: there is no
	/// value to inspect and no error to catch.
	///
	/// Nothing was being *computed* in those iterations. `pmf(k)` for a `k` far below the
	/// mean is `exp(k·ln λ − λ − ln Γ(k+1))`, which underflows to exactly zero long before
	/// the mass becomes interesting — at λ = 1e12 every term below about `λ − 9√λ` is a
	/// literal `0.0` being added to a running total. The loop now starts at
	/// `firstCountWithRepresentableMass(_:)`, twelve standard deviations below the mean,
	/// which is where those terms stop being zero. The cost becomes O(√λ) and the answers
	/// below λ ≈ 144 are **unchanged**, because the start is clamped at zero there and the
	/// loop is the one that was already running.
	///
	/// This is a bound on the neglected mass, not a performance cutoff: the head that is
	/// skipped is smaller than the last bit of the answer, so no `p` a `Double` can hold
	/// distinguishes the two sums. A cutoff would stop the search early and return a count
	/// it had not justified; this starts it late and finishes it.
	///
	/// - Parameter p: A probability. Values at or below zero give `0`; values at or
	///   above one give the largest `k` the search reaches.
	/// - Note: A `p` that is `nan` also gives `0`, because `nan > 0` is false. That is the
	///   one place this type cannot follow ``ContinuousDistribution/quantile(_:)``, which
	///   answers an unreadable probability with `nan`: the return type is `Int` and `Int`
	///   has no `nan` to return. `0` is this distribution's support minimum, matching what
	///   ``DistributionGeometric/quantile(_:)`` does with its own, and it is a real count —
	///   a caller cannot tell it from the answer to `p = 1e-300`. Prefer screening `p`
	///   before the call; the type cannot do it for you.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 0 }
		// The degenerate distribution has every quantile at zero.
		guard lambda > 0 else { return 0 }

		// Ten standard deviations past the mean, plus a floor for small rates. The
		// Poisson tail beyond this is far below the resolution of a Double, so the
		// bound costs nothing and guarantees termination for p >= 1.
		let spread: Double = 10.0 * lambda.squareRoot()
		let ceiling: Int = Int(lambda + spread) + 40
		// The documented answer for a probability at or above one, reached without walking
		// the whole support to discover that the mass never gets there.
		guard p < 1 else { return ceiling }

		let start: Int = Self.firstCountWithRepresentableMass(lambda)
		var cumulative = 0.0
		for k in start...ceiling {
			cumulative += pmf(k)
			if cumulative >= p { return k }
		}
		return ceiling
	}

	/// The lowest count whose mass can still change a `Double` running total.
	///
	/// Twelve standard deviations below the mean, with the same floor of forty the ceiling
	/// uses so that a small rate is not clipped. Chernoff bounds the Poisson left tail by
	/// `exp(-t²/2)` at `t` standard deviations, so twelve leaves at most `5e-32` below the
	/// start — some `3e15` times smaller than the `1.1e-16` ulp of a probability near one,
	/// and smaller again than the rounding already accumulated by the terms that are
	/// summed. Twelve rather than the nine that bound alone would justify: the margin is
	/// free, since the cost is O(√λ) either way.
	///
	/// - Parameter lambda: The rate. `init(lambda:)` has already established that it is
	///   non-negative and no larger than 2^53.
	/// - Returns: Zero for any rate below about 144, where the whole support is in range.
	private static func firstCountWithRepresentableMass(_ lambda: Double) -> Int {
		let deviations: Double = 12.0 * lambda.squareRoot()
		let lowered: Double = lambda - deviations - 40

		// The upper bound is redundant against `init(lambda:)`, which already refuses a rate
		// above 2^53 — and `lowered` is strictly below `lambda`. It is stated here anyway so
		// the conversion is total *on its own terms* rather than by relying on an invariant
		// established in another function, which is the same reason
		// `InventorySimulator.boundedLeadTimePeriods` carries its own bound. `Int(_:)` traps
		// rather than answering, so the cost of the redundancy is one comparison and the cost
		// of omitting it is the process.
		guard lowered > 0, lowered < 0x1p53 else { return 0 }
		return Int(lowered)
	}
}
