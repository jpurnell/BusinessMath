import Foundation
import Numerics

// MARK: - Cluster ICC (LME-Based)

/// Computes the intraclass correlation coefficient from clustered data
/// using a random-intercept linear mixed-effects model.
///
/// This is a convenience wrapper that builds an intercept-only
/// ``RandomInterceptModel``, fits it via ``fitRandomIntercept(_:maxIterations:tolerance:)``,
/// and returns the ICC = sigma_u squared / (sigma_u squared + sigma_e squared).
///
/// Unlike the rater-agreement ``icc(_:model:agreement:confidence:)`` function,
/// this computes the proportion of total variance attributable to between-group
/// differences in an LME framework.
///
/// - Parameter values: Array of arrays where each inner array contains one
///   group's observations. Must contain at least 2 groups, each with at
///   least 1 observation.
/// - Returns: The ICC in [0, 1].
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)``
///   if fewer than 2 groups or total observations are insufficient.
public func clusterICC<T: Real & Sendable>(
    _ values: [[T]]
) throws -> T where T: BinaryFloatingPoint {
    guard !values.isEmpty else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: 0,
            context: "clusterICC requires at least 2 groups")
    }
    guard values.count >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: values.count,
            context: "clusterICC requires at least 2 groups")
    }

    // Flatten to parallel arrays
    var flatValues = [T]()
    var flatGroups = [Int]()
    for (g, group) in values.enumerated() {
        guard !group.isEmpty else {
            throw BusinessMathError.insufficientData(
                required: 1, actual: 0,
                context: "Each group must have at least 1 observation (group \(g) is empty)")
        }
        for obs in group {
            flatValues.append(obs)
            flatGroups.append(g)
        }
    }

    return try clusterICC(values: flatValues, groups: flatGroups)
}

/// Computes the intraclass correlation coefficient from flat arrays
/// using a random-intercept linear mixed-effects model.
///
/// This is a convenience wrapper that builds an intercept-only
/// ``RandomInterceptModel``, fits it, and returns the ICC.
///
/// - Parameters:
///   - values: Observation values (length N).
///   - groups: Group assignment for each observation (length N, 0-indexed).
/// - Returns: The ICC in [0, 1].
/// - Throws: ``BusinessMathError/mismatchedDimensions(message:expected:actual:)``
///   if values and groups differ in length.
///   ``BusinessMathError/insufficientData(required:actual:context:)``
///   if fewer than 2 groups or insufficient observations.
public func clusterICC<T: Real & Sendable>(
    values: [T], groups: [Int]
) throws -> T where T: BinaryFloatingPoint {
    guard values.count == groups.count else {
        throw BusinessMathError.mismatchedDimensions(
            message: "values and groups must have the same length",
            expected: "\(values.count)",
            actual: "\(groups.count)")
    }

    let grouping = try GroupingFactor(groups)
    let N = values.count
    let X = DenseMatrix<T>(rows: N, columns: 1, repeating: T(1))
    let model = RandomInterceptModel(fixedEffects: X, response: values, grouping: grouping)
    let result = try fitRandomIntercept(model)
    return result.icc
}

// MARK: - Likelihood Ratio Test

/// Result of a likelihood ratio test comparing two nested LME models.
///
/// The LRT statistic is computed as:
/// ```
/// chi-square = -2 * (logLik_reduced - logLik_full)
/// ```
/// which follows a chi-squared distribution with degrees of freedom equal
/// to the difference in the number of variance parameters between models.
public struct LRTResult<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
    /// Chi-square test statistic: -2 * (logLik_reduced - logLik_full).
    public let chiSquare: T

    /// Degrees of freedom (difference in number of variance parameters).
    public let degreesOfFreedom: Int

    /// P-value from the chi-squared distribution.
    public let pValue: T
}

