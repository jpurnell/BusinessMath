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
/// - Returns: A random number uniformly distributed between 0.0 (inclusive) and 1.0 (exclusive).
///
///
/// - Example:
///   ```swift
///   let randomValue: Double = distributionUniform()
///   // randomValue will be a uniform random number between 0.0 and 1.0

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

public func distributionUniform<T: Real>(min l: T, max h: T, _ randomSeed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
    let lower = T.minimum(l, h)
    let upper = T.maximum(l, h)
    return ((upper - lower) * distributionUniform(randomSeed)) + lower
}

public struct DistributionUniform: DistributionRandom, Sendable {
	public typealias T = Double
		
	let min: Double
	let max: Double

	public init (_ min: Double = 0.0, _ max: Double = 1.0) {
		self.min = min
		self.max = max
	}
	
	public func random(_ randomSeed: Double = Double.random(in: 0...1)) -> Double {
		distributionUniform(min: min, max: max, randomSeed)
	}
	
	public func next() -> Double {
		return random()
	}
}



