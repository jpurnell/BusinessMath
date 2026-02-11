//
//  distributionNormal.swift
//
//
//  Created by Justin Purnell on 3/21/22.
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
public func distributionNormal<T: Real>(mean: T = T(0), stdDev: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	return boxMuller(mean: mean, stdDev: stdDev, u1Seed, u2Seed)
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
public func distributionNormal<T: Real>(mean: T = T(0), variance: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	return boxMuller(mean: mean, variance: variance, u1Seed, u2Seed)
}

/// A normal (Gaussian) distribution generator for producing random values.
///
/// `DistributionNormal` uses the Box-Muller transform to generate random values from a
/// normal distribution with specified mean and standard deviation. The normal distribution
/// is the bell curve used throughout statistics and probability theory.
public struct DistributionNormal: DistributionRandom, Sendable {

	var mean: Double = 0.0
	var stdDev: Double = 1.0

	/// Creates a normal distribution generator using mean and standard deviation.
	/// - Parameters:
	///   - mean: The mean of the distribution (default: 0.0)
	///   - stdDev: The standard deviation of the distribution (default: 1.0)
	public init(_ mean: Double = 0.0, _ stdDev: Double = 1.0) {
		self.mean = mean
		self.stdDev = stdDev
	}

	/// Creates a normal distribution generator using mean and variance.
	/// - Parameters:
	///   - mean: The mean of the distribution (default: 0.0)
	///   - variance: The variance of the distribution (default: 1.0)
	public init(mean: Double = 0.0, variance: Double = 1.0) {
		self.mean = mean
		self.stdDev = Double.sqrt(variance)
	}


	/// Generates a random value from the normal distribution.
	/// - Returns: A random Double from the normal distribution with configured mean and standard deviation
	public func random() -> Double {
		return distributionNormal(mean: mean, stdDev: stdDev)
	}

	/// Generates the next random value from the normal distribution.
	/// - Returns: A random Double from the normal distribution with configured mean and standard deviation
	public func next() -> Double {
		return random()
	}
}
