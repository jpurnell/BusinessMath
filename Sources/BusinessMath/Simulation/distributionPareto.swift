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
///   - u: The probability at which to evaluate the quantile, in `[0, 1]`. Not a stream
///     seed — see ``distributionPareto(scale:shape:seed:)`` for that.
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
public func distributionPareto<T: Real>(scale: T, shape: T, quantileAt u: Double) -> T where T: BinaryFloatingPoint {
	// Validate parameters - return NaN for invalid inputs
	guard scale > T(0), !scale.isNaN, scale.isFinite else { return T.nan }
	guard shape > T(0), !shape.isNaN, shape.isFinite else { return T.nan }

	// The quantile: xₘ/(1 − u)^(1/α), which is exactly ``DistributionPareto/quantile(_:)``.
	//
	// It used to be xₘ/u^(1/α), which is the same distribution read from the other end —
	// *decreasing* in its argument, where the type's `quantile(_:)` increases. Two
	// implementations of one function disagreeing about direction, and nothing compared them:
	// the only point both were ever tested at was u = 0.5, where `u` and `1 − u` are the same
	// number. Folding once here makes the identity true, and costs nothing distributionally.
	//
	// The pole moves with the fold, from u = 0 to u = 1, and stops being a hazard on the way.
	// At u = 1 the quantile of a Pareto genuinely is `+infinity`, which is what the type
	// returns, so the answer is right rather than merely finite.
	//
	// Worth keeping the history of the old pole, because the lesson outlived it. `u = 0` sent
	// `0^(1/α)` to zero and the variate to `+infinity`, poisoning the mean, the variance and
	// every percentile above it in whatever Monte Carlo run the draw landed in — and not
	// rarely, since `distributionUniform` quantizes to multiples of 1e-7 and every seed below
	// the quantum arrived as exactly zero. The attempted clamp was
	// `let epsilon: T = T(Int(1e-10))`, and `Int(1e-10)` is **0**, so the guard read `u > 0`
	// and did nothing at all. Repairing the constant would have been the wrong fix regardless:
	// a clamp maps an interval of draws onto one value and leaves a point mass — at α = 3 and
	// ε = 1e-10, an atom sitting alone at 2154·xₘ. See `git show d247691`.
	guard u < 1 else { return T.infinity }
	let logComplement: T = T.log(onePlus: -T(u))
	let exponent: T = -logComplement / shape
	return scale * T.exp(exponent)
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
public struct DistributionPareto: DistributionRandom, Sendable {
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
		return distributionPareto(scale: scale, shape: shape, using: &generator)
	}
}


extension DistributionPareto: ContinuousDistribution {
	/// P(X ≤ x) = 1 − (scale/x)^shape, zero below `scale`.
	///
	/// `scale` is the minimum of the support — Pareto's *x*ₘ — and `shape` is the
	/// tail index α.
	public func cdf(_ x: Double) -> Double {
		guard scale > 0, shape > 0 else { return Double.nan }
		guard x > scale else { return 0 }
		// Just above the lower bound the power is within an ulp of 1, so the same
		// cancellation applies as in ``exponentialCDF(_:λ:)``. Going through the log
		// keeps the digits: 1 − r^s = −expMinusOne(s·ln r).
		// (x − scale)/scale is exact for x near scale, where scale/x is not: the
		// ratio lands within an ulp of 1 and takes the answer's digits with it.
		let relative = (x - scale) / scale
		let exponent = -shape * Double.log(onePlus: relative)
		return -Double.expMinusOne(exponent)
	}

	/// The value at which the CDF equals `p`: scale / (1 − p)^(1/shape).
	public func quantile(_ p: Double) -> Double {
		guard scale > 0, shape > 0 else { return Double.nan }
		guard p < 1 else { return Double.infinity }
		let logComplement = Double.log(onePlus: -p)
		return scale * Double.exp(-logComplement / shape)
	}
}


// MARK: - Seeded and generator-driven draws

/// A draw from the Pareto distribution, reproducible from `seed`.
///
/// The sampler, as distinct from ``distributionPareto(scale:shape:quantileAt:)``, which is the quantile function and
/// evaluates it at a point you supply. This one chooses the point.
///
/// `seed:` means the same thing here as on every other sampler in this library — a `UInt64`
/// naming a stream, not a uniform in `(0, 1)`. It used to mean the second, which put the
/// inverse-transform families in a different seeding regime from the rejection-based ones and
/// left `seed:` meaning two different things across one API.
///
/// - Parameters:
///   - scale: The scale parameter (xₘ).
///   - shape: The shape parameter (α).
///   - seed: The stream to draw from, or `nil` to draw unseeded.
/// - Returns: A value distributed as Pareto.
public func distributionPareto<T: Real>(scale: T, shape: T, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return distributionPareto(scale: scale, shape: shape, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return distributionPareto(scale: scale, shape: shape, using: &generator)
}

/// A draw from the Pareto distribution, taking its uniform from `generator`.
///
/// All randomness comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on one stream.
///
/// The uniform is drawn on the **open** interval. This family's quantile takes a logarithm or a
/// reciprocal, so an endpoint would turn a legal uniform into a non-finite variate — rarely
/// enough to survive testing and often enough to reach production.
///
/// - Parameters:
///   - scale: The scale parameter (xₘ).
///   - shape: The shape parameter (α).
///   - generator: The random source. Advanced by exactly one draw.
/// - Returns: A value distributed as Pareto.
public func distributionPareto<T: Real, G: RandomNumberGenerator>(scale: T, shape: T, using generator: inout G) -> T where T: BinaryFloatingPoint {
	let u: Double = openUnitUniform(Double.self, using: &generator)
	return distributionPareto(scale: scale, shape: shape, quantileAt: u)
}
