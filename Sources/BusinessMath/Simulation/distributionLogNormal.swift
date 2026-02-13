//
//  distributionLogNormal.swift
//  
//
//  Created by Justin Purnell on 3/28/22.
//

import Foundation
import Numerics

// https://en.wikipedia.org/wiki/Log-normal_distribution#Related_distributions

/// Returns a log normal distribution of values with mean µ and standard deviation σ
/// - Parameters:
///   - mean: The mean of the distribution
///   - stdDev: The standard deviation of the distribution
///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
/// - Returns: A Log Normal distributed value, x, centered on the mean µ with a standard deviation of σ. Running this function many times will generate an array of values that is distributed log normally around µ with std dev of σ
public func distributionLogNormal<T: Real>(mean: T = T(0), stdDev: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
    return T.exp(distributionNormal(mean: mean, stdDev: stdDev, u1Seed, u2Seed))
}

	/// Returns a log normal distribution of values with mean µ and variance σ^2
	/// - Parameters:
	///   - mean: The mean of the distribution
	///   - variance: The variance of the distribution
	///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
	///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
	/// - Returns: A Log Normal distributed value, x, centered on the mean µ with a variance of σ^2. Running this function many times will generate an array of values that is distributed log normally around µ with variance of σ^2
public func distributionLogNormal<T: Real>(mean: T = T(0), variance: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
    return T.exp(distributionNormal(mean: mean, variance: variance, u1Seed, u2Seed))
}

/// A log-normal distribution generator for producing positive-only random values.
///
/// The log-normal distribution is useful for modeling quantities that are always positive
/// and have multiplicative rather than additive variation (e.g., stock prices, incomes).
public struct DistributionLogNormal: DistributionRandom, Sendable {
	let mean: Double
	let stdDev: Double

	/// Creates a log-normal distribution generator using mean and standard deviation.
	/// - Parameters:
	///   - mean: Mean of the underlying normal distribution (default: 0)
	///   - stdDev: Standard deviation of the underlying normal (default: 1.0)
	public init(_ mean: Double = 0, _ stdDev: Double = 1.0) {
		self.mean = mean
		self.stdDev = stdDev
	}

	/// Creates a log-normal distribution generator using mean and variance.
	/// - Parameters:
	///   - mean: Mean of the underlying normal distribution (default: 0)
	///   - variance: Variance of the underlying normal (default: 1.0)
	public init(mean: Double = 0, variance: Double = 1.0) {
		self.mean = mean
		self.stdDev = Double.sqrt(variance)
	}

	/// Generates a random value from the log-normal distribution.
	/// - Returns: A random positive Double from the log-normal distribution
	public func random() -> Double {
		return distributionLogNormal(mean: mean, stdDev: stdDev)
	}

	/// Generates the next random value from the log-normal distribution.
	/// - Returns: A random positive Double from the log-normal distribution
	public func next() -> Double {
		return random()
	}
}
