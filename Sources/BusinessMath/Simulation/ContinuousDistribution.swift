//
//  ContinuousDistribution.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation
import Numerics
#if canImport(os)
import os

private let logger = Logger(subsystem: "com.businessmath", category: "ContinuousDistribution")
#endif

/// A distribution whose law is stated as a CDF and its inverse.
///
/// ``DistributionRandom`` asks a distribution only how to *draw*. That is enough to
/// run a simulation and not enough for anything else: it cannot be checked against a
/// reference CDF, it cannot be inverted, and it cannot be handed a chosen point in
/// the unit interval. `ContinuousDistribution` adds the two functions that make all
/// three possible.
///
/// ## What conformance buys
///
/// **A sampler, for free.** `next(using:)` is supplied by inverse transform — one
/// uniform in, one draw out. A conformer that states `cdf` and `quantile` and nothing
/// else is already a complete, seedable distribution.
///
/// **Admission to quasi-random sampling.** Latin hypercube and Sobol hand each input
/// one coordinate of a jointly-chosen point, which is only meaningful for a
/// distribution that can say what value sits at a given uniform. Conformance *is* the
/// eligibility test; a distribution without a quantile is refused rather than
/// silently sampled pseudo-randomly. See `SamplingMethod`.
///
/// **A single test template.** Every conformer is checked the same way: CDF against a
/// reference, `quantile(cdf(x)) == x`, monotonicity, and a Kolmogorov–Smirnov
/// statistic over a seeded sample.
///
/// ## Conforming
///
/// Two functions and a typealias. Both samplers come from the protocol.
///
/// ```swift
/// struct Kumaraswamy: ContinuousDistribution {
///     typealias T = Double
///     let a: Double, b: Double
///
///     func cdf(_ x: Double) -> Double {
///         1 - Double.pow(1 - Double.pow(x, a), b)
///     }
///
///     func quantile(_ p: Double) -> Double {
///         Double.pow(1 - Double.pow(1 - p, 1 / b), 1 / a)
///     }
/// }
/// ```
///
/// The `typealias` is worth stating explicitly. `T` is inferable from `cdf` and
/// `quantile` alone, but once both samplers are defaulted there is little left to
/// infer from, and the diagnostic when inference fails names the associated type
/// rather than the line that confused it.
///
/// ## Overriding the sampler
///
/// A conformer may implement its own `next(using:)` — because rejection sampling is
/// faster, or because an existing seeded stream must not change. ``DistributionNormal``
/// keeps Box–Muller and ``DistributionGamma`` keeps Marsaglia–Tsang for exactly that
/// reason, and `SeededStreamRegressionTests` exists to notice if either stops.
///
/// Overriding does **not** forfeit quasi-random eligibility. The two paths are
/// independent: quasi-random runs call `quantile(_:)` directly and never consult
/// `next(using:)` at all.
///
/// ## Topics
/// ### Describing the distribution
/// - ``cdf(_:)``
/// - ``quantile(_:)``
public protocol ContinuousDistribution<T>: SeedableDistribution {

	/// The cumulative distribution function: P(X ≤ x).
	///
	/// Non-decreasing, and bounded by 0 and 1. Defined for every finite `x`,
	/// including values outside the support, where it returns 0 or 1 rather than
	/// failing.
	///
	/// - Parameter x: Any finite value.
	/// - Returns: The probability that a draw falls at or below `x`.
	func cdf(_ x: T) -> T

	/// The value at which the CDF equals `p` — the inverse of `cdf(_:)`.
	///
	/// - Parameter p: A probability in the **open** interval (0, 1). The endpoints
	///   are excluded because they are infinite for any unbounded support, and a
	///   caller that needs a bound should read the support directly.
	/// - Returns: The `x` for which `cdf(x) == p`.
	func quantile(_ p: T) -> T
}

extension ContinuousDistribution {

	/// Draws by inverse transform: one uniform in, one value out.
	///
	/// The uniform comes from `openUnitRandom(using:)`, which excludes
	/// both endpoints — `quantile(0)` is −∞ for most distributions and `quantile(1)`
	/// is +∞, and a sampler that occasionally returns an infinity is worse than one
	/// that is merely slow.
	///
	/// Exactly one 64-bit word is consumed per draw. That is a requirement, not an
	/// implementation detail: a quasi-random point set supplies one coordinate per
	/// input per iteration, so a sampler drawing twice would desynchronise from it.
	///
	/// - Parameter generator: The random source. A seeded generator makes the stream
	///   reproducible.
	/// - Returns: A draw following this distribution.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> T {
		let uniform = Double.openUnitRandom(using: &generator)
		return quantile(T(uniform))
	}

	/// Draws from the system random source.
	///
	/// The unseeded entry point required by ``DistributionRandom``. It follows the
	/// same law as `next(using:)` and differs only in where the randomness comes
	/// from; prefer the seeded form anywhere the result has to be reproducible.
	public func next() -> T {
		return quantile(T(Double.openUnitRandom()))
	}
}

