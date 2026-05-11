import Foundation
import Numerics

/// Credible interval bounds for a Bayesian estimate.
///
/// Stores the lower and upper bounds of a highest-density or
/// equal-tailed credible interval.
public struct CredibleInterval<T: Real & Sendable>: Sendable, Equatable {
    /// Lower bound of the credible interval.
    public let lower: T
    /// Upper bound of the credible interval.
    public let upper: T

    /// Creates a credible interval with specified bounds.
    ///
    /// - Parameters:
    ///   - lower: Lower bound.
    ///   - upper: Upper bound.
    public init(lower: T, upper: T) {
        self.lower = lower
        self.upper = upper
    }
}

/// Result of Bayesian ICC estimation via Gibbs sampling.
///
/// Contains the full posterior samples for all variance components and the
/// derived ICC, along with summary statistics (mean, median, credible interval)
/// and convergence diagnostics (R-hat, effective sample size).
///
/// Use ``probabilityAbove(_:)`` to compute the posterior probability that the
/// ICC exceeds a substantive threshold.
///
/// ## Topics
///
/// ### Posterior Samples
/// - ``sigmaSubjectsSamples``
/// - ``sigmaRatersSamples``
/// - ``sigmaErrorSamples``
/// - ``iccSamples``
///
/// ### Summary Statistics
/// - ``iccMean``
/// - ``iccMedian``
/// - ``iccCredibleInterval``
///
/// ### Convergence Diagnostics
/// - ``rHat``
/// - ``effectiveSampleSizeCount``
public struct BayesianICCResult<T: Real & Sendable>: Sendable, Equatable {
    /// Posterior samples of the subject (between-group) variance component.
    public let sigmaSubjectsSamples: [T]
    /// Posterior samples of the rater (between-rater) variance component.
    public let sigmaRatersSamples: [T]
    /// Posterior samples of the residual error variance component.
    public let sigmaErrorSamples: [T]
    /// Posterior samples of the intraclass correlation coefficient.
    public let iccSamples: [T]

    /// Posterior mean of the ICC.
    public let iccMean: T
    /// Posterior median of the ICC.
    public let iccMedian: T
    /// 95% equal-tailed credible interval for the ICC.
    public let iccCredibleInterval: CredibleInterval<T>

    /// Posterior mean of the subject variance component.
    public let sigmaSubjectsMean: T
    /// Posterior mean of the rater variance component.
    public let sigmaRatersMean: T
    /// Posterior mean of the error variance component.
    public let sigmaErrorMean: T

    /// Gelman-Rubin R-hat convergence diagnostic. `nil` if only one chain was run.
    public let rHat: T?
    /// Effective sample size accounting for autocorrelation.
    public let effectiveSampleSizeCount: Int

    /// Computes the posterior probability that the ICC exceeds a given threshold.
    ///
    /// - Parameter threshold: The ICC value to compare against.
    /// - Returns: The proportion of posterior samples above `threshold`, in [0, 1].
    public func probabilityAbove(_ threshold: T) -> T {
        guard !iccSamples.isEmpty else { return T.zero }
        let count = iccSamples.filter { $0 > threshold }.count
        return T(count) / T(iccSamples.count)
    }
}
