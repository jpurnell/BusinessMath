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
///   - seed: Seed for a private ``DeterministicRNG``. The same seed and the same `df`
///     reproduce the same value exactly, no matter how many rejection iterations the
///     underlying gamma draw happens to need. `nil` (the default) draws from system
///     entropy and is non-reproducible by contract — use `seed:` or
///     ``distributionT(degreesOfFreedom:using:)`` when reproducibility matters.
/// - Returns: A random value sampled from the t(df) distribution
///
/// ## Example
///
/// ```swift
/// // Generate financial returns with fat tails
/// let returns: Double = distributionT(degreesOfFreedom: 5)
/// print("Daily return: \(returns)%")
///
/// // The same value on every run
/// let reproducible: Double = distributionT(degreesOfFreedom: 5, seed: 42)
/// ```
public func distributionT<T: Real>(degreesOfFreedom: Int, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionT(degreesOfFreedom: degreesOfFreedom, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionT(degreesOfFreedom: degreesOfFreedom, using: &generator)
}

/// Generates a Student's t variate, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``distributionT(degreesOfFreedom:seed:)``,
/// following the same convention as ``SeedableDistribution/next(using:)``: all randomness
/// comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on a single stream.
///
/// - Parameters:
///   - degreesOfFreedom: The degrees of freedom parameter (df > 0)
///   - generator: The random source. Advanced by two draws for the normal plus however
///     many the chi-squared rejection sampling needs — a data-dependent count, which is
///     precisely why a caller cannot supply a fixed array of uniforms instead.
/// - Returns: A random value sampled from the t(df) distribution
public func distributionT<T: Real, G: RandomNumberGenerator>(degreesOfFreedom: Int, using generator: inout G) -> T where T: BinaryFloatingPoint {
	guard degreesOfFreedom > 0 else {
		preconditionFailure("Degrees of freedom must be positive")
	}

	// Generate Z ~ N(0,1) - consumes 2 uniforms
	let u1Seed = Double.random(in: 0...1, using: &generator)
	let u2Seed = Double.random(in: 0...1, using: &generator)
	let z: T = distributionNormal(mean: T(0), stdDev: T(1), u1Seed, u2Seed)

	// Generate V ~ χ²(df) using the relationship χ²(df) = Gamma(df/2, 2)
	let df = T(degreesOfFreedom)
	let shape = df / T(2) // fp-safety:disable — constant T(2)
	let scale = T(2)
	let v = gammaVariate(shape: shape, scale: scale, using: &generator)

	// T = Z / √(V/df)
	let denominator = T.sqrt(v / df) // fp-safety:disable — df > 0 guarded above
	guard denominator > T(0) else { return z }
	return z / denominator // fp-safety:disable — guarded by denominator > 0 above
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
		guard degreesOfFreedom > 0 else {
			preconditionFailure("Degrees of freedom must be positive")
		}
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

extension DistributionT: SeedableDistribution {
	/// Generates the next random value, drawing all randomness from `generator`.
	///
	/// Follows the same probability law as ``next()`` — T = Z / √(V/df) where Z ~ N(0,1)
	/// via Box-Muller and V ~ χ²(df) built as Gamma(df/2, 2) via Marsaglia-Tsang —
	/// sourcing every uniform draw from `generator`; a seeded generator makes the stream
	/// fully reproducible.
	///
	/// - Parameter generator: The random source for every uniform draw.
	/// - Returns: A random Double sampled from t(df)
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionT(degreesOfFreedom: degreesOfFreedom, using: &generator)
	}
}
