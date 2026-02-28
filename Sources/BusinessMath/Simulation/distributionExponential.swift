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
