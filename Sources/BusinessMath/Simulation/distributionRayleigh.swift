//
//  DistributionRayleigh.swift
//  BusinessMath
//
//  Created by Justin Purnell on 8/25/25.
//

import Foundation
import Numerics

/// Generates a random value from a Rayleigh distribution with the specified mean.
///
/// The Rayleigh distribution is a continuous probability distribution for non-negative-valued random variables.
///
/// - Parameter mean: The mean of the Rayleigh distribution.
/// - Parameter seed: Optional seed for reproducibility
/// - Returns: A random value sampled from the Rayleigh distribution.
public func distributionRayleigh<T: Real>(mean: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard mean > T(0), !mean.isNaN, mean.isFinite else { return T.nan }

	// Rayleigh is the *radius* of the Box-Muller transform, so it meets the same
	// `log(0)` pole and needs the same guard — this one had none, and returned
	// `+infinity` whenever the uniform came out zero. `distributionUniform`
	// quantizes to a multiple of 1e-7, so that was every seed below 1e-7, one
	// draw in ten million, not the vanishing probability the pole has in exact
	// arithmetic.
	//
	// The guard is `1 - u` rather than a clamp, matching `d247691`: for any
	// representable `u < 1`, IEEE subtraction gives `1 - u > 0` exactly, and
	// `u ↦ 1 - u` is measure-preserving, so the draw stays exactly uniform on
	// `(0, 1]`. A clamp would instead pile an atom of probability on the clamp
	// value. Only one variate is needed here, so `boxMullerSeed` — which returns
	// a pair and would compute a second sine and cosine to discard them — is not
	// the right shared routine to call.
	let raw: T
	if let seed = seed {
		raw = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		raw = distributionUniform(min: T(0), max: T(1))
	}
	// `distributionUniform` is documented half-open but returns a closed [0, 1]:
	// its lattice is k/10_000_000 for k in 0...10_000_000, and the top point
	// arises only from a seed of exactly 1.0, which `Double.random(in: 0...1)`
	// can produce. Fold that one spurious point back onto the lattice's first,
	// so `1 - raw` lands in (0, 1] for every input the API accepts.
	let u = raw < T(1) ? T(1) - raw : T(1)
    return mean * T.sqrt(T(-2) * T.log(u))
}

/// A type that represents a Rayleigh distribution.
///
/// The Rayleigh distribution is a continuous probability distribution for non-negative-valued random variables.
/// It is often used to model the magnitude of a two-dimensional vector whose components are uncorrelated, normally distributed with equal variance, and zero mean.
public struct DistributionRayleigh: DistributionRandom {
    /// The mean of the Rayleigh distribution.
    let mean: Double
    
    /// Creates a new instance of `DistributionRayleigh` with the specified mean.
    ///
    /// - Parameter mean: The mean of the Rayleigh distribution.
    public init(mean: Double) {
        self.mean = mean
    }
    
    /// Generates a random value from the Rayleigh distribution.
    ///
    /// - Returns: A random value sampled from the Rayleigh distribution.
    public func random() -> Double {
        return distributionRayleigh(mean: mean)
    }
    
    /// Generates the next random value from the Rayleigh distribution.
    ///
    /// - Returns: The next random value sampled from the Rayleigh distribution.
    public func next() -> Double {
        return random()
    }
}

extension DistributionRayleigh: SeedableDistribution {
    /// Generates the next random value, drawing the uniform seed from `generator`.
    ///
    /// Follows the same probability law as ``next()``; a seeded generator makes the
    /// stream fully reproducible.
    ///
    /// - Parameter generator: The random source for the uniform draw.
    /// - Returns: A random value sampled from the Rayleigh distribution
    public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
        return distributionRayleigh(mean: mean, seed: Double.random(in: 0...1, using: &generator))
    }
}
