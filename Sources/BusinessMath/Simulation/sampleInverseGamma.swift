import Foundation
import Numerics

/// Samples from an Inverse-Gamma(shape, scale) distribution.
///
/// Uses the relationship: if `X ~ Gamma(shape, 1/scale)`, then `1/X ~ InverseGamma(shape, scale)`.
/// The Inverse-Gamma distribution is the conjugate prior for the variance parameter of a
/// normal distribution with known mean, making it fundamental to Bayesian variance estimation.
///
/// - Parameters:
///   - shape: The shape parameter (must be > 0).
///   - scale: The scale parameter (must be > 0).
///   - seed: Seed for a private ``DeterministicRNG``. The same seed with the same shape
///     and scale reproduces the same value exactly. `nil` (the default) draws from system
///     entropy and is non-reproducible by contract — use `seed:` or
///     ``sampleInverseGamma(shape:scale:using:)`` when reproducibility matters.
/// - Returns: A random value from InverseGamma(shape, scale).
/// - Throws: `BusinessMathError.invalidInput` if shape or scale is not positive.
public func sampleInverseGamma<T: Real>(
    shape: T,
    scale: T,
    seed: UInt64? = nil
) throws -> T where T: BinaryFloatingPoint {
    if let seed {
        var generator = DeterministicRNG(seed: seed)
        return try sampleInverseGamma(shape: shape, scale: scale, using: &generator)
    }
    var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
    return try sampleInverseGamma(shape: shape, scale: scale, using: &generator)
}

/// Samples from an Inverse-Gamma(shape, scale) distribution, drawing every uniform from `generator`.
///
/// The generator-parameterized form of ``sampleInverseGamma(shape:scale:seed:)``,
/// following the same convention as ``SeedableDistribution/next(using:)``: all randomness
/// comes from the caller's generator, so the caller owns reproducibility and can
/// interleave this draw with others on a single stream. Gibbs samplers want exactly this —
/// one stream advancing across thousands of sweeps rather than a fresh seed per draw.
///
/// - Parameters:
///   - shape: The shape parameter (must be > 0).
///   - scale: The scale parameter (must be > 0).
///   - generator: The random source. Advanced by a data-dependent number of draws, since
///     the underlying Marsaglia-Tsang sampler rejects.
/// - Returns: A random value from InverseGamma(shape, scale).
/// - Throws: `BusinessMathError.invalidInput` if shape or scale is not positive.
public func sampleInverseGamma<T: Real, G: RandomNumberGenerator>(
    shape: T,
    scale: T,
    using generator: inout G
) throws -> T where T: BinaryFloatingPoint {
    guard shape > T.zero else {
        throw BusinessMathError.invalidInput(
            message: "Inverse-Gamma shape must be positive",
            value: "\(shape)",
            expectedRange: "(0, +inf)")
    }
    guard scale > T.zero else {
        throw BusinessMathError.invalidInput(
            message: "Inverse-Gamma scale must be positive",
            value: "\(scale)",
            expectedRange: "(0, +inf)")
    }

    // Gamma(shape, 1/scale) — note gammaVariate takes scale parameter, not rate
    let gammaScale = T(1) / scale
    let g = gammaVariate(shape: shape, scale: gammaScale, using: &generator)

    guard g > T.zero else {
        throw BusinessMathError.calculationFailed(
            operation: "Inverse-Gamma sampling",
            reason: "Gamma variate was non-positive",
            suggestions: ["Draw again, or widen the shape parameter"])
    }

    return T(1) / g
}
