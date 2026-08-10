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
/// If U ~ Uniform(0, 1], then X = xₘ / U^(1/α) ~ Pareto(xₘ, α)
///
/// The interval is half-open at zero on purpose. `u = 0` is the pole of the transform
/// and returns `+infinity`; a seed of zero, and every seed below the 1e-7 quantum of
/// ``distributionUniform(min:max:_:)``, reaches it. Only that single point is remapped,
/// to `u = 1`, so the result is always finite and always at least `scale`. See
/// `openUnitUniform(seed:)` in `boxMuellerSeed.swift` for why this is a remap and not
/// a clamp.
///
/// - Parameters:
///   - scale: The scale parameter xₘ (minimum value, xₘ > 0)
///   - shape: The shape parameter α (α > 0, controls inequality)
///   - seed: Optional seed for reproducibility, a uniform on `[0, 1]`
/// - Returns: A random value sampled from the Pareto(xₘ, α) distribution, always
///   finite and always `>= scale`
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
	// Validate parameters - return NaN for invalid inputs
	guard scale > T(0), !scale.isNaN, scale.isFinite else { return T.nan }
	guard shape > T(0), !shape.isNaN, shape.isFinite else { return T.nan }

	// Use inverse transform method: X = xₘ / U^(1/α)
	// where U ~ Uniform(0, 1]
	let drawn: T
	if let seed = seed {
		drawn = distributionUniform(min: T(0), max: T(1), seed)
	} else {
		drawn = distributionUniform(min: T(0), max: T(1))
	}

	// `u = 0` is the pole of this transform: `0^(1/α)` is zero and the variate is
	// `+infinity`, which poisons the mean, the variance and every percentile above it
	// in whatever Monte Carlo run the draw lands in. It is not a rare accident —
	// `distributionUniform` quantizes to multiples of 1e-7, so every seed below the
	// quantum arrives here as exactly zero.
	//
	// This used to try to clamp, with `let epsilon: T = T(Int(1e-10))`. `Int(1e-10)` is
	// **0**, so the guard read `u > 0` and did nothing whatsoever. Repairing the
	// constant would have been the wrong fix anyway: a clamp maps a whole interval of
	// draws onto one value and leaves a point mass at `scale·ε^(-1/α)` — at α = 3 and
	// ε = 1e-10, an atom sitting alone at 2154·xₘ. Drawing on (0, 1] instead moves only
	// the single point `u = 0`, to 1, which is a set of measure zero mapped onto
	// another. The same rule the Box-Muller sites settled on; see `git show d247691`.
	let u = openUnitUniform(seed: drawn)

	return scale / T.pow(u, T(1) / shape)
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
		guard scale > 0 else {
			preconditionFailure("Pareto scale parameter must be positive")
		}
		guard shape > 0 else {
			preconditionFailure("Pareto shape parameter must be positive")
		}
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

extension DistributionPareto: SeedableDistribution {
	/// Generates the next random value, drawing the inverse-transform uniform from `generator`.
	///
	/// Follows the same probability law as ``next()``; a seeded generator makes the
	/// stream fully reproducible.
	///
	/// - Parameter generator: The random source for the single uniform draw.
	/// - Returns: A random value sampled from Pareto(xₘ, α), always >= scale
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return distributionPareto(scale: scale, shape: shape,
								  seed: Double.random(in: 0...1, using: &generator))
	}
}
