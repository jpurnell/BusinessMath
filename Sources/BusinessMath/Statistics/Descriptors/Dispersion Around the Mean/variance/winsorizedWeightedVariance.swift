import Foundation
import Numerics

/// Alpha-Winsorized weighted variance.
///
/// Clips values below the alpha-th and above the (1-alpha)-th weighted
/// percentiles to those boundary values, then computes the weighted variance
/// of the clipped dataset.
///
/// Winsorizing reduces the influence of extreme observations without
/// discarding them entirely, providing a robust variance estimate.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - alpha: Winsorizing proportion (0 < alpha < 0.5). Default 0.05.
///   - pop: Whether to compute sample or population variance. Defaults to `.sample`.
///
/// - Returns: The Winsorized weighted variance.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.invalidInput` if `alpha` is outside (0, 0.5) or any weight is negative.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
///
/// - Complexity: O(n log n) due to percentile computation.
public func winsorizedWeightedVariance<T: Real>(
	_ values: [T], weights: [T], alpha: T = T(5) / T(100), _ pop: Population = .sample
) throws -> T {
	guard alpha > T.zero, alpha < T(1) / T(2) else {
		throw BusinessMathError.invalidInput(
			message: "Winsorizing alpha must be in (0, 0.5)",
			value: "\(alpha)", expectedRange: "(0, 0.5)")
	}

	// Compute clipping boundaries using weighted percentiles
	let lowerBound = try weightedPercentile(values, weights: weights, p: alpha)
	let upperBound = try weightedPercentile(values, weights: weights, p: T(1) - alpha)

	// Clip values to boundaries
	let clippedValues = values.map { value -> T in
		if value < lowerBound {
			return lowerBound
		} else if value > upperBound {
			return upperBound
		} else {
			return value
		}
	}

	// Compute weighted variance of clipped values
	return try weightedVariance(clippedValues, weights: weights, pop)
}
