//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// √3⁄π — the factor relating a logistic distribution's standard deviation to its
/// scale parameter *s*.
///
/// A logistic variate has variance `s²π²/3`, so `s = σ√3/π`. This is not a tuning
/// constant and not an approximation: it is that identity solved for *s*, and it is
/// named because it appeared twice in this file — once in the sampler as
/// `magicNumber`, once in the CDF — and two copies are two chances to disagree about
/// what `stdDev` means.
internal func logisticScaleFactor<T: Real>() -> T {
	T.sqrt(3) / T.pi
}

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
	// Validate parameters - return NaN for invalid inputs
	guard !stdDev.isNaN, stdDev.isFinite else { return T.nan }
	guard stdDev >= T(0) else { return T.nan }  // Negative stdDev is invalid
	guard !mean.isNaN, mean.isFinite else { return T.nan }

	// Handle degenerate case: stdDev = 0 means deterministic (always returns mean)
	if stdDev == T(0) { return mean }

	let p: T
	if let seed = seed {
		p = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		p = distributionUniform()
	}
	let scaleFactor: T = logisticScaleFactor()
	let odds: T = p / (1 - p)
	return mean + scaleFactor * stdDev * T.log(odds)
}

/// A logistic distribution generator for producing random values.
///
/// The logistic distribution is similar to the normal distribution but has heavier tails.
/// Commonly used in logistic regression and growth modeling.
public struct DistributionLogistic: DistributionRandom, Sendable {
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

extension DistributionLogistic: SeedableDistribution {
	/// Generates the next random value, drawing the quantile-transform uniform from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the single uniform draw.
	/// - Returns: A random Double from the logistic distribution with configured mean and standard deviation
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionLogistic(mean, stdDev,
									seed: Double.random(in: 0...1, using: &generator))
	}
}


extension DistributionLogistic: ContinuousDistribution {
	/// The logistic scale parameter *s*, derived from the standard deviation.
	///
	/// A logistic distribution has variance `s²π²/3`, so `s = σ√3/π`. This type is
	/// parameterised by σ, and the sampler at the top of this file uses the same
	/// factor — it calls it `magicNumber`.
	private var logisticScale: Double {
		let factor: Double = logisticScaleFactor()
		return factor * stdDev
	}

	/// P(X ≤ x) = 1 / (1 + exp(−(x − μ)/s)).
	public func cdf(_ x: Double) -> Double {
		let scale = logisticScale
		guard scale > 0 else { return x < mean ? 0 : 1 }
		let z = (x - mean) / scale
		return 1 / (1 + Double.exp(-z))
	}

	/// The value at which the CDF equals `p`: μ + s·ln(p / (1 − p)).
	public func quantile(_ p: Double) -> Double {
		let scale = logisticScale
		guard scale > 0 else { return mean }
		let complement = 1 - p
		guard p > 0, complement > 0 else {
			return p <= 0 ? -Double.infinity : Double.infinity
		}
		let odds = p / complement
		return mean + scale * Double.log(odds)
	}
}
