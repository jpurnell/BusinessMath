//
//  distributionPareto.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Generates a random value from a Pareto distribution with the specified scale and shape parameters.
///
/// The Pareto distribution is a power-law probability distribution that models phenomena where
/// a small number of items account for a large portion of the total (the "80/20 rule" or Pareto principle).
/// It is characterized by heavy tails and is used to model income distribution, wealth inequality,
/// and other scenarios with extreme inequality.
///
/// ## Distribution Properties
///
/// - **Domain**: [scale, +∞)
/// - **Mean**: (α×xₘ)/(α-1) for α > 1, undefined otherwise
/// - **Variance**: (xₘ²×α)/((α-1)²(α-2)) for α > 2, undefined otherwise
/// - **Median**: xₘ × 2^(1/α)
///
/// ## Key Characteristics
///
/// - Heavy-tailed distribution (produces extreme outliers)
/// - Power-law behavior: P(X > x) ∝ x^(-α)
/// - Lower shape parameter α means higher inequality
/// - Models "80/20 rule" and similar phenomena
///
/// ## Common Use Cases
///
/// - Wealth and income distribution
/// - Sales concentration (top customers, products)
/// - City population sizes
/// - File size distribution on servers
/// - Natural resource reserves
/// - Social network connection counts
///
/// ## Implementation
///
/// This function uses the inverse transform method:
/// If U ~ Uniform(0,1), then X = xₘ / U^(1/α) ~ Pareto(xₘ, α)
///
/// - Parameters:
///   - scale: The scale parameter xₘ (minimum value, xₘ > 0)
///   - shape: The shape parameter α (α > 0, controls inequality)
///   - seed: Optional seed for reproducibility
/// - Returns: A random value sampled from the Pareto(xₘ, α) distribution
///
/// ## Example
///
/// ```swift
/// // Model wealth distribution (80/20 rule)
/// let wealth: Double = distributionPareto(scale: 10000, shape: 1.5)
/// print("Wealth: $\(wealth)")
///
/// // Model top customer sales (high concentration)
/// let sales: Double = distributionPareto(scale: 1000, shape: 2.0)
/// print("Customer value: $\(sales)")
/// ```
public func distributionPareto<T: Real>(scale: T, shape: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	precondition(scale > T(0), "Pareto scale parameter must be positive")
	precondition(shape > T(0), "Pareto shape parameter must be positive")

	// Use inverse transform method: X = xₘ / U^(1/α)
	// where U ~ Uniform(0,1)
	let u: T
	if let seed = seed {
		u = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		u = distributionUniform(min: T(0), max: T(1))
	}

	// Avoid division by very small numbers
	let epsilon: T = T(Int(1e-10))  // 1e-10
	let adjustedU = u > epsilon ? u : epsilon

	return scale / T.pow(adjustedU, T(1) / shape)
}

/// A type that represents a Pareto distribution.
///
/// The Pareto distribution is a continuous probability distribution characterized by
/// power-law behavior and heavy tails. It is widely used to model scenarios with
/// extreme inequality, such as wealth distribution and sales concentration.
///
/// ## Properties
///
/// - **scale**: The scale parameter xₘ (minimum value, xₘ > 0)
/// - **shape**: The shape parameter α (α > 0, lower means more inequality)
/// - **Mean**: (α×xₘ)/(α-1) for α > 1
///
/// ## Distribution Behavior
///
/// - **Low α (1-2)**: Extreme inequality, very heavy tails (80/20 rule)
/// - **Medium α (2-4)**: Moderate inequality
/// - **High α (>4)**: Less inequality, more concentrated near minimum
///
/// ## Example
///
/// ```swift
/// // Create a distribution for wealth inequality (80/20 rule)
/// let wealth = DistributionPareto(scale: 10000, shape: 1.5)
/// let income = wealth.random()
/// print("Annual income: $\(income)")
///
/// // Create a distribution for customer lifetime value
/// let customerValue = DistributionPareto(scale: 100, shape: 2.0)
/// let value = customerValue.next()
/// print("Customer LTV: $\(value)")
/// ```
public struct DistributionPareto: DistributionRandom {
	/// The scale parameter xₘ (minimum value, xₘ > 0)
	let scale: Double

	/// The shape parameter α (α > 0, controls inequality)
	let shape: Double

	/// Creates a new instance of `DistributionPareto` with the specified scale and shape parameters.
	///
	/// - Parameters:
	///   - scale: The scale parameter xₘ (minimum value, xₘ > 0)
	///   - shape: The shape parameter α (α > 0)
	public init(scale: Double, shape: Double) {
		precondition(scale > 0, "Pareto scale parameter must be positive")
		precondition(shape > 0, "Pareto shape parameter must be positive")
		self.scale = scale
		self.shape = shape
	}

	/// Generates a random value from the Pareto distribution.
	///
	/// - Returns: A random value sampled from Pareto(xₘ, α), always >= scale
	public func random() -> Double {
		return distributionPareto(scale: scale, shape: shape)
	}

	/// Generates the next random value from the Pareto distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from Pareto(xₘ, α), always >= scale
	public func next() -> Double {
		return random()
	}
}
