//
//  distributionGeometric.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics


// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from a geometric distribution with success probability `p`.
///
/// The geometric distribution models the number of trials needed to get the first success in a sequence of independent Bernoulli trials.
/// It is a discrete probability distribution with parameter `p`, where `p` is the probability of success on each trial.
///
/// - Parameters:
///   - p: The probability of success on each trial. It should be a value between 0 and 1.
///   - seed: Seed for a private ``DeterministicRNG``. The same seed with the same `p`
///     reproduces the same value exactly. `nil` (the default) draws from system entropy
///     and is non-reproducible by contract — use `seed:` or
///     ``distributionGeometric(_:using:)`` when reproducibility matters.
/// - Returns: A random number generated from the geometric distribution with success probability `p`.
///
/// - Note: The function uses the inverse transform method: `X = ceil(ln(U) / ln(1-p))` for
///         `U ~ Uniform(0, 1)`, so it consumes exactly one uniform per draw.
///
/// - Example:
///   ```swift
///   let probabilityOfSuccess: Double = 0.5
///   let randomValue: Double = distributionGeometric(probabilityOfSuccess, seed: 42)
///   // The same value on every run.
///   ```
public func distributionGeometric<T: Real>(_ p: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionGeometric(p, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionGeometric(p, using: &generator)
}

/// Generates a geometric variate, drawing its uniform from `generator`.
///
/// The generator-parameterized form of ``distributionGeometric(_:seed:)``, following the
/// same convention as ``SeedableDistribution/next(using:)``: all randomness comes from the
/// caller's generator, so the caller owns reproducibility and can interleave this draw
/// with others on a single stream.
///
/// - Parameters:
///   - p: The probability of success on each trial (0 < p ≤ 1).
///   - generator: The random source. Advanced by exactly one draw.
/// - Returns: The number of trials until the first success, or `NaN` if `p` is out of range.
public func distributionGeometric<T: Real, G: RandomNumberGenerator>(_ p: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard p > T(0), p <= T(1), !p.isNaN, p.isFinite else { return T.nan }

	// Special case: p = 1 means always succeed on first trial
	if p == T(1) { return T(1) }

	// Use inverse transform method (O(1), no iteration needed)
	// X = ceil(ln(U) / ln(1-p)) where U ~ Uniform(0,1)
	let u: T = distributionUniform(min: T(0), max: T(1), Double.random(in: 0...1, using: &generator))

	// Avoid log(0) by using 1-U which has same distribution as U
	let oneMinusP = T(1) - p
	let logOneMinusP = T.log(oneMinusP)

	// Prevent division by zero for p very close to 1
	guard logOneMinusP < T(0) else { return T(1) }

	// ceil(ln(1-U) / ln(1-p)) but use ln(U) since U and 1-U have same distribution
	let result = T.log(u) / logOneMinusP
	return T(max(1, Int(result.rounded(.up))))
}

/// A geometric distribution generator for modeling number of trials until first success.
///
/// The geometric distribution models scenarios like: number of coin flips until heads,
/// number of attempts until success, or waiting time in discrete trials.
public struct DistributionGeometric: DistributionRandom, Sendable {
	let p: Double

	/// Creates a geometric distribution generator.
	/// - Parameter probabilityOfSuccess: Success probability per trial (0 < p ≤ 1)
	public init(_ probabilityOfSuccess: Double) {
		self.p = probabilityOfSuccess
	}

	/// Generates a random value from the geometric distribution.
	/// - Returns: A random positive integer (as Double) representing number of trials
	public func random() -> Double {
		distributionGeometric(p)
	}

	/// Generates the next random value from the geometric distribution.
	/// - Returns: A random positive integer (as Double) representing number of trials
	public func next() -> Double {
		return random()
	}
}

extension DistributionGeometric: SeedableDistribution {
	/// Generates the next random value, drawing the inverse-transform uniform from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the single uniform draw.
	/// - Returns: A random positive integer (as Double) representing number of trials until first success
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionGeometric(p, using: &generator)
	}
}



