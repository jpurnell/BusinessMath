//
//  distributionBeta.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Generates a random value from a Beta distribution with the specified shape parameters.
///
/// The Beta distribution is a continuous probability distribution defined on the interval [0, 1].
/// It is parameterized by two positive shape parameters, alpha (α) and beta (β), which control
/// the shape of the distribution.
///
/// ## Distribution Properties
///
/// - **Domain**: [0, 1]
/// - **Mean**: α / (α + β)
/// - **Mode**: (α - 1) / (α + β - 2) when α > 1 and β > 1
/// - **Variance**: (α × β) / [(α + β)² × (α + β + 1)]
///
/// ## Common Use Cases
///
/// - Project completion percentages
/// - Market share modeling
/// - Success rates and probabilities
/// - Bayesian analysis (as a conjugate prior for Bernoulli/Binomial distributions)
///
/// ## Implementation
///
/// This function uses the relationship between Beta and Gamma distributions:
/// If X ~ Gamma(α, 1) and Y ~ Gamma(β, 1), then X/(X + Y) ~ Beta(α, β)
///
/// - Parameters:
///   - alpha: The first shape parameter (α > 0)
///   - beta: The second shape parameter (β > 0)
///   - seed: Seed for a private ``DeterministicRNG``. The same seed with the same α and β
///     reproduces the same value exactly. `nil` (the default) draws from system entropy
///     and is non-reproducible by contract — use `seed:` or
///     ``distributionBeta(alpha:beta:using:)`` when reproducibility matters.
/// - Returns: A random value sampled from the Beta(α, β) distribution
///
/// ## Example
///
/// ```swift
/// // Generate project completion percentage (skewed toward completion)
/// let completion: Double = distributionBeta(alpha: 8.0, beta: 2.0)
/// print("Project is \(completion * 100)% complete")
///
/// // The same value on every run
/// let reproducible: Double = distributionBeta(alpha: 8.0, beta: 2.0, seed: 42)
/// ```
public func distributionBeta<T: Real>(alpha: T, beta: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionBeta(alpha: alpha, beta: beta, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionBeta(alpha: alpha, beta: beta, using: &generator)
}

/// Generates a Beta variate, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``distributionBeta(alpha:beta:seed:)``, following
/// the same convention as ``SeedableDistribution/next(using:)``: all randomness comes
/// from the caller's generator, so the caller owns reproducibility and can interleave
/// this draw with others on a single stream.
///
/// The two gamma variates are drawn in sequence from the one stream. The array form this
/// replaced split a fixed `[Double]` down the middle and handed half to each — so neither
/// gamma got a stream it could finish, and at α = β = 0.5 the draw silently left the
/// supplied uniforms on 5.1% of calls.
///
/// - Parameters:
///   - alpha: The first shape parameter (α > 0)
///   - beta: The second shape parameter (β > 0)
///   - generator: The random source. Advanced by a data-dependent number of draws.
/// - Returns: A random value sampled from the Beta(α, β) distribution, in [0, 1]
public func distributionBeta<T: Real, G: RandomNumberGenerator>(alpha: T, beta: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	// Special case: Beta(1, 1) is Uniform(0, 1)
	if alpha == T(1) && beta == T(1) {
		return distributionUniform(min: T(0), max: T(1), Double.random(in: 0...1, using: &generator))
	}

	// Use the Beta-Gamma relationship: X/(X+Y) where X~Gamma(α,1), Y~Gamma(β,1)
	let x = gammaVariate(shape: alpha, scale: T(1), using: &generator)
	let y = gammaVariate(shape: beta, scale: T(1), using: &generator)

	let total = x + y
	guard total > T(0) else {
		// Degenerate underflow (measure zero for valid α, β): fall back to the distribution mean
		return alpha / (alpha + beta) // fp-safety:disable — alpha and beta are positive
	}
	return x / total // fp-safety:disable — guarded by total > 0 above
}

/// A type that represents a Beta distribution.
///
/// The Beta distribution is a continuous probability distribution defined on [0, 1],
/// parameterized by two positive shape parameters alpha (α) and beta (β).
///
/// ## Properties
///
/// - **alpha**: First shape parameter (α > 0)
/// - **beta**: Second shape parameter (β > 0)
/// - **Mean**: α / (α + β)
///
/// ## Distribution Shapes
///
/// - α = β: Symmetric around 0.5
/// - α > β: Right-skewed (higher values more likely)
/// - α < β: Left-skewed (lower values more likely)
/// - α = β = 1: Uniform distribution
/// - α, β < 1: U-shaped distribution
/// - α, β > 1: Unimodal distribution
///
/// ## Example
///
/// ```swift
/// // Create a distribution for project completion (skewed toward high completion)
/// let completion = DistributionBeta(alpha: 8.0, beta: 2.0)
/// let percentage = completion.random() * 100
/// print("Project is \(percentage)% complete")
///
/// // Create a symmetric distribution
/// let symmetric = DistributionBeta(alpha: 5.0, beta: 5.0)
/// let value = symmetric.next()
/// ```
public struct DistributionBeta: DistributionRandom, Sendable {
	/// The first shape parameter (α > 0)
	let alpha: Double

	/// The second shape parameter (β > 0)
	let beta: Double

	/// Creates a new instance of `DistributionBeta` with the specified shape parameters.
	///
	/// - Parameters:
	///   - alpha: The first shape parameter (α > 0)
	///   - beta: The second shape parameter (β > 0)
	public init(alpha: Double, beta: Double) {
		guard alpha > 0 else {
			preconditionFailure("Beta distribution alpha parameter must be positive")
		}
		guard beta > 0 else {
			preconditionFailure("Beta distribution beta parameter must be positive")
		}
		self.alpha = alpha
		self.beta = beta
	}

	/// Generates a random value from the Beta distribution.
	///
	/// - Returns: A random value sampled from Beta(α, β), in the range [0, 1]
	public func random() -> Double {
		return distributionBeta(alpha: alpha, beta: beta)
	}

	/// Generates the next random value from the Beta distribution.
	///
	/// This is an alias for `random()` to conform to the `DistributionRandom` protocol.
	///
	/// - Returns: The next random value sampled from Beta(α, β), in the range [0, 1]
	public func next() -> Double {
		return random()
	}
}

extension DistributionBeta: SeedableDistribution {
	/// Generates the next random value, drawing all randomness from `generator`.
	///
	/// Follows the same probability law as ``next()`` — the Beta-Gamma relationship
	/// X/(X+Y) where X ~ Gamma(α, 1) and Y ~ Gamma(β, 1), with Beta(1, 1) reducing to
	/// Uniform(0, 1) — sourcing every uniform draw from `generator`; a seeded generator
	/// makes the stream fully reproducible.
	///
	/// - Parameter generator: The random source for every uniform draw.
	/// - Returns: A random Double sampled from Beta(α, β), in the range [0, 1]
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionBeta(alpha: alpha, beta: beta, using: &generator)
	}
}

extension DistributionBeta: ContinuousDistribution {
	/// P(X ≤ x) = I_x(α, β), the regularized incomplete beta.
	public func cdf(_ x: Double) -> Double {
		totalizedResult { try regularizedIncompleteBeta(x: x, a: alpha, b: beta) }
	}

	/// The value at which the CDF equals `p`.
	///
	/// Root-found, through ``inverseRegularizedIncompleteBeta(p:a:b:)``.
	public func quantile(_ p: Double) -> Double {
		totalizedResult { try inverseRegularizedIncompleteBeta(p: p, a: alpha, b: beta) }
	}

	// Keeps its own `next(using:)`: a ratio of two gamma variates, each of which is
	// itself rejection-sampled.
}
