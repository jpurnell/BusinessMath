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
///   - seeds: Optional seeds for reproducibility
/// - Returns: A random value sampled from the Beta(α, β) distribution
///
/// ## Example
///
/// ```swift
/// // Generate project completion percentage (skewed toward completion)
/// let completion: Double = distributionBeta(alpha: 8.0, beta: 2.0)
/// print("Project is \(completion * 100)% complete")
///
/// // Generate symmetric distribution around 0.5
/// let symmetric: Double = distributionBeta(alpha: 5.0, beta: 5.0)
/// ```
public func distributionBeta<T: Real>(alpha: T, beta: T, seeds: [Double]? = nil) -> T where T: BinaryFloatingPoint {
	// Special case: Beta(1, 1) is Uniform(0, 1)
	if alpha == T(1) && beta == T(1) {
		if let seeds = seeds, !seeds.isEmpty {
			return distributionUniform(min: T(0), max: T(1), seeds[0])
		}
		return distributionUniform(min: T(0), max: T(1))
	}

	// Use the Beta-Gamma relationship: X/(X+Y) where X~Gamma(α,1), Y~Gamma(β,1)
	// Split seeds: first half for X, second half for Y
	var seedIndexX = 0
	var seedIndexY = 0
	let xSeeds: [Double]?
	let ySeeds: [Double]?

	if let seeds = seeds {
		let midpoint = seeds.count / 2
		xSeeds = Array(seeds[0..<midpoint])
		ySeeds = Array(seeds[midpoint..<seeds.count])
	} else {
		xSeeds = nil
		ySeeds = nil
	}

	let x = gammaVariate(shape: alpha, scale: T(1), seeds: xSeeds, seedIndex: &seedIndexX)
	let y = gammaVariate(shape: beta, scale: T(1), seeds: ySeeds, seedIndex: &seedIndexY)

	return x / (x + y)
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
public struct DistributionBeta: DistributionRandom {
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
		precondition(alpha > 0, "Beta distribution alpha parameter must be positive")
		precondition(beta > 0, "Beta distribution beta parameter must be positive")
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
