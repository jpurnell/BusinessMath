//
//  DiscreteDistribution.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation
import Numerics

/// A distribution over a countable support, stated as a pmf, a CDF and a quantile.
///
/// The discrete sibling of ``ContinuousDistribution``, and it exists for the same two
/// reasons: a shared test template, and admission to quasi-random sampling. Poisson,
/// hypergeometric, negative binomial, logarithmic series and the explicit-pmf
/// distributions all belong here.
///
/// ## Why `next()` returns a floating-point value
///
/// ``DistributionRandom`` requires it, and the simulation pipeline is `Double`-typed
/// throughout — ``SimulationInput`` erases every distribution to a `Double` sampler.
/// The value returned is always integral and exactly representable; callers wanting
/// the count back can `Int(_:)` it without rounding concerns.
///
/// ## Sampling cost
///
/// The default `next(using:)` inverts the CDF, which for an explicit pmf means a
/// search: O(log n) with a cumulative array. A conformer may override it with an
/// alias table for O(1) draws, and should — *for the pseudo-random path only*.
///
/// An alias table is not monotone in its uniform. Under a stratified or
/// low-discrepancy sequence that destroys the equidistribution the sequence exists to
/// provide, giving the right distribution with none of the variance reduction. So an
/// alias table belongs in `next(using:)`, where it is fast and correct, and never in
/// `quantile(_:)`, which quasi-random sampling calls and which must stay monotone.
///
/// ## Topics
/// ### Describing the distribution
/// - ``pmf(_:)``
/// - ``cdf(_:)``
/// - ``quantile(_:)``
public protocol DiscreteDistribution<T>: SeedableDistribution {

	/// The probability mass at `k`: P(X = k).
	///
	/// Returns zero outside the support rather than failing.
	func pmf(_ k: Int) -> T

	/// The cumulative distribution function: P(X ≤ k).
	///
	/// Non-decreasing, bounded by 0 and 1, and defined for every `Int`.
	func cdf(_ k: Int) -> T

	/// The smallest `k` for which `cdf(k) >= p`.
	///
	/// Must be **monotone non-decreasing** in `p`. Quasi-random sampling depends on
	/// it — see the note on alias tables above.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The corresponding outcome.
	func quantile(_ p: T) -> Int
}

extension DiscreteDistribution {

	/// Draws by inverting the CDF at a uniform from the open interval (0, 1).
	///
	/// Consumes exactly one 64-bit word, for the reason given on
	/// `ContinuousDistribution.next(using:)`.
	///
	/// - Parameter generator: The random source.
	/// - Returns: The drawn outcome, as an exactly-representable integral value.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> T {
		let uniform = Double.openUnitRandom(using: &generator)
		let outcome = quantile(T(uniform))
		return T(outcome)
	}

	/// Draws from the system random source.
	///
	/// The unseeded entry point required by ``DistributionRandom``. It follows the
	/// same law as `next(using:)` and differs only in where the randomness comes
	/// from; prefer the seeded form anywhere the result has to be reproducible.
	public func next() -> T {
		let outcome = quantile(T(Double.openUnitRandom()))
		return T(outcome)
	}
}
