//
//  distributionUniform.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Generates a random number from a uniform distribution over the interval (0, 1).
///
/// The draw comes from ``openUnitUniform(_:using:)``, which maps 52 random bits onto the open
/// unit interval; this function carries it into the requested `Real` type.
///
/// - Parameter randomSeed: A uniform value in (0, 1) (default: newly generated random value)
/// - Returns: A random number uniformly distributed strictly between 0.0 and 1.0.
///
/// - Note: This once rounded the seed down onto a lattice of ten million points, which cost
///   about seven decimal digits and, because the rounding was directional, biased every
///   sample downward by roughly 5e-8. A bias with a direction does not average out as the
///   sample count rises — it is exactly what a Monte Carlo estimate cannot survive — so the
///   quantization is gone. Values published before that change are not reproducible after it.
///
/// - Example:
///   ```swift
///   let randomValue: Double = distributionUniform()
///   // randomValue will be a uniform random number between 0.0 and 1.0
///   ```
public func distributionUniform<T: Real>(_ randomSeed: Double = openUnitUniform()) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	return T(randomSeed)
}

/// Generates a random number from a uniform distribution over a specified interval [l, h).
///
/// This function generates a random number from a uniform distribution between two specified bounds `l` and `h` using the `distributionUniform()` function, which should generate a uniform random number between 0.0 and 1.0.
///
/// - Parameters:
///   - l: The lower bound of the interval.
///   - h: The upper bound of the interval.
///   - randomSeed: Random seed value in [0, 1] (default: newly generated random value)
/// - Returns: A random number uniformly distributed between `min(l, h)` (inclusive) and `max(l, h)` (exclusive).
///
/// - Note: The function ensures that `l` is less than or equal to `h` by using the minimum and maximum of the two values provided.
///   It then scales the uniformly distributed random number [0, 1) to the specified interval [l, h).
///
/// - Example:
///   ```swift
///   let lowerBound: Double = 5.0
///   let upperBound: Double = 10.0
///   let randomValue: Double = distributionUniform(min: lowerBound, max: upperBound)
///   // randomValue will be a uniform random number between 5.0 and 10.0
///   ```
public func distributionUniform<T: Real>(min l: T, max h: T, _ randomSeed: Double = openUnitUniform()) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
    let lower = T.minimum(l, h)
    let upper = T.maximum(l, h)
    return ((upper - lower) * distributionUniform(randomSeed)) + lower
}

/// A uniform distribution generator for producing random values over a specified interval.
///
/// `DistributionUniform` generates random values uniformly distributed between minimum and maximum bounds.
/// All values in the interval have equal probability of being selected.
public struct DistributionUniform: DistributionRandom, Sendable {
	/// The numeric type produced by this distribution (Double).
	public typealias T = Double

	let min: Double
	let max: Double

	/// Creates a uniform distribution generator over the specified interval.
	/// - Parameters:
	///   - min: Lower bound of the distribution (default: 0.0)
	///   - max: Upper bound of the distribution (default: 1.0)
	public init (_ min: Double = 0.0, _ max: Double = 1.0) {
		self.min = min
		self.max = max
	}

	/// Generates a random value from the uniform distribution with an optional seed.
	/// - Parameter randomSeed: Random seed value in [0, 1] (default: newly generated random value)
	/// - Returns: A random Double uniformly distributed between min and max
	public func random(_ randomSeed: Double = openUnitUniform()) -> Double { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
		distributionUniform(min: min, max: max, randomSeed)
	}

	/// Generates the next random value from the uniform distribution.
	/// - Returns: A random Double between min and max using a new random seed
	public func next() -> Double {
		return random()
	}
}

extension DistributionUniform: SeedableDistribution {
	/// Generates the next random value, drawing the uniform seed from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the uniform draw.
	/// - Returns: A random Double uniformly distributed between min and max
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionUniform(min: min, max: max, openUnitUniform(Double.self, using: &generator))
	}
}


extension DistributionUniform: ContinuousDistribution {
	/// The density: 1/(b − a) inside the interval and zero outside.
	///
	/// The endpoints are included, which is a convention rather than a fact — a continuous
	/// distribution assigns them no probability either way — and it is the one that makes a
	/// plot of the density look like the rectangle it is.
	///
	/// - Parameter x: Any finite value.
	/// - Returns: The density, zero outside the support.
	public func pdf(_ x: Double) -> Double {
		guard x.isFinite else { return 0 }
		let lower = Swift.min(min, max)
		let upper = Swift.max(min, max)
		let span = upper - lower
		guard span > 0 else { return x == lower ? Double.infinity : 0 }
		guard x >= lower, x <= upper else { return 0 }
		return 1 / span
	}

	/// P(X ≤ x): zero below the lower bound, one above the upper, linear between.
	public func cdf(_ x: Double) -> Double {
		let lower = Swift.min(min, max)
		let upper = Swift.max(min, max)
		if x <= lower { return 0 }
		if x >= upper { return 1 }

		let span = upper - lower
		guard span > 0 else { return 1 }
		return (x - lower) / span
	}

	/// The value at which the CDF equals `p`.
	public func quantile(_ p: Double) -> Double {
		let lower = Swift.min(min, max)
		let upper = Swift.max(min, max)
		let span = upper - lower
		return lower + p * span
	}
}
