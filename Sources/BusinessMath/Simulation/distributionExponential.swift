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
///   - seed: Optional uniform random seed in [0, 1] for deterministic generation (default: nil)
/// - Returns: A random number generated from the Exponential distribution with rate parameter `λ`.
///
/// - Note: The function computes the random number using the inverse transform sampling method:
///   \[ X = -\frac{1}{\lambda} \
///
public func distributionExponential<T: Real>(λ: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard λ > T(0), !λ.isNaN, λ.isFinite else { return T.nan }

	let u: T
	if let seed = seed {
		u = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		u = distributionUniform()
	}
	return T(-1) * (T(1) / λ) * T.log(1 - u)
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
		return distributionExponential(λ: λ, seed: Double.random(in: 0...1, using: &generator))
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
