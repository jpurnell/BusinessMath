//
//  distributionT.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Generates a random value from a Student's t-distribution with the specified degrees of freedom.
///
/// The Student's t-distribution is a continuous probability distribution that arises when estimating
/// the mean of a normally distributed population in situations where the sample size is small and
/// the population standard deviation is unknown.
///
/// ## Distribution Properties
///
/// - **Domain**: (-∞, +∞)
/// - **Mean**: 0 (for df > 1), undefined for df ≤ 1
/// - **Variance**: df/(df-2) for df > 2, infinite for 1 < df ≤ 2, undefined for df ≤ 1
/// - **Mode**: 0 (symmetric around zero)
///
/// ## Key Characteristics
///
/// - Symmetric and bell-shaped like the normal distribution
/// - Heavier tails than the normal distribution (more prone to extreme values)
/// - As degrees of freedom increase, approaches the standard normal distribution
/// - With df=1, equivalent to the Cauchy distribution (undefined mean and variance)
///
/// ## Common Use Cases
///
/// - Modeling financial returns with fat tails (extreme events)
/// - Small sample statistical inference
/// - Confidence intervals when population variance is unknown
/// - Hypothesis testing with small samples
/// - Robust alternatives to normal distributions
///
/// ## Implementation
///
/// This function uses the relationship between t-distribution, normal, and chi-squared:
/// If Z ~ N(0,1) and V ~ χ²(df), then T = Z / √(V/df) ~ t(df)
///
/// The chi-squared distribution is generated using the relationship:
/// χ²(df) = Gamma(df/2, 2)
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
/// - Returns: A random value sampled from the t(df) distribution
///
/// ## Example
///
/// ```swift
/// // Generate financial returns with fat tails
/// let returns: Double = distributionT(degreesOfFreedom: 5)
/// print("Daily return: \(returns)%")
///
/// // Generate values close to standard normal (high df)
/// let nearNormal: Double = distributionT(degreesOfFreedom: 30)
/// ```
public func distributionT<T: Real>(degreesOfFreedom: Int, seeds: [Double]? = nil) -> T where T: BinaryFloatingPoint {
	precondition(degreesOfFreedom > 0, "Degrees of freedom must be positive")

	var seedIndex = 0

	// Helper to get next seed
	func nextSeed() -> Double {
		if let seeds = seeds, seedIndex < seeds.count {
			let seed = seeds[seedIndex]
			seedIndex += 1
			return seed
		}
		return Double.random(in: 0...1)
	}

	// Generate Z ~ N(0,1) - needs 2 seeds
	let u1Seed = nextSeed()
	let u2Seed = nextSeed()
	let z: T = distributionNormal(mean: T(0), stdDev: T(1), u1Seed, u2Seed)

	// Generate V ~ χ²(df) using the relationship χ²(df) = Gamma(df/2, 2)
	let df = T(degreesOfFreedom)
	let shape = df / T(2)
	let scale = T(2)
	let v = gammaVariate(shape: shape, scale: scale, seeds: seeds, seedIndex: &seedIndex)

	// T = Z / √(V/df)
	let denominator = T.sqrt(v / df)
	return z / denominator
}

/// A type that represents a Student's t-distribution.
///
/// The Student's t-distribution is a continuous probability distribution that is symmetric
/// and bell-shaped, but with heavier tails than the normal distribution, making it useful
/// for modeling data with outliers or extreme values.
///
/// ## Properties
///
/// - **degreesOfFreedom**: The degrees of freedom parameter (df > 0)
/// - **Mean**: 0 (for df > 1)
/// - **Variance**: df/(df-2) for df > 2
///
/// ## Distribution Behavior
///
/// - **Low df (1-5)**: Heavy tails, prone to extreme values
/// - **Medium df (5-30)**: Moderate tails, suitable for small samples
/// - **High df (>30)**: Approaches standard normal distribution
///
/// ## Example
///
/// ```swift
/// // Create a distribution for financial returns with moderate fat tails
/// let returns = DistributionT(degreesOfFreedom: 5)
/// let dailyReturn = returns.random()
/// print("Daily return: \(dailyReturn)%")
///
/// // Create a distribution close to normal
/// let nearNormal = DistributionT(degreesOfFreedom: 30)
/// let value = nearNormal.next()
/// ```
public struct DistributionT: DistributionRandom {
	/// The degrees of freedom parameter (df > 0)
	let degreesOfFreedom: Int

	/// Creates a new instance of `DistributionT` with the specified degrees of freedom.
	///
	/// - Parameters:
	///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
	public init(degreesOfFreedom: Int) {
		precondition(degreesOfFreedom > 0, "Degrees of freedom must be positive")
		self.degreesOfFreedom = degreesOfFreedom
	}

	/// Generates a random value from the t-distribution.
	///
	/// - Returns: A random value sampled from t(df)
	public func random() -> Double {
		return distributionT(degreesOfFreedom: degreesOfFreedom)
	}

	/// Generates the next random value from the t-distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from t(df)
	public func next() -> Double {
		return random()
	}
}
