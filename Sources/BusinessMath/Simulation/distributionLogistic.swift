//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// Generates a logistic distribution value based on the specified mean and standard deviation.
///
/// The logistic distribution is useful for modeling growth and logistic regression. It's similar to the normal distribution but has heavier tails.
///
/// - Parameters:
///	- mean: The mean of the logistic distribution. Defaults to 0.
///	- stdDev: The standard deviation of the logistic distribution. Defaults to 1.
///	- seed: Optional uniform random seed in [0, 1] for deterministic generation (default: nil)
///
/// - Returns: A value distributed according to the logistic distribution based on the specified mean and standard deviation.
///
/// - Note:
///   - The internal probability `p` should be in the open interval (0, 1). Values outside this range will result in mathematical errors.
///   - The constant `magicNumber` is derived as `sqrt(3) / π` which is used to scale the standard deviation.
///
/// - Requires: The use of appropriate `Real` compatible number types for accurate results.

public func distributionLogistic<T: Real>(_ mean: T = 0, _ stdDev: T = 1, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	let p: T
	if let seed = seed {
		p = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		p = distributionUniform()
	}
	let magicNumber = T.sqrt(3) / T.pi
	return mean + magicNumber * stdDev * T.log(p / (1 - p))
}

/// A logistic distribution generator for producing random values.
///
/// The logistic distribution is similar to the normal distribution but has heavier tails.
/// Commonly used in logistic regression and growth modeling.
public struct DistributionLogistic: DistributionRandom {
	let mean: Double
	let stdDev: Double

	/// Creates a logistic distribution generator using mean and standard deviation.
	/// - Parameters:
	///   - mean: Mean of the distribution (default: 0)
	///   - stdDev: Standard deviation of the distribution (default: 1)
	public init(_ mean: Double = 0, _ stdDev: Double = 1) {
		self.mean = mean
		self.stdDev = stdDev
	}

	/// Creates a logistic distribution generator using mean and variance.
	/// - Parameters:
	///   - mean: Mean of the distribution (default: 0)
	///   - variance: Variance of the distribution (default: 1)
	public init(mean: Double = 0, variance: Double = 1) {
		self.mean = mean
		self.stdDev = Double.sqrt(variance)
	}

	/// Generates a random value from the logistic distribution.
	/// - Returns: A random Double from the logistic distribution
	public func random() -> Double {
		return distributionLogistic(mean, stdDev)
	}

	/// Generates the next random value from the logistic distribution.
	/// - Returns: A random Double from the logistic distribution
	public func next() -> Double {
		return random()
	}
}
