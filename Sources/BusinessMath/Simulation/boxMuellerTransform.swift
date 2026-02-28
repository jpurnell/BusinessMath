//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// Generates a single random number from a normal (Gaussian) distribution with a specified mean and standard deviation using the Box-Muller transform.
///
/// This function relies on the Box-Muller transform to generate standard normally distributed values and scales them according to the specified mean and standard deviation.
///
/// - Parameters:
///	- mean: The mean of the normal distribution. Defaults to 0.
///	- stdDev: The standard deviation of the normal distribution. Defaults to 1.
///	- u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///	- u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
///
/// - Returns: A value distributed according to the normal distribution with the given mean and standard deviation.
///
/// - Note:
///   - The function `boxMullerSeed` is used internally to generate the standard normally distributed values.
///
/// - Example:
///   ```swift
///   let normalValue = boxMuller(mean: 5.0, stdDev: 2.0)
///   ```
///
/// - Requires: Appropriate implementation of the function `boxMullerSeed` to generate standard normal values.

public func boxMuller<T: Real>(mean: T = T(0), stdDev: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard !stdDev.isNaN, stdDev.isFinite else { return T.nan }
	guard stdDev >= T(0) else { return T.nan }  // Negative stdDev is invalid
	guard !mean.isNaN, mean.isFinite else { return T.nan }

	// Handle degenerate case: stdDev = 0 means deterministic (always returns mean)
	if stdDev == T(0) { return mean }

	return (stdDev * boxMullerSeed(u1Seed, u2Seed).z1) + mean
}

/// Generates a single random number from a normal (Gaussian) distribution with a specified mean and variance using the Box-Muller transform.
///
/// This function relies on the Box-Muller transform to generate standard normally distributed values and scales them according to the specified mean and variance.
///
/// - Parameters:
///	- mean: The mean of the normal distribution. Defaults to 0.
///	- variance: The variance of the normal distribution. Defaults to 1.
///	- u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///	- u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
///
/// - Returns: A value distributed according to the normal distribution with the given mean and variance.
///
/// - Note:
///   - The function `boxMullerSeed` is used internally to generate the standard normally distributed values.
///
/// - Example:
///   ```swift
///   let normalValue = boxMuller(mean: 5.0, stdDev: 2.0)
///   ```
///
/// - Requires: Appropriate implementation of the function `boxMullerSeed` to generate standard normal values.
public func boxMuller<T: Real>(mean: T, variance: T, _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard !variance.isNaN, variance.isFinite else { return T.nan }
	guard variance >= T(0) else { return T.nan }  // Negative variance is invalid

	// Handle degenerate case: variance = 0 means stdDev = 0 (deterministic)
	if variance == T(0) { return mean }

	return boxMuller(mean: mean, stdDev: T.sqrt(variance), u1Seed, u2Seed)
}
