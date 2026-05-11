import Foundation
import Numerics

/// Alpha-Winsorized weighted standard deviation.
///
/// Computes the square root of the alpha-Winsorized weighted variance.
/// Values below the alpha-th and above the (1-alpha)-th weighted percentiles
/// are clipped to those boundary values before computing the standard deviation.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - alpha: Winsorizing proportion (0 < alpha < 0.5). Default 0.05.
///   - pop: Whether to compute sample or population standard deviation. Defaults to `.sample`.
///
/// - Returns: The Winsorized weighted standard deviation.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.invalidInput` if `alpha` is outside (0, 0.5) or any weight is negative.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
///
/// - Complexity: O(n log n) due to percentile computation.
public func winsorizedWeightedStandardDeviation<T: Real>(
	_ values: [T], weights: [T], alpha: T = T(5) / T(100), _ pop: Population = .sample
) throws -> T {
	let wVar = try winsorizedWeightedVariance(values, weights: weights, alpha: alpha, pop)
	return T.sqrt(wVar)
}
