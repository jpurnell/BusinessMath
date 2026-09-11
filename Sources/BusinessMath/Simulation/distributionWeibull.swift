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
///   - u: The probability at which to evaluate the quantile, in `[0, 1]`. Not a stream
///     seed — see ``distributionWeibull(shape:scale:seed:)`` for that.
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
public func distributionWeibull<T: Real>(shape: T, scale: T, quantileAt u: Double) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard shape > T(0), !shape.isNaN, shape.isFinite else { return T.nan }
	guard scale > T(0), !scale.isNaN, scale.isFinite else { return T.nan }

	let scaled: T = distributionUniform(min: T(0), max: T(1), u)

	// Use inverse transform: X = scale × (-ln(1 - U))^(1/shape)
	let oneMinusU = T(1) - scaled
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
		guard shape > 0 else {
			preconditionFailure("Weibull distribution shape parameter must be positive")
		}
		guard scale > 0 else {
			preconditionFailure("Weibull distribution scale parameter must be positive")
		}
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

extension DistributionWeibull: SeedableDistribution {
	/// Generates the next random value, drawing the inverse-transform uniform from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the single uniform draw.
	/// - Returns: A random value sampled from Weibull(k, λ), a non-negative value
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionWeibull(shape: shape, scale: scale, using: &generator)
	}
}


extension DistributionWeibull: ContinuousDistribution {
	/// P(X ≤ x) = 1 − exp(−(x/scale)^shape).
	public func cdf(_ x: Double) -> Double {
		guard shape > 0, scale > 0 else { return Double.nan }
		guard x > 0 else { return 0 }
		let ratio = x / scale
		let raised = Double.pow(ratio, shape)
		// expMinusOne, not `1 - exp`: see ``exponentialCDF(_:λ:)``.
		return -Double.expMinusOne(-raised)
	}

	/// The value at which the CDF equals `p`: scale · (−ln(1 − p))^(1/shape).
	public func quantile(_ p: Double) -> Double {
		guard shape > 0, scale > 0 else { return Double.nan }
		guard p < 1 else { return Double.infinity }
		// log(onePlus: -p), not log(1 - p): for small p the subtraction rounds the
		// argument to 1 and the log to zero.
		let negativeLog = -Double.log(onePlus: -p)
		let exponent = 1 / shape
		return scale * Double.pow(negativeLog, exponent)
	}
}


// MARK: - Seeded and generator-driven draws

/// A draw from the Weibull distribution, reproducible from `seed`.
///
/// The sampler, as distinct from ``distributionWeibull(shape:scale:quantileAt:)``, which is the quantile function and
/// evaluates it at a point you supply. This one chooses the point.
///
/// `seed:` means the same thing here as on every other sampler in this library — a `UInt64`
/// naming a stream, not a uniform in `(0, 1)`. It used to mean the second, which put the
/// inverse-transform families in a different seeding regime from the rejection-based ones and
/// left `seed:` meaning two different things across one API.
///
/// - Parameters:
///   - shape: The shape parameter.
///   - scale: The scale parameter.
///   - seed: The stream to draw from, or `nil` to draw unseeded.
/// - Returns: A value distributed as Weibull.
public func distributionWeibull<T: Real>(shape: T, scale: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionWeibull(shape: shape, scale: scale, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionWeibull(shape: shape, scale: scale, using: &generator)
}

/// A draw from the Weibull distribution, taking its uniform from `generator`.
///
/// All randomness comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on one stream.
///
/// The uniform is drawn on the **open** interval. This family's quantile takes a logarithm or a
/// reciprocal, so an endpoint would turn a legal uniform into a non-finite variate — rarely
/// enough to survive testing and often enough to reach production.
///
/// - Parameters:
///   - shape: The shape parameter.
///   - scale: The scale parameter.
///   - generator: The random source. Advanced by exactly one draw.
/// - Returns: A value distributed as Weibull.
public func distributionWeibull<T: Real, G: RandomNumberGenerator>(shape: T, scale: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	let u: Double = openUnitUniform(Double.self, using: &generator)
	return distributionWeibull(shape: shape, scale: scale, quantileAt: u)
}
