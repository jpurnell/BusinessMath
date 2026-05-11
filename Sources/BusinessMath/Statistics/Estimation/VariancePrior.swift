import Foundation
import Numerics

/// Prior distribution specification for a variance parameter using the Inverse-Gamma family.
///
/// In Bayesian variance estimation the Inverse-Gamma(shape, scale) distribution is the
/// conjugate prior for the variance of a normal likelihood. The ``shape`` parameter
/// controls the concentration of prior belief, while ``scale`` anchors the prior mode.
///
/// Two convenience factories are provided:
/// - ``vague``: A minimally informative prior that lets the data dominate.
/// - ``informative(expectedVariance:strength:)``: An informative prior centered
///   on a specified expected variance with tunable strength.
///
/// ## Topics
///
/// ### Creating Priors
/// - ``vague``
/// - ``informative(expectedVariance:strength:)``
public struct VariancePrior<T: Real & Sendable>: Sendable, Equatable {
    /// The shape parameter of the Inverse-Gamma prior (must be > 0).
    public let shape: T
    /// The scale parameter of the Inverse-Gamma prior (must be > 0).
    public let scale: T

    /// Creates a variance prior with explicit shape and scale parameters.
    ///
    /// - Parameters:
    ///   - shape: The shape parameter (> 0).
    ///   - scale: The scale parameter (> 0).
    public init(shape: T, scale: T) {
        self.shape = shape
        self.scale = scale
    }

    /// A vague (minimally informative) prior suitable when no strong prior
    /// beliefs about the variance exist.
    ///
    /// Uses Inverse-Gamma(0.001, 0.001), which has very little influence
    /// on the posterior when the sample size is moderate or large.
    public static var vague: VariancePrior {
        VariancePrior(shape: T(1) / T(1000), scale: T(1) / T(1000))
    }

    /// Creates an informative prior centered on a specific expected variance.
    ///
    /// The resulting Inverse-Gamma has mode close to `expectedVariance` and
    /// tighter concentration as `strength` increases.
    ///
    /// - Parameters:
    ///   - expectedVariance: The a-priori expected variance (> 0).
    ///   - strength: How strongly to weight the prior — larger values
    ///     correspond to more pseudo-observations (> 0).
    /// - Returns: An informative ``VariancePrior``.
    public static func informative(expectedVariance: T, strength: T) -> VariancePrior {
        VariancePrior(
            shape: strength / T(2),
            scale: strength * expectedVariance / T(2)
        )
    }
}
