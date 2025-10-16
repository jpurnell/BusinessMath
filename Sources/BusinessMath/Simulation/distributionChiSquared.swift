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
public func distributionChiSquared<T: Real>(degreesOfFreedom: Int) -> T {
	precondition(degreesOfFreedom > 0, "Degrees of freedom must be positive")

	// Chi-squared(df) = Gamma(df/2, 2)
	let df = T(degreesOfFreedom)
	let shape = df / T(2)
	let scale = T(2)

	return gammaVariate(shape: shape, scale: scale)
}

/// Internal helper function to generate Gamma distributed random variables.
///
/// Uses Marsaglia and Tsang's method for shape >= 1, and shape transformation for shape < 1.
///
/// - Parameters:
///   - shape: The shape parameter (k > 0)
///   - scale: The scale parameter (θ > 0)
/// - Returns: A random value from Gamma(shape, scale)
private func gammaVariate<T: Real>(shape: T, scale: T) -> T {
	guard shape > T(0) && scale > T(0) else {
		fatalError("Gamma shape and scale must be positive")
	}

	// For shape < 1, use the transformation property
	if shape < T(1) {
		let u: T = distributionUniform(min: T(0), max: T(1))
		let x = gammaVariate(shape: shape + T(1), scale: scale)
		return x * T.pow(u, T(1) / shape)
	}

	// Marsaglia and Tsang's method for shape >= 1
	let oneThird: T = T(1) / T(3)
	let d = shape - oneThird
	let c = T(1) / T.sqrt(T(9) * d)

	while true {
		var x: T
		var v: T

		// Generate v = (1 + c×Z)³ where Z ~ N(0,1)
		repeat {
			x = distributionNormal(mean: T(0), stdDev: T(1))
			v = T(1) + c * x
		} while v <= T(0)

		v = v * v * v

		// Generate U ~ Uniform(0,1)
		let u: T = distributionUniform(min: T(0), max: T(1))

		// Acceptance test
		let x2 = x * x
		let x4 = x2 * x2
		let constant: T = T(331) / T(10000)  // 0.0331
		let threshold1 = T(1) - constant * x4
		if u < threshold1 {
			return d * v * scale
		}

		let logU = T.log(u)
		let logV = T.log(v)
		let half: T = T(1) / T(2)
		let term1 = half * x2
		let term2 = d * (T(1) - v + logV)
		let threshold2 = term1 + term2
		if logU < threshold2 {
			return d * v * scale
		}
	}
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
