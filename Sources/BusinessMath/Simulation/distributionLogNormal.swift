//
//  distributionLogNormal.swift
//  
//
//  Created by Justin Purnell on 3/28/22.
//

import Foundation
import Numerics

// https://en.wikipedia.org/wiki/Log-normal_distribution#Related_distributions

/// A log-normal draw, parameterised by the mean and standard deviation of its **logarithm**.
///
/// `X = exp(N)` where `N ~ Normal(logMean, logStdDev)`. The parameters describe `N`, not `X`.
/// `X` itself has mean `exp(logMean + logStdDev²/2)` and median `exp(logMean)`, neither of
/// which is `logMean`.
///
/// The names say so now because they used to say the opposite. These parameters were called
/// `mean` and `stdDev`, and the documentation read *"Returns a log normal distribution of
/// values with mean µ and standard deviation σ"* — which is the misreading, printed as the
/// contract. ``DistributionMVLogNormal`` has always spelled the multivariate version
/// `logMeans` and `logStandardDeviations`; this is the same distribution answering to the
/// same names.
///
/// - Parameters:
///   - logMean: The mean of `log(X)`, not of `X`.
///   - logStdDev: The standard deviation of `log(X)`, not of `X`.
///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
/// - Returns: A positive value whose logarithm is `Normal(logMean, logStdDev)`.
public func distributionLogNormal<T: Real>(logMean: T = T(0), logStdDev: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	return T.exp(distributionNormal(mean: logMean, stdDev: logStdDev, u1Seed, u2Seed))
}

/// A log-normal draw, parameterised by the mean and variance of its **logarithm**.
///
/// The variance form of ``distributionLogNormal(logMean:logStdDev:_:_:)``; see there for why
/// the parameters carry the `log` prefix.
///
/// - Parameters:
///   - logMean: The mean of `log(X)`, not of `X`.
///   - logVariance: The variance of `log(X)`, not of `X`.
///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
/// - Returns: A positive value whose logarithm is `Normal(logMean, logVariance)`.
public func distributionLogNormal<T: Real>(logMean: T = T(0), logVariance: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	return T.exp(distributionNormal(mean: logMean, variance: logVariance, u1Seed, u2Seed))
}

/// Deprecated spelling of ``distributionLogNormal(logMean:logStdDev:_:_:)``.
///
/// - Parameters:
///   - mean: The mean of `log(X)`, despite the name. Use `logMean:` instead.
///   - stdDev: The standard deviation of `log(X)`, despite the name. Use `logStdDev:` instead.
///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
/// - Returns: A positive value whose logarithm is `Normal(mean, stdDev)`.
@available(*, deprecated, renamed: "distributionLogNormal(logMean:logStdDev:_:_:)", message: "`mean` and `stdDev` describe log(X), not X. Renamed so the parameter cannot be read as the mean of the variate it returns.")
public func distributionLogNormal<T: Real>(mean: T = T(0), stdDev: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	return distributionLogNormal(logMean: mean, logStdDev: stdDev, u1Seed, u2Seed)
}

/// Deprecated spelling of ``distributionLogNormal(logMean:logVariance:_:_:)``.
///
/// - Parameters:
///   - mean: The mean of `log(X)`, despite the name. Use `logMean:` instead.
///   - variance: The variance of `log(X)`, despite the name. Use `logVariance:` instead.
///   - u1Seed: First uniform random seed in [0, 1] (default: newly generated)
///   - u2Seed: Second uniform random seed in [0, 1] (default: newly generated)
/// - Returns: A positive value whose logarithm is `Normal(mean, variance)`.
@available(*, deprecated, renamed: "distributionLogNormal(logMean:logVariance:_:_:)", message: "`mean` and `variance` describe log(X), not X. Renamed so the parameter cannot be read as the mean of the variate it returns.")
public func distributionLogNormal<T: Real>(mean: T = T(0), variance: T = T(1), _ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	return distributionLogNormal(logMean: mean, logVariance: variance, u1Seed, u2Seed)
}