/// Performs a likelihood ratio test comparing a random-intercept model
/// (reduced) against a random intercept-and-slope model (full).
///
/// The test evaluates whether adding random slopes significantly improves
/// the model fit. The degrees of freedom equal 2, reflecting the additional
/// variance parameters in the full model (sigma_u1 squared and sigma_u01)
/// beyond the single sigma_u squared in the reduced model.
///
/// - Parameters:
///   - reduced: Result from fitting a random-intercept model.
///   - full: Result from fitting a random intercept-and-slope model on the same data.
/// - Returns: An ``LRTResult`` containing the chi-square statistic, df, and p-value.
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)``
///   if the chi-square statistic is not finite.
public func likelihoodRatioTest<T: Real>(
    reduced: RandomInterceptResult<T>,
    full: RandomSlopeResult<T>
) throws -> LRTResult<T> where T: BinaryFloatingPoint {
    // LRT statistic: -2 * (logLik_reduced - logLik_full)
    let rawChiSq = T(-2) * (reduced.remlLogLikelihood - full.remlLogLikelihood)

    // Clamp to non-negative (numerical noise can produce tiny negatives)
    let chiSq = T.maximum(rawChiSq, T.zero)

    guard chiSq.isFinite else {
        throw BusinessMathError.invalidInput(
            message: "LRT chi-square statistic is not finite",
            value: "\(chiSq)",
            expectedRange: "[0, ∞)")
    }

    // df = 2: full model has 3 variance params (sigma_u0², sigma_u1², sigma_u01)
    // reduced has 1 variance param (sigma_u²), so df = 3 - 1 = 2
    let df = 2

    // p-value from chi-squared CDF
    let cdfValue: T = try chiSquaredCDF(x: chiSq, df: df)
    let pValue = T(1) - cdfValue

    return LRTResult(chiSquare: chiSq, degreesOfFreedom: df, pValue: pValue)
}

// MARK: - AIC / BIC Model Selection

/// Indicates which of two nested models is preferred.
public enum ModelSelection: Sendable, Equatable {
    /// The reduced (random-intercept-only) model is preferred.
    case reduced
    /// The full (random intercept-and-slope) model is preferred.
    case full
}

/// Selects between a random-intercept and random-slope model using AIC.
///
/// The Akaike Information Criterion balances goodness of fit against
/// model complexity. Lower AIC indicates a better trade-off.
///
/// - Parameters:
///   - reduced: Result from fitting a random-intercept model.
///   - full: Result from fitting a random intercept-and-slope model.
/// - Returns: ``ModelSelection/reduced`` or ``ModelSelection/full``
///   depending on which has lower AIC.
public func selectByAIC<T: Real>(
    reduced: RandomInterceptResult<T>,
    full: RandomSlopeResult<T>
) -> ModelSelection where T: BinaryFloatingPoint {
    full.aic < reduced.aic ? .full : .reduced
}

/// Selects between a random-intercept and random-slope model using BIC.
///
/// The Bayesian Information Criterion penalizes model complexity more
/// heavily than AIC, especially for larger sample sizes. Lower BIC
/// indicates a better trade-off.
///
/// - Parameters:
///   - reduced: Result from fitting a random-intercept model.
///   - full: Result from fitting a random intercept-and-slope model.
/// - Returns: ``ModelSelection/reduced`` or ``ModelSelection/full``
///   depending on which has lower BIC.
public func selectByBIC<T: Real>(
    reduced: RandomInterceptResult<T>,
    full: RandomSlopeResult<T>
) -> ModelSelection where T: BinaryFloatingPoint {
    full.bic < reduced.bic ? .full : .reduced
}

// MARK: - Design Effect

/// Computes the design effect (DEFF) for a random-intercept model.
///
/// The design effect measures how much the variance of a statistic is
/// inflated by clustering compared to simple random sampling:
/// ```
/// DEFF = 1 + (average_cluster_size - 1) * ICC
/// ```
///
/// A DEFF of 1 means no clustering effect. A DEFF of 3 means the
/// effective sample size is one-third of the nominal sample size.
///
/// - Parameter result: A fitted random-intercept model result.
/// - Returns: The design effect (always >= 1 when ICC >= 0).
public func designEffect<T: Real>(
    _ result: RandomInterceptResult<T>
) -> T where T: BinaryFloatingPoint {
    guard result.groups > 0 else { return T(1) }
    let averageClusterSize = T(result.observations) / T(result.groups)
    let deff = T(1) + (averageClusterSize - T(1)) * result.icc
    return T.maximum(deff, T(1))
}
