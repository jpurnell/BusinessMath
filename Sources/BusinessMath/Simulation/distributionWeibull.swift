//
//  distributionWeibull.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Generates a random value from a Weibull distribution with the specified shape and scale parameters.
///
/// The Weibull distribution is a continuous probability distribution widely used in reliability
/// analysis and failure modeling. It is parameterized by a shape parameter (k) and a scale
/// parameter (λ).
///
/// ## Distribution Properties
///
/// - **Domain**: x ≥ 0
/// - **Mean**: λ × Γ(1 + 1/k)
/// - **Shape Parameter (k)**: Controls the failure rate behavior
///   - k < 1: Decreasing failure rate (infant mortality)
///   - k = 1: Constant failure rate (exponential distribution)
///   - k > 1: Increasing failure rate (wear-out failures)
/// - **Scale Parameter (λ)**: Stretches or compresses the distribution
///
/// ## Common Use Cases
///
/// - Equipment failure analysis
/// - Customer churn timing
/// - Time-to-event modeling
/// - Reliability engineering
/// - Wind speed distributions
///
/// ## Implementation
///
/// This function uses the inverse transform method:
/// If U ~ Uniform(0, 1), then X = λ × (-ln(1 - U))^(1/k) ~ Weibull(k, λ)
///
/// - Parameters:
///   - shape: The shape parameter k (k > 0)
///   - scale: The scale parameter λ (λ > 0)
/// - Returns: A random value sampled from the Weibull(k, λ) distribution
///
/// ## Example
///
/// ```swift
/// // Model equipment failure with increasing failure rate
/// let timeToFailure: Double = distributionWeibull(shape: 2.5, scale: 1000.0)
/// print("Equipment will fail after \(timeToFailure) hours")
///
/// // Model exponential failure (constant rate)
/// let constantRate: Double = distributionWeibull(shape: 1.0, scale: 500.0)
/// ```
public func distributionWeibull<T: Real>(shape: T, scale: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
	// Generate U ~ Uniform(0, 1)
	let u: T
	if let seed = seed {
		u = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		u = distributionUniform(min: T(0), max: T(1))
	}

	// Use inverse transform: X = scale × (-ln(1 - U))^(1/shape)
	let oneMinusU = T(1) - u
	let negativeLog = -T.log(oneMinusU)
	let exponent = T(1) / shape
	let result = scale * T.pow(negativeLog, exponent)

	return result
}

/// A type that represents a Weibull distribution.
///
/// The Weibull distribution is a flexible continuous probability distribution used extensively
/// in reliability analysis, failure modeling, and survival analysis.
///
/// ## Properties
///
/// - **shape**: Shape parameter k (k > 0)
///   - Controls the failure rate behavior
///   - k < 1: Infant mortality (decreasing failure rate)
///   - k = 1: Exponential distribution (constant failure rate)
///   - k > 1: Wear-out failures (increasing failure rate)
///   - k = 2: Similar to Rayleigh distribution
/// - **scale**: Scale parameter λ (λ > 0)
///   - Controls the spread of the distribution
///   - Higher values stretch the distribution
///
/// ## Mean
///
/// Mean = λ × Γ(1 + 1/k)
///
/// where Γ is the gamma function
///
/// ## Common Applications
///
/// - **Reliability Engineering**: Time until component failure
/// - **Customer Analytics**: Time until customer churn
/// - **Medical**: Survival time analysis
/// - **Weather**: Wind speed modeling
/// - **Manufacturing**: Product lifetime analysis
///
/// ## Example
///
/// ```swift
/// // Create a Weibull distribution for equipment reliability
/// // Shape = 2.5 indicates increasing failure rate (wear-out)
/// // Scale = 10000 hours is the characteristic life
/// let reliability = DistributionWeibull(shape: 2.5, scale: 10000.0)
///
/// // Generate time-to-failure samples
/// let failureTimes = (0..<100).map { _ in reliability.next() }
/// let averageLife = mean(failureTimes)
/// print("Average equipment life: \(averageLife) hours")
///
/// // Model constant failure rate (exponential)
/// let constantRate = DistributionWeibull(shape: 1.0, scale: 5000.0)
/// let mtbf = constantRate.random()  // Mean time between failures
/// ```
public struct DistributionWeibull: DistributionRandom, Sendable {
	/// The shape parameter k (k > 0)
	///
	/// Controls the failure rate behavior:
	/// - k < 1: Decreasing failure rate
	/// - k = 1: Constant failure rate
	/// - k > 1: Increasing failure rate
	let shape: Double

	/// The scale parameter λ (λ > 0)
	///
	/// Controls the spread of the distribution
	let scale: Double

	/// Creates a new instance of `DistributionWeibull` with the specified shape and scale parameters.
	///
	/// - Parameters:
	///   - shape: The shape parameter k (k > 0)
	///   - scale: The scale parameter λ (λ > 0)
	///
	/// - Precondition: Both shape and scale must be positive
	public init(shape: Double, scale: Double) {
		precondition(shape > 0, "Weibull distribution shape parameter must be positive")
		precondition(scale > 0, "Weibull distribution scale parameter must be positive")
		self.shape = shape
		self.scale = scale
	}

	/// Generates a random value from the Weibull distribution.
	///
	/// - Returns: A random value sampled from Weibull(k, λ), a non-negative value
	public func random() -> Double {
		return distributionWeibull(shape: shape, scale: scale)
	}

	/// Generates the next random value from the Weibull distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from Weibull(k, λ), a non-negative value
	public func next() -> Double {
		return random()
	}
}