/// A log-normal distribution generator for producing positive-only random values.
///
/// The log-normal distribution is useful for modeling quantities that are always positive
/// and have multiplicative rather than additive variation (e.g., stock prices, incomes).
public struct DistributionLogNormal: DistributionRandom, Sendable {
	/// The mean of `log(X)`. Not the mean of `X`, which is `exp(logMean + logStdDev²/2)`.
	let logMean: Double
	/// The standard deviation of `log(X)`. Not the standard deviation of `X`.
	let logStdDev: Double

	/// Creates a log-normal generator from the mean and standard deviation of its logarithm.
	/// - Parameters:
	///   - logMean: Mean of the underlying normal (default: 0)
	///   - logStdDev: Standard deviation of the underlying normal (default: 1.0)
	public init(_ logMean: Double = 0, _ logStdDev: Double = 1.0) {
		self.logMean = logMean
		self.logStdDev = logStdDev
	}

	/// Creates a log-normal generator from the mean and standard deviation of its logarithm.
	/// - Parameters:
	///   - logMean: Mean of the underlying normal (default: 0)
	///   - logStdDev: Standard deviation of the underlying normal (default: 1.0)
	public init(logMean: Double = 0, logStdDev: Double = 1.0) {
		self.logMean = logMean
		self.logStdDev = logStdDev
	}

	/// Creates a log-normal generator from the mean and variance of its logarithm.
	/// - Parameters:
	///   - logMean: Mean of the underlying normal (default: 0)
	///   - logVariance: Variance of the underlying normal (default: 1.0)
	public init(logMean: Double = 0, logVariance: Double = 1.0) {
		self.logMean = logMean
		self.logStdDev = Double.sqrt(logVariance)
	}

	/// Deprecated spelling of ``init(logMean:logVariance:)``.
	///
	/// - Parameters:
	///   - mean: Mean of the underlying normal, despite the name. Use `logMean:` instead.
	///   - variance: Variance of the underlying normal, despite the name. Use `logVariance:` instead.
	@available(*, deprecated, renamed: "init(logMean:logVariance:)", message: "`mean` and `variance` describe log(X), not X.")
	public init(mean: Double = 0, variance: Double = 1.0) {
		self.logMean = mean
		self.logStdDev = Double.sqrt(variance)
	}

	/// Generates a random value from the log-normal distribution.
	/// - Returns: A random positive Double from the log-normal distribution
	public func random() -> Double {
		return distributionLogNormal(logMean: logMean, logStdDev: logStdDev)
	}

	/// Generates the next random value from the log-normal distribution.
	/// - Returns: A random positive Double from the log-normal distribution
	public func next() -> Double {
		return random()
	}
}

extension DistributionLogNormal: SeedableDistribution {
	/// Generates the next random value, drawing both Box-Muller uniforms from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the two uniform draws.
	/// - Returns: A random positive Double from the log-normal distribution
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionLogNormal(logMean: logMean, logStdDev: logStdDev,
									 Double.random(in: 0...1, using: &generator),
									 Double.random(in: 0...1, using: &generator))
	}
}


extension DistributionLogNormal: ContinuousDistribution {
	/// P(X ≤ x) for this log-normal.
	///
	/// `logMean` and `logStdDev` are the parameters of the *underlying normal* — the
	/// distribution is `exp(Normal(logMean, logStdDev))`, not a variate whose arithmetic
	/// mean is `logMean`. The names used to be `mean` and `stdDev`, and this paragraph
	/// existed to undo them. Frontline's `PsiLogNormal` states its parameters the other
	/// way; a binding must convert, and this is the side of that conversion the
	/// mathematics lives on.
	public func cdf(_ x: Double) -> Double {
		logNormalCDF(x, mean: logMean, stdDev: logStdDev)
	}

	/// The value at which the CDF equals `p`: `exp` of the normal quantile.
	public func quantile(_ p: Double) -> Double {
		Double.exp(inverseNormalCDF(p: p, mean: logMean, stdDev: logStdDev))
	}

	// Keeps its own `next(using:)`: `exp` of a Box–Muller draw, two uniforms.
}