// MARK: - The uniform a quantile can safely be given

extension Double {

	/// A uniform draw from the **open** interval (0, 1) — never 0, never 1.
	///
	/// Neither of the obvious spellings is open on both sides: `Double.random(in: 0..<1)`
	/// can return 0, and `1 - Double.random(in: 0..<1)` can return 1. Feeding either
	/// endpoint to a quantile function yields an infinity, which then propagates
	/// through a simulation as a NaN somewhere unrelated.
	///
	/// This instead takes a 53-bit integer *k* and returns `(k + ½) / 2⁵³`. The result
	/// is strictly inside the interval, symmetric about ½, and spans
	/// `[2⁻⁵⁴, 1 − 2⁻⁵⁴]` — about ±8.4σ on a standard normal, which is further into
	/// the tail than any simulation of practical size will reach.
	///
	/// Exactly one 64-bit word is consumed, which is what lets a quasi-random point
	/// set stay aligned with the inputs it feeds.
	///
	/// - Parameter generator: The random source.
	/// - Returns: A uniform value strictly between 0 and 1.
	public static func openUnitRandom<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		// The high bits are the well-mixed ones in every generator we use.
		return openUnitValue(from: generator.next() >> Double.discardedRandomBits)
	}

	/// A uniform draw from the open interval (0, 1), taken from the system source.
	///
	/// The unseeded companion to `openUnitRandom(using:)`, with identical
	/// construction and range. Prefer the seeded form anywhere the result has to be
	/// reproducible.
	///
	/// - Returns: A uniform value strictly between 0 and 1.
	public static func openUnitRandom() -> Double {
		return openUnitValue(from: UInt64.random(in: 0...UInt64.max) >> Double.discardedRandomBits) // stochastic:exempt — the documented unseeded path; pass `using:` for reproducibility
	}

	/// Maps a 53-bit integer onto the open interval as `(k + ½) / 2⁵³`.
	///
	/// Shared by both entry points so the two cannot drift apart in range or in the
	/// half-ulp offset that keeps them off the endpoints.
	private static func openUnitValue(from bits: UInt64) -> Double {
		// Centre the value in its cell — the half is what keeps both endpoints out of
		// reach, symmetrically — then scale the cell index down to the unit interval.
		let half = Double(1) / Double(2)
		let offset = Double(bits) + half
		return offset * Double.randomCellWidth
	}

	/// How many bits of a 64-bit word are surplus to a significand.
	///
	/// A `Double` carries `significandBitCount` explicit bits plus the implicit
	/// leading one, so a draw uses that many of the word's high bits and discards the
	/// rest. Derived rather than written as 11, so the same code is right for any
	/// binary floating-point width.
	fileprivate static let discardedRandomBits =
		UInt64.bitWidth - (Double.significandBitCount + 1)

	/// The width of one cell of the unit interval, `2^−precision`.
	///
	/// `ulpOfOne` is `2^−(precision−1)` by definition, so half of it is the cell width
	/// for a full-precision significand.
	fileprivate static let randomCellWidth = Double.ulpOfOne / 2
}

// MARK: - Bridging the throwing special functions

/// Evaluates a throwing distribution function, reporting invalid parameters as `nan`.
///
/// `cdf` and `quantile` are **total** by contract: they are called from sampling
/// loops and from the quasi-random path, neither of which can propagate an error, and
/// both are documented to answer for every input. Several of the functions they
/// delegate to — `tCDF`, `fQuantile`, `regularizedIncompleteBeta` and the two
/// special-function inverses — throw instead, because their own callers *can* act on
/// a bad shape parameter.
///
/// The two contracts meet here, once, rather than at each of the twenty-odd
/// conformances. Concentrating it means there is a single place to read what happens
/// to a discarded error, and a single place to change it.
///
/// A thrown error means the distribution's parameters are invalid — a non-positive
/// degrees of freedom, a shape that is zero. `nan` is the signal every free-function
/// distribution in this package already uses for exactly that, it propagates rather
/// than being mistaken for a result, and it is what `assertConformance` checks for at
/// the endpoints.
///
/// - Parameter compute: The throwing evaluation.
/// - Returns: Its result, or `T.nan` if it threw.
internal func totalizedResult<T: Real>(_ compute: () throws -> T) -> T {
	do {
		return try compute()
	} catch {
		// The error is not discarded — it is the only account of *why* a nan
		// appeared, and a nan that propagates into a simulation result is otherwise
		// very hard to trace back to its parameters. This branch runs only on invalid
		// parameters, so it is off the sampling path entirely.
		#if canImport(os)
		logger.error("Distribution function failed; returning nan: \(error, privacy: .public)")
		#endif
		return T.nan
	}
}
