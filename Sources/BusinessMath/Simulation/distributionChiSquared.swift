//
//  distributionChiSquared.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

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
/// - Returns: A random value sampled from the χ²(df) distribution
///
/// ## Example
///
/// ```swift
/// // Generate chi-squared values for goodness-of-fit test
/// let chiSq: Double = distributionChiSquared(degreesOfFreedom: 10)
/// print("Chi-squared statistic: \(chiSq)")
///
/// // Generate variance estimates
/// let variance: Double = distributionChiSquared(degreesOfFreedom: 20)
/// ```
public func distributionChiSquared<T: Real>(degreesOfFreedom: Int, seeds: [Double]? = nil) -> T {
	precondition(degreesOfFreedom > 0, "Degrees of freedom must be positive")

	var seedIndex = 0

	// Chi-squared(df) = Gamma(df/2, 2)
	let df = T(degreesOfFreedom)
	let shape = df / T(2)
	let scale = T(2)

	return gammaVariate(shape: shape, scale: scale, seeds: seeds, seedIndex: &seedIndex)
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
public struct DistributionChiSquared: DistributionRandom {
	/// The degrees of freedom parameter (df > 0)
	let degreesOfFreedom: Int

	/// Creates a new instance of `DistributionChiSquared` with the specified degrees of freedom.
	///
	/// - Parameters:
	///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
	public init(degreesOfFreedom: Int) {
		precondition(degreesOfFreedom > 0, "Degrees of freedom must be positive")
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
