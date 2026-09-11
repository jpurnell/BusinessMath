//
//  distributionExponential.swift
//
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from an Exponential distribution with rate parameter `λ`.
///
/// The Exponential distribution is a continuous probability distribution that describes the time between events in a Poisson process. This function generates a random number from an Exponential distribution using the inverse transform sampling method.
///
/// - Parameters:
///   - λ: The rate parameter of the Exponential distribution.
///   - u: The point in `(0, 1)` at which to evaluate the quantile.
/// - Returns: A random number generated from the Exponential distribution with rate parameter `λ`.
///
/// - Note: The function computes the random number using the inverse transform sampling method:
///   \[ X = -\frac{1}{\lambda} \
///
public func distributionExponential<T: Real>(λ: T, quantileAt u: Double) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard λ > T(0), !λ.isNaN, λ.isFinite else { return T.nan }

	let scaled: T = distributionUniform(min: T(0), max: T(1), u)
	return T(-1) * (T(1) / λ) * T.log(1 - scaled)
}

/// An exponential distribution generator for modeling time between events.
///
/// The exponential distribution is memoryless and commonly used for modeling waiting times,
/// lifetimes, and inter-arrival times in Poisson processes.
public struct DistributionExponential: DistributionRandom, Sendable {
	let λ: Double

	/// Creates an exponential distribution generator.
	/// - Parameter λ: Rate parameter (λ > 0, mean = 1/λ)
	public init(_ λ: Double) {
		self.λ = λ
	}

	/// Generates a random value from the exponential distribution.
	/// - Returns: A random positive Double from the exponential distribution
	public func random() -> Double {
		distributionExponential(λ: λ)
	}

	/// Generates the next random value from the exponential distribution.
	/// - Returns: A random positive Double from the exponential distribution
	public func next() -> Double {
		return random()
	}
}

extension DistributionExponential: SeedableDistribution {
	/// Generates the next random value, drawing the uniform seed from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the uniform draw.
	/// - Returns: A random positive Double from the exponential distribution
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionExponential(λ: λ, using: &generator)
	}
}


extension DistributionExponential: ContinuousDistribution {
	/// P(X ≤ x) = 1 − e^(−λx), zero for negative `x`.
	public func cdf(_ x: Double) -> Double {
		exponentialCDF(x, λ: λ)
	}

	/// The value at which the CDF equals `p`: −ln(1 − p) / λ.
	public func quantile(_ p: Double) -> Double {
		guard λ > 0 else { return Double.nan }
		guard p < 1 else { return Double.infinity }
		// log(onePlus: -p), not log(1 - p): for small p the subtraction rounds the
		// argument to 1 and the log to zero.
		return -Double.log(onePlus: -p) / λ
	}
}


// MARK: - Seeded and generator-driven draws

/// A draw from the exponential distribution, reproducible from `seed`.
///
/// The sampler, as distinct from ``distributionExponential(λ:quantileAt:)``, which is the quantile function and
/// evaluates it at a point you supply. This one chooses the point.
///
/// `seed:` means the same thing here as on every other sampler in this library — a `UInt64`
/// naming a stream, not a uniform in `(0, 1)`. It used to mean the second, which put the
/// inverse-transform families in a different seeding regime from the rejection-based ones and
/// left `seed:` meaning two different things across one API.
///
/// - Parameters:
///   - λ: The rate parameter.
///   - seed: The stream to draw from, or `nil` to draw unseeded.
/// - Returns: A value distributed as exponential.
public func distributionExponential<T: Real>(λ: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionExponential(λ: λ, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionExponential(λ: λ, using: &generator)
}

/// A draw from the exponential distribution, taking its uniform from `generator`.
///
/// All randomness comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on one stream.
///
/// The uniform is drawn on the **open** interval. This family's quantile takes a logarithm or a
/// reciprocal, so an endpoint would turn a legal uniform into a non-finite variate — rarely
/// enough to survive testing and often enough to reach production.
///
/// - Parameters:
///   - λ: The rate parameter.
///   - generator: The random source. Advanced by exactly one draw.
/// - Returns: A value distributed as exponential.
public func distributionExponential<T: Real, G: RandomNumberGenerator>(λ: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	let u: Double = openUnitUniform(Double.self, using: &generator)
	return distributionExponential(λ: λ, quantileAt: u)
}
