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
	let u: T
	if let seed = seed {
		u = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		u = distributionUniform(min: T(0), max: T(1))
	}
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
