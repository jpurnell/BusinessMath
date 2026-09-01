//
//  distributionGamma.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from a Gamma distribution with shape parameter `r` and rate parameter `λ`.
///
/// The Gamma distribution is a two-parameter family of continuous probability distributions. The parameters are referred to as the shape parameter `r` and the rate parameter `λ`. This function uses the relationship between the Gamma and Exponential distributions to generate a Gamma-distributed random variable.
///
/// - Parameters:
///   - r: The shape parameter of the Gamma distribution, which must be an integer indicating the number of exponential random variables to sum.
///   - λ: The rate parameter (inverse of the scale parameter) of the Gamma distribution.
///   - seed: Seed for a private ``DeterministicRNG``. The same seed with the same `r`
///     and `λ` reproduces the same value exactly. `nil` (the default) draws from system
///     entropy and is non-reproducible by contract — use `seed:` or
///     ``distributionGamma(r:λ:using:)`` when reproducibility matters.
/// - Returns: A random number generated from the Gamma distribution with shape parameter `r` and rate parameter `λ`.
///
/// - Note: The function generates `r` exponential random variables with rate parameter `λ` and returns their sum. This approaches the Gamma distribution using the definition that a Gamma distribution with integer shape parameter `r` can be constructed from the sum of `r` exponential variables.
///
/// - Example:
///   ```swift
///   let shapeParameter: Int = 3
///   let rateParameter: Double = 2.0
///   let randomValue: Double = distributionGamma(r: shapeParameter, λ: rateParameter, seed: 42)
///   // Same value on every run.
///   ```
public func distributionGamma<T: Real>(r: Int, λ: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionGamma(r: r, λ: λ, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionGamma(r: r, λ: λ, using: &generator)
}

/// Generates a Gamma-distributed value, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``distributionGamma(r:λ:seed:)``, following the
/// same convention as ``SeedableDistribution/next(using:)``: all randomness comes from
/// the caller's generator, so the caller owns reproducibility and can interleave this
/// draw with others on a single stream.
///
/// - Parameters:
///   - r: The shape parameter — the number of exponential variates to sum (r > 0).
///   - λ: The rate parameter (λ > 0).
///   - generator: The random source. Advanced by exactly `r` draws.
/// - Returns: A Gamma(r, λ) variate, or `NaN` if `r <= 0` or `λ` is not a positive finite value.
public func distributionGamma<T: Real, G: RandomNumberGenerator>(r: Int, λ: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard r > 0 else { return T.nan }
	guard λ > T(0), !λ.isNaN, λ.isFinite else { return T.nan }

	var sum: T = T(0)
	for _ in 0..<r {
		sum += distributionExponential(λ: λ, seed: Double.random(in: 0...1, using: &generator))
	}
	return sum
}

/// Generates a random value from a Gamma distribution using Marsaglia and Tsang's method.
///
/// This is a more general and efficient implementation that works for any real-valued shape parameter.
/// Uses Marsaglia and Tsang's method for shape >= 1, and shape transformation for shape < 1.
///
/// ## Why there is no array-of-uniforms parameter
///
/// This function used to take `seeds: [Double]?` — a finite array of pre-drawn uniforms
/// consumed by index — and fell through to the system generator the moment the index ran
/// past the end. That cannot be used correctly here even in principle: rejection sampling
/// bounded at 10,000 outer by 1,000 inner iterations means the number of uniforms consumed
/// is data-dependent and unbounded, so no caller can size the array. Measured at shape 0.5,
/// consumption averaged 4.08 uniforms with a maximum of 13 over 20,000 draws. A seed sizes
/// itself.
///
/// - Parameters:
///   - shape: The shape parameter (k > 0)
///   - scale: The scale parameter (θ > 0)
///   - seed: Seed for a private ``DeterministicRNG``. The same seed reproduces the same
///     value exactly, however many rejection iterations the draw happens to need. `nil`
///     (the default) draws from system entropy and is non-reproducible by contract — use
///     `seed:` or ``gammaVariate(shape:scale:using:)`` when reproducibility matters.
/// - Returns: A random value from Gamma(shape, scale)
public func gammaVariate<T: Real>(shape: T, scale: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return gammaVariate(shape: shape, scale: scale, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return gammaVariate(shape: shape, scale: scale, using: &generator)
}

/// Generates a random value from a Gamma distribution, drawing all randomness from a generator.
///
/// Generator-parameterized variant of ``gammaVariate(shape:scale:seed:)``. It follows
/// the identical probability law — Marsaglia and Tsang's rejection-sampling method for
/// shape ≥ 1, and the shape transformation property for shape < 1 — but sources every
/// uniform draw (including those inside the rejection loop) from `generator`, so a seeded
/// generator such as ``SplitMix64`` reproduces the identical sample stream on every run.
///
/// - Parameters:
///   - shape: The shape parameter (k > 0)
///   - scale: The scale parameter (θ > 0)
///   - generator: The random source for every uniform draw; a seeded generator makes the
///     returned stream fully reproducible.
/// - Returns: A random value from Gamma(shape, scale)
public func gammaVariate<T: Real, G: RandomNumberGenerator>(shape: T, scale: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	guard shape > T(0) && scale > T(0) else {
		preconditionFailure("Gamma shape and scale must be positive")
	}

	// For shape < 1, use the transformation property
	if shape < T(1) {
		let u: T = distributionUniform(min: T(0), max: T(1), Double.random(in: 0...1, using: &generator))
		let x = gammaVariate(shape: shape + T(1), scale: scale, using: &generator)
		return x * T.pow(u, T(1) / shape) // fp-safety:disable — shape > 0 guarded at function entry
	}

	// Marsaglia and Tsang's method for shape >= 1
	// Acceptance rate is typically >95%, but add safety limit
	let maxIterations = 10000
	let maxInnerIterations = 1000

	let oneThird: T = T(1) / T(3) // fp-safety:disable — constant T(3)
	let d = shape - oneThird
	let c = T(1) / T.sqrt(T(9) * d) // fp-safety:disable — shape >= 1 so d >= 2/3 > 0

	for _ in 0..<maxIterations {
		var x: T
		var v: T

		// Generate v = (1 + c×Z)³ where Z ~ N(0,1)
		var innerIterations = 0
		repeat {
			let u1Seed = Double.random(in: 0...1, using: &generator)
			let u2Seed = Double.random(in: 0...1, using: &generator)
			x = distributionNormal(mean: T(0), stdDev: T(1), u1Seed, u2Seed)
			v = T(1) + c * x
			innerIterations += 1
			// Safety: break inner loop if stuck (shouldn't happen with valid parameters)
			if innerIterations >= maxInnerIterations {
				break
			}
		} while v <= T(0)

		// If inner loop exhausted, try outer loop again
		guard v > T(0) else { continue }

		v = v * v * v

		// Generate U ~ Uniform(0,1)
		let u: T = distributionUniform(min: T(0), max: T(1), Double.random(in: 0...1, using: &generator))

		// Acceptance test
		let x2 = x * x
		let x4 = x2 * x2
		let constant: T = T(331) / T(10000)  // 0.0331
		let threshold1 = T(1) - constant * x4
		if u < threshold1 {
			return d * v * scale
		}

		let logU = T.log(u)
		let logV = T.log(v)
		let half: T = T(1) / T(2)
		let term1 = half * x2
		let term2 = d * (T(1) - v + logV)
		let threshold2 = term1 + term2
		if logU < threshold2 {
			return d * v * scale
		}
	}

	// Fallback: return mean of gamma distribution if rejection sampling exhausted
	// This should never happen with valid parameters
	return shape * scale
}

/// A Gamma distribution generator for producing random values.
///
/// The Gamma distribution is useful for modeling waiting times and is a generalization
/// of the exponential distribution. Common in queuing theory and reliability analysis.
public struct DistributionGamma: DistributionRandom, Sendable {
	var r: Int
	var λ: Double

	/// Creates a Gamma distribution generator.
	/// - Parameters:
	///   - r: Shape parameter (integer number of exponential variables to sum)
	///   - λ: Rate parameter (inverse of scale parameter)
	public init(r: Int, λ: Double) {
		self.r = r
		self.λ = λ
	}

	/// Generates a random value from the Gamma distribution.
	/// - Returns: A random Double from the Gamma distribution
	public func random() -> Double {
		return distributionGamma(r: r, λ: λ)
	}

	/// Generates the next random value from the Gamma distribution.
	/// - Returns: A random Double from the Gamma distribution
	public func next() -> Double {
		return random()
	}
}

extension DistributionGamma: SeedableDistribution {
	/// Generates the next random value, drawing all exponential-summation uniforms from `generator`.
	///
	/// Follows the same probability law as ``next()`` — a Gamma(r, λ) variate built as the sum
	/// of `r` exponential variates with rate `λ` — sourcing every uniform draw from `generator`;
	/// a seeded generator makes the stream fully reproducible.
	///
	/// - Parameter generator: The random source for the `r` uniform draws.
	/// - Returns: A random Double from the Gamma distribution with configured shape and rate, or NaN for invalid parameters
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionGamma(r: r, λ: λ, using: &generator)
	}
}
