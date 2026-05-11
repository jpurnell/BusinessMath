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
///   - seeds: Optional array of seed values for deterministic generation.
///   - seedIndex: Mutable index tracking position in seed array.
/// - Returns: A random value from InverseGamma(shape, scale).
/// - Throws: `BusinessMathError.invalidInput` if shape or scale is not positive.
public func sampleInverseGamma<T: Real>(
    shape: T,
    scale: T,
    seeds: [Double]? = nil,
    seedIndex: inout Int
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
    let g = gammaVariate(shape: shape, scale: gammaScale, seeds: seeds, seedIndex: &seedIndex)

    guard g > T.zero else {
        throw BusinessMathError.calculationFailed(
            operation: "Inverse-Gamma sampling",
            reason: "Gamma variate was non-positive",
            suggestions: ["Try different seed values"])
    }

    return T(1) / g
}
