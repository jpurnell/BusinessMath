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

public func distributionUniform<T: Real>() -> T {
	let randomSeed = Double.random(in: 0...1)
    let value = T(Int(randomSeed * Double(1_000_000_000_000))) / T(1_000_000_000_000)
    return value
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

public func distributionUniform<T: Real>(min l: T, max h: T) -> T {
    let lower = T.minimum(l, h)
    let upper = T.maximum(l, h)
    return ((upper - lower) * distributionUniform()) + lower
}
