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
/// - Parameter seed: Optional seed for reproducibility, a uniform on `[0, 1]`.
/// - Returns: A random value sampled from the Rayleigh distribution.
///
/// - Note: A Rayleigh variate is the *radius* of the Box-Muller transform, so this
///   is ``boxMullerRadius(_:)`` scaled by `mean`. Routing through the shared radius
///   rather than the shared pair matters: the pair would consume a second uniform
///   and compute a sine and a cosine only to discard them.
public func distributionRayleigh<T: Real>(mean: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard mean > T(0), !mean.isNaN, mean.isFinite else { return T.nan }

	// Two things this used to do for itself and no longer needs to.
	//
	// It ran the seed through `distributionUniform`, which quantizes to multiples
	// of 1e-7. That is what made the `log(0)` pole a real event rather than a
	// vanishing one: every seed below 1e-7 — one draw in ten million — landed on
	// exactly zero and returned `+infinity`. Seeds now reach the transform at full
	// precision, so a seed of 1e-9 is the legitimate 6.07-sigma radius it should
	// always have been, and only an exact zero is degenerate.
	//
	// And it folded the uniform as `1 - u`, which was the right guard for a
	// quantized [0, 1] with a fat atom at the bottom. With the quantization gone
	// the shared rule applies instead: only the single point `u = 0` moves, to 1,
	// which is a set of measure zero mapped onto another. The seeded *values*
	// change because a seed now indexes the distribution the other way round; the
	// distribution itself is identical.
	if let seed {
		return mean * boxMullerRadius(seed)
	}
	return mean * boxMullerRadius()
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
        // Straight to the shared radius rather than through the seed form: the
        // generator path draws `1 - Double.random(in: 0..<1)`, which is exact on
        // (0, 1] and never has to remap anything.
        return mean * boxMullerRadius(using: &generator)
    }
}
