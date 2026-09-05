//
//  DistributionRayleigh.swift
//  BusinessMath
//
//  Created by Justin Purnell on 8/25/25.
//

import Foundation
import Numerics

/// Generates a random value from a Rayleigh distribution with the specified scale.
///
/// The Rayleigh distribution is a continuous probability distribution for non-negative-valued random variables.
///
/// ## Distribution properties
///
/// - **Domain**: x ≥ 0
/// - **Mean**: σ√(π/2) ≈ 1.2533σ
/// - **Variance**: (4−π)/2·σ² ≈ 0.4292σ²
/// - **Mode**: σ
/// - **Median**: σ√(2 ln 2) ≈ 1.1774σ
///
/// - Parameter scale: The scale parameter σ (σ > 0). This is *not* the mean; the mean
///   is `σ√(π/2)`. To sample a Rayleigh with a target mean `m`, pass
///   `scale: m / (π/2).squareRoot()`, i.e. `m / 1.2533141373155003`.
/// - Parameter seed: Optional seed for reproducibility, a uniform on `[0, 1]`.
/// - Returns: A random value sampled from the Rayleigh(σ) distribution.
///
/// - Note: A Rayleigh variate is the *radius* of the Box-Muller transform, so this
///   is ``boxMullerRadius(_:)`` scaled by `scale`. Routing through the shared radius
///   rather than the shared pair matters: the pair would consume a second uniform
///   and compute a sine and a cosine only to discard them.
///
/// - Note: This parameter was called `mean:` and documented as the mean until the
///   arithmetic was checked against it. It never was: `σ · boxMullerRadius()` has mean
///   `σ√(π/2)`, so a caller asking for a mean of 2 measured 2.5039 over 400,000 draws —
///   a 25.2% overshoot. Two repairs were available, and both break callers. Dividing by
///   √(π/2) would have kept the label and changed every existing caller's numbers
///   *silently*, since the code would still compile. Renaming changes no number and
///   fails the build instead, which is the break that gets looked at. It also puts
///   Rayleigh where it belongs in this library's naming: the scale families —
///   ``distributionWeibull(shape:scale:seed:)``, of which Rayleigh is the k = 2 case,
///   and ``distributionPareto(scale:shape:seed:)`` — take `scale:`, while `mean:`
///   is reserved for the location families where the parameter genuinely is the mean
///   (``distributionNormal(mean:stdDev:_:_:)``, ``distributionLogistic(_:_:seed:)``).
///   Rayleigh has no location parameter at all. The package's own Rayleigh tests had
///   already reached this conclusion on their own — they name the argument `scale` and
///   `σ` and assert `mean ≈ σ√(π/2)` — so only the label and the prose were wrong.
public func distributionRayleigh<T: Real>(scale: T, seed: Double? = nil) -> T where T: BinaryFloatingPoint {
    // Validate parameters - return NaN for invalid inputs
    guard scale > T(0), !scale.isNaN, scale.isFinite else { return T.nan }

    // Two things this used to do for itself and no longer needs to.
    //
    // It ran the seed through `distributionUniform`, which quantizes to multiples
    // of 1e-7. That is what made the `log(0)` pole a real event rather than a
    // vanishing one: every seed below 1e-7 — one draw in ten million — landed on
    // exactly zero and returned `+infinity`. Seeds now reach the transform at full
    // precision, so a seed of 1e-9 is the legitimate 6.07-sigma radius it should
    // always have been, and only an exact zero is degenerate.
    //
    // And it folded the uniform as `1 - u`, which was the right guard for a
    // quantized [0, 1] with a fat atom at the bottom. With the quantization gone
    // the shared rule applies instead: only the single point `u = 0` moves, to 1,
    // which is a set of measure zero mapped onto another. The seeded *values*
    // change because a seed now indexes the distribution the other way round; the
    // distribution itself is identical.
    if let seed {
    	return scale * boxMullerRadius(seed)
    }
    return scale * boxMullerRadius()
}

/// A type that represents a Rayleigh distribution.
///
/// The Rayleigh distribution is a continuous probability distribution for non-negative-valued random variables.
/// It is often used to model the magnitude of a two-dimensional vector whose components are uncorrelated, normally distributed with equal variance, and zero mean.
///
/// The parameter is the scale σ, not the mean; the mean is `σ√(π/2)`. See
/// ``distributionRayleigh(scale:seed:)`` for the conversion and for why the parameter
/// was renamed.
public struct DistributionRayleigh: DistributionRandom, Sendable {
    /// The scale parameter σ of the Rayleigh distribution. The mean is `σ√(π/2)`.
    let scale: Double

    /// Creates a new instance of `DistributionRayleigh` with the specified scale.
    ///
    /// - Parameter scale: The scale parameter σ (σ > 0). Not the mean — for a target
    ///   mean `m`, pass `m / 1.2533141373155003`.
    public init(scale: Double) {
        self.scale = scale
    }

    /// Generates a random value from the Rayleigh distribution.
    ///
    /// - Returns: A random value sampled from the Rayleigh distribution.
    public func random() -> Double {
        return distributionRayleigh(scale: scale)
    }
    
    /// Generates the next random value from the Rayleigh distribution.
    ///
    /// - Returns: The next random value sampled from the Rayleigh distribution.
    public func next() -> Double {
        return random()
    }
}

extension DistributionRayleigh: SeedableDistribution {
    /// Generates the next random value, drawing the uniform seed from `generator`.
    ///
    /// Follows the same probability law as ``next()``; a seeded generator makes the
    /// stream fully reproducible.
    ///
    /// - Parameter generator: The random source for the uniform draw.
    /// - Returns: A random value sampled from the Rayleigh distribution
    public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
        // Straight to the shared radius rather than through the seed form: the
        // generator path draws `1 - Double.random(in: 0..<1)`, which is exact on
        // (0, 1] and never has to remap anything.
        return scale * boxMullerRadius(using: &generator)
    }
}


extension DistributionRayleigh: ContinuousDistribution {
    /// P(X ≤ x) = 1 − exp(−x² / 2σ²).
    public func cdf(_ x: Double) -> Double {
        guard scale > 0 else { return Double.nan }
        guard x > 0 else { return 0 }
        let ratio = x / scale
        let exponent = ratio * ratio / 2
        // expMinusOne, not `1 - exp`: see ``exponentialCDF(_:λ:)``.
        return -Double.expMinusOne(-exponent)
    }

    /// The value at which the CDF equals `p`: σ·√(−2 ln(1 − p)).
    public func quantile(_ p: Double) -> Double {
        guard scale > 0 else { return Double.nan }
        guard p < 1 else { return Double.infinity }
        // log(onePlus: -p), not log(1 - p): for small p the subtraction rounds the
        // argument to 1 and the log to zero.
        let negativeLog = -Double.log(onePlus: -p)
        return scale * (2 * negativeLog).squareRoot()
    }
}
