//
//  distributionChiSquared.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
#if canImport(OSLog)
import OSLog
#endif

/// Generates a random value from a Chi-squared distribution with the specified degrees of freedom.
///
/// The Chi-squared distribution is a continuous probability distribution that arises in
/// statistical inference, particularly in hypothesis testing and confidence interval estimation.
/// It is the distribution of the sum of squares of independent standard normal random variables.
///
/// ## Distribution Properties
///
/// - **Domain**: [0, +∞)
/// - **Mean**: df (degrees of freedom)
/// - **Variance**: 2×df
/// - **Mode**: max(df - 2, 0) for df ≥ 2
///
/// ## Key Characteristics
///
/// - Always positive (non-negative)
/// - Right-skewed, especially for low degrees of freedom
/// - As df increases, becomes more symmetric and approaches a normal distribution
/// - Special case: df=2 is equivalent to Exponential(0.5)
///
/// ## Common Use Cases
///
/// - Goodness-of-fit tests
/// - Test of independence in contingency tables
/// - Variance estimation and hypothesis testing
/// - Confidence intervals for population variance
/// - Model comparison and likelihood ratio tests
///
/// ## Implementation
///
/// This function uses the relationship between Chi-squared and Gamma distributions:
/// χ²(df) = Gamma(df/2, 2)
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
///   - seed: Seed for a private ``DeterministicRNG``. The same seed and the same `df`
///     reproduce the same value exactly, however many rejection iterations the underlying
///     gamma draw happens to need. `nil` (the default) draws from system entropy and is
///     non-reproducible by contract — use `seed:` or
///     ``distributionChiSquared(degreesOfFreedom:using:)`` when reproducibility matters.
/// - Returns: A random value sampled from the χ²(df) distribution, or NaN if df ≤ 0
///
/// ## Example
///
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// let values = [100.0, 110.0, 120.0, 130.0]
/// // Generate chi-squared values for goodness-of-fit test
/// let chiSq: Double = distributionChiSquared(degreesOfFreedom: 10)
/// print("Chi-squared statistic: \(chiSq)")
///
/// // The same value on every run
/// let reproducible: Double = distributionChiSquared(degreesOfFreedom: 10, seed: 42)
///
/// // Invalid degrees of freedom returns NaN
/// let invalid: Double = distributionChiSquared(degreesOfFreedom: 0)
/// print(invalid.isNaN)  // true
/// ```
@available(macOS 11.0, *)
public func distributionChiSquared<T: Real>(degreesOfFreedom: Int, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionChiSquared(degreesOfFreedom: degreesOfFreedom, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionChiSquared(degreesOfFreedom: degreesOfFreedom, using: &generator)
}

/// Generates a chi-squared variate, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``distributionChiSquared(degreesOfFreedom:seed:)``,
/// following the same convention as ``SeedableDistribution/next(using:)``: all randomness
/// comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on a single stream.
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
///   - generator: The random source. Advanced by a data-dependent number of draws, since
///     the underlying Marsaglia-Tsang sampler rejects.
/// - Returns: A random value sampled from the χ²(df) distribution, or NaN if df ≤ 0
@available(macOS 11.0, *)
public func distributionChiSquared<T: Real, G: RandomNumberGenerator>(degreesOfFreedom: Int, using generator: inout G) -> T where T: BinaryFloatingPoint {
	guard degreesOfFreedom > 0 else {
		// Chi-squared distribution is undefined for df ≤ 0
		return T.nan
	}

	// Chi-squared(df) = Gamma(df/2, 2)
	let df = T(degreesOfFreedom)
	let shape = df / T(2)
	let scale = T(2)

	return gammaVariate(shape: shape, scale: scale, using: &generator)
}

/// Generates a random value from a Chi-squared distribution with validation.
///
/// Same as ``distributionChiSquared(degreesOfFreedom:seed:)`` but throws an error instead
/// of returning NaN for invalid degrees of freedom.
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (must be > 0)
///   - seed: Seed for a private ``DeterministicRNG``; `nil` (the default) draws from
///     system entropy and is non-reproducible by contract.
/// - Returns: A random value sampled from the χ²(df) distribution
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if df ≤ 0
@available(macOS 11.0, *)
public func distributionChiSquaredThrowing<T: Real>(degreesOfFreedom: Int, seed: UInt64? = nil) throws -> T where T: BinaryFloatingPoint {
	guard degreesOfFreedom > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(degreesOfFreedom)",
			expectedRange: "> 0"
		)
	}
	return distributionChiSquared(degreesOfFreedom: degreesOfFreedom, seed: seed)
}

