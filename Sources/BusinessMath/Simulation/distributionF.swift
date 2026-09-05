//
//  distributionF.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
#if canImport(OSLog)
import OSLog
#endif

/// Generates a random value from an F-distribution with the specified degrees of freedom.
///
/// The F-distribution is a continuous probability distribution that arises frequently in
/// statistical inference, particularly in the analysis of variance (ANOVA) and in comparing
/// variances of two populations.
///
/// ## Distribution Properties
///
/// - **Domain**: [0, +∞)
/// - **Mean**: df2/(df2-2) for df2 > 2, undefined otherwise
/// - **Variance**: [2×df2²×(df1+df2-2)] / [df1×(df2-2)²×(df2-4)] for df2 > 4
/// - **Mode**: [(df1-2)/df1] × [df2/(df2+2)] for df1 > 2
///
/// ## Key Characteristics
///
/// - Always positive (non-negative)
/// - Right-skewed distribution
/// - As both df1 and df2 increase, approaches normal distribution
/// - Reciprocal relationship: F(df1, df2) ~ 1/F(df2, df1)
///
/// ## Common Use Cases
///
/// - Analysis of Variance (ANOVA)
/// - Comparing variances of two populations
/// - Testing equality of multiple means
/// - Model comparison and regression analysis
/// - Ratio of two chi-squared distributions
///
/// ## Implementation
///
/// This function uses the relationship between F and Chi-squared distributions:
/// F(df1, df2) = (χ²(df1)/df1) / (χ²(df2)/df2)
///
/// - Parameters:
///   - df1: The first degrees of freedom parameter (numerator, df1 > 0)
///   - df2: The second degrees of freedom parameter (denominator, df2 > 0)
///   - seed: Seed for a private ``DeterministicRNG``. The same seed with the same degrees
///     of freedom reproduces the same value exactly. `nil` (the default) draws from system
///     entropy and is non-reproducible by contract — use `seed:` or
///     ``distributionF(df1:df2:using:)`` when reproducibility matters.
/// - Returns: A random value sampled from the F(df1, df2) distribution, or NaN if df1 ≤ 0 or df2 ≤ 0
///
/// ## Example
///
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// // Test variance ratio in ANOVA
/// let fStat: Double = distributionF(df1: 5, df2: 20)
/// print("F-statistic: \(fStat)")
///
/// // The same value on every run
/// let reproducible: Double = distributionF(df1: 5, df2: 20, seed: 42)
///
/// // Invalid degrees of freedom returns NaN
/// let invalid: Double = distributionF(df1: 0, df2: 10)
/// print(invalid.isNaN)  // true
/// ```
@available(macOS 11.0, *)
public func distributionF<T: Real>(df1: Int, df2: Int, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionF(df1: df1, df2: df2, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionF(df1: df1, df2: df2, using: &generator)
}

/// Generates an F variate, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``distributionF(df1:df2:seed:)``, following the
/// same convention as ``SeedableDistribution/next(using:)``: all randomness comes from the
/// caller's generator, so the caller owns reproducibility and can interleave this draw
/// with others on a single stream.
///
/// The two chi-squared variates are drawn in sequence from the one stream. The array form
/// this replaced split a fixed `[Double]` down the middle and handed half to each — so
/// neither chi-squared got a stream it could finish, and at df1 = df2 = 1 the draw
/// silently left the supplied uniforms on 5.5% of calls.
///
/// - Parameters:
///   - df1: The first degrees of freedom parameter (numerator, df1 > 0)
///   - df2: The second degrees of freedom parameter (denominator, df2 > 0)
///   - generator: The random source. Advanced by a data-dependent number of draws.
/// - Returns: A random value sampled from the F(df1, df2) distribution, or NaN if df1 ≤ 0 or df2 ≤ 0
@available(macOS 11.0, *)
public func distributionF<T: Real, G: RandomNumberGenerator>(df1: Int, df2: Int, using generator: inout G) -> T where T: BinaryFloatingPoint {
	// F-distribution is undefined for df1 ≤ 0 or df2 ≤ 0
	guard df1 > 0, df2 > 0 else {
		return T.nan
	}

	// F(df1, df2) = (χ²(df1)/df1) / (χ²(df2)/df2)
	// where χ²(df) = Gamma(df/2, 2)

	let dfOne = T(df1)
	let dfTwo = T(df2)

	let chi1: T = distributionChiSquared(degreesOfFreedom: df1, using: &generator)
	let chi2: T = distributionChiSquared(degreesOfFreedom: df2, using: &generator)

	// F = (χ²₁/df1) / (χ²₂/df2)
	let numerator = chi1 / dfOne // fp-safety:disable — df1 > 0 guarded above
	let denominator = chi2 / dfTwo // fp-safety:disable — df2 > 0 guarded above

	guard denominator > T(0) else {
		// Degenerate underflow (measure zero for valid df2): mirror the NaN convention
		return T.nan
	}
	return numerator / denominator // fp-safety:disable — guarded by denominator > 0 above
}

/// A type that represents an F-distribution.
///
/// The F-distribution is a continuous probability distribution that arises when comparing
/// variances or in the analysis of variance (ANOVA). It is the ratio of two scaled
/// chi-squared distributions.
///
/// ## Properties
///
/// - **df1**: The first degrees of freedom (numerator, df1 > 0)
/// - **df2**: The second degrees of freedom (denominator, df2 > 0)
/// - **Mean**: df2/(df2-2) for df2 > 2
///
/// ## Distribution Behavior
///
/// - **Small df**: More right-skewed, heavier tails
/// - **Large df**: More symmetric, approaches normal
/// - **df2 ≤ 2**: Mean undefined
/// - **df2 ≤ 4**: Variance undefined
///
/// ## Example
///
/// ```swift
/// // Create a distribution for ANOVA with 5 groups and 20 observations
/// let fDist = DistributionF(df1: 4, df2: 15)
/// let testStatistic = fDist.random()
/// print("F-statistic: \(testStatistic)")
///
/// // Create a distribution for variance comparison
/// let varianceTest = DistributionF(df1: 10, df2: 12)
/// let ratio = varianceTest.next()
/// ```
@available(macOS 11.0, *)
public struct DistributionF: DistributionRandom, Sendable {
	/// The first degrees of freedom (numerator, df1 > 0)
	let df1: Int

	/// The second degrees of freedom (denominator, df2 > 0)
	let df2: Int

	/// Creates a new instance of `DistributionF` with the specified degrees of freedom.
	///
	/// - Parameters:
	///   - df1: The first degrees of freedom (numerator, df1 > 0)
	///   - df2: The second degrees of freedom (denominator, df2 > 0)
	public init(df1: Int, df2: Int) {
		guard df1 > 0 else {
			preconditionFailure("First degrees of freedom must be positive")
		}
		guard df2 > 0 else {
			preconditionFailure("Second degrees of freedom must be positive")
		}
		self.df1 = df1
		self.df2 = df2
	}

	/// Generates a random value from the F-distribution.
	///
	/// - Returns: A random value sampled from F(df1, df2), always non-negative
	public func random() -> Double {
		return distributionF(df1: df1, df2: df2)
	}

	/// Generates the next random value from the F-distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from F(df1, df2), always non-negative
	public func next() -> Double {
		return random()
	}
}

@available(macOS 11.0, *)
extension DistributionF: SeedableDistribution {
	/// Generates the next random value, drawing all randomness from `generator`.
	///
	/// Follows the same probability law as ``next()`` — F = (χ²(df1)/df1) / (χ²(df2)/df2),
	/// with each chi-squared variate built as Gamma(df/2, 2) via Marsaglia-Tsang (the same
	/// construction `distributionChiSquared` uses) — sourcing every uniform draw from
	/// `generator`; a seeded generator makes the stream fully reproducible.
	///
	/// - Parameter generator: The random source for every uniform draw.
	/// - Returns: A random Double sampled from F(df1, df2), always non-negative
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionF(df1: df1, df2: df2, using: &generator)
	}
}


extension DistributionF: ContinuousDistribution {
	/// P(X ≤ x) for this F distribution.
	public func cdf(_ x: Double) -> Double {
		totalizedResult { try fCDF(f: x, df1: df1, df2: df2) }
	}

	/// The value at which the CDF equals `p`.
	public func quantile(_ p: Double) -> Double {
		totalizedResult { try fQuantile(p: p, df1: df1, df2: df2) }
	}

	// Keeps its own `next(using:)`: a ratio of two chi-squared variates.
}
