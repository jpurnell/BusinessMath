//
//  distributionF.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics
import OSLog

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
/// - Returns: A random value sampled from the F(df1, df2) distribution
///
/// ## Example
///
/// ```swift
/// // Test variance ratio in ANOVA
/// let fStat: Double = distributionF(df1: 5, df2: 20)
/// print("F-statistic: \(fStat)")
///
/// // Compare variances of two samples
/// let varianceRatio: Double = distributionF(df1: 10, df2: 15)
/// ```
@available(macOS 11.0, *)
public func distributionF<T: Real>(df1: Int, df2: Int, seeds: [Double]? = nil) -> T {
	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")
//	precondition(df1 > 0, "First degrees of freedom must be positive")
//	precondition(df2 > 0, "Second degrees of freedom must be positive")

	guard df1 > 0 else {
			#if DEBUG
			logger.error("Invalid first degrees of freedom: \(df1). Using default value of 1.")
			#endif
			// Use minimum valid value
			return distributionF(df1: 1, df2: df2, seeds: seeds)
		}

		guard df2 > 0 else {
			#if DEBUG
			logger.error("Invalid second degrees of freedom: \(df2). Using default value of 1.")
			#endif
			// Use minimum valid value
			return distributionF(df1: df1, df2: 1, seeds: seeds)
		}
	
	// F(df1, df2) = (χ²(df1)/df1) / (χ²(df2)/df2)
	// where χ²(df) = Gamma(df/2, 2)

	let dfOne = T(df1)
	let dfTwo = T(df2)

	// Generate two independent chi-squared random variables
	// Split seeds: first half for chi1, second half for chi2
	let chi1Seeds: [Double]?
	let chi2Seeds: [Double]?

	if let seeds = seeds {
		let midpoint = seeds.count / 2
		chi1Seeds = Array(seeds[0..<midpoint])
		chi2Seeds = Array(seeds[midpoint..<seeds.count])
	} else {
		chi1Seeds = nil
		chi2Seeds = nil
	}

	let chi1: T = distributionChiSquared(degreesOfFreedom: df1, seeds: chi1Seeds)
	let chi2: T = distributionChiSquared(degreesOfFreedom: df2, seeds: chi2Seeds)

	// F = (χ²₁/df1) / (χ²₂/df2)
	let numerator = chi1 / dfOne
	let denominator = chi2 / dfTwo

	return numerator / denominator
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
public struct DistributionF: DistributionRandom {
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
		precondition(df1 > 0, "First degrees of freedom must be positive")
		precondition(df2 > 0, "Second degrees of freedom must be positive")
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
