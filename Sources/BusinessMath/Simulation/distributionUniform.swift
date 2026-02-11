//
//  distributionUniform.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Generates a random number from a uniform distribution over the interval [0, 1).
///
/// This function generates a random number from a uniform distribution using the `Double.random(in:)` function,
/// which returns a non-negative `Double` uniformly distributed between 0.0 and 1.0. The result is then scaled and converted to the specified `Real` type.
///
/// - Parameter randomSeed: Random seed value in [0, 1] (default: newly generated random value)
/// - Returns: A random number uniformly distributed between 0.0 (inclusive) and 1.0 (exclusive).
///
/// - Example:
///   ```swift
///   let randomValue: Double = distributionUniform()
///   // randomValue will be a uniform random number between 0.0 and 1.0
///   ```
public func distributionUniform<T: Real>(_ randomSeed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	let scale = 10_000_000.0  // Use 10 million to provide sufficient precision while avoiding 32-bit overflow
	let quantized = (randomSeed * scale).rounded(.down) / scale
	return T(quantized)
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
public func distributionUniform<T: Real>(min l: T, max h: T, _ randomSeed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
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
	public func random(_ randomSeed: Double = Double.random(in: 0...1)) -> Double {
		distributionUniform(min: min, max: max, randomSeed)
	}

	/// Generates the next random value from the uniform distribution.
	/// - Returns: A random Double between min and max using a new random seed
	public func next() -> Double {
		return random()
	}
}