/// Generates a validated chi-squared variate, drawing every uniform from `generator`.
///
/// The generator-parameterized form of
/// ``distributionChiSquaredThrowing(degreesOfFreedom:seed:)``.
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (must be > 0)
///   - generator: The random source.
/// - Returns: A random value sampled from the χ²(df) distribution
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if df ≤ 0
@available(macOS 11.0, *)
public func distributionChiSquaredThrowing<T: Real, G: RandomNumberGenerator>(degreesOfFreedom: Int, using generator: inout G) throws -> T where T: BinaryFloatingPoint {
	guard degreesOfFreedom > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(degreesOfFreedom)",
			expectedRange: "> 0"
		)
	}
	return distributionChiSquared(degreesOfFreedom: degreesOfFreedom, using: &generator)
}

/// A type that represents a Chi-squared distribution.
///
/// The Chi-squared distribution is a continuous probability distribution that is widely used
/// in statistical inference, particularly for hypothesis testing involving variances and
/// categorical data analysis.
///
/// ## Properties
///
/// - **degreesOfFreedom**: The degrees of freedom parameter (df > 0)
/// - **Mean**: df
/// - **Variance**: 2×df
///
/// ## Distribution Behavior
///
/// - **Low df (1-5)**: Highly right-skewed
/// - **Medium df (5-20)**: Moderately skewed
/// - **High df (>30)**: Approaches normal distribution
///
/// ## Example
///
/// ```swift
/// // Create a distribution for goodness-of-fit testing
/// let chiSq = DistributionChiSquared(degreesOfFreedom: 10)
/// let testStatistic = chiSq.random()
/// print("Chi-squared test statistic: \(testStatistic)")
///
/// // Create a distribution for variance estimation
/// let varianceTest = DistributionChiSquared(degreesOfFreedom: 25)
/// let sample = varianceTest.next()
/// ```
@available(macOS 11.0, *)
public struct DistributionChiSquared: DistributionRandom {
	/// The degrees of freedom parameter (df > 0)
	let degreesOfFreedom: Int

	/// Creates a new instance of `DistributionChiSquared` with the specified degrees of freedom.
	///
	/// - Parameters:
	///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
	public init(degreesOfFreedom: Int) {
		guard degreesOfFreedom > 0 else {
			preconditionFailure("Degrees of freedom must be positive")
		}
		self.degreesOfFreedom = degreesOfFreedom
	}

	/// Generates a random value from the Chi-squared distribution.
	///
	/// - Returns: A random value sampled from χ²(df), always non-negative
	public func random() -> Double {
		return distributionChiSquared(degreesOfFreedom: degreesOfFreedom)
	}

	/// Generates the next random value from the Chi-squared distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from χ²(df), always non-negative
	public func next() -> Double {
		return random()
	}
}

@available(macOS 11.0, *)
extension DistributionChiSquared: SeedableDistribution {
	/// Generates the next random value, drawing every underlying uniform from `generator`.
	///
	/// Uses the defining property χ²(df) = Σᵢ Zᵢ² over `df` independent standard
	/// normal draws, each produced by the seeded Box-Muller transform, so the result
	/// follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for all standard normal draws.
	/// - Returns: A random value sampled from χ²(df), always non-negative
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		let standardNormal = DistributionNormal(0.0, 1.0)
		var sumOfSquares = 0.0
		for _ in 0..<degreesOfFreedom {
			let z = standardNormal.next(using: &generator)
			sumOfSquares += z * z
		}
		return sumOfSquares
	}
}
