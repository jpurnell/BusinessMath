import Foundation
import Numerics

/// Computes the weighted variance using reliability weights.
///
/// Weighted variance generalizes the standard variance by assigning different
/// importance to each observation. This is useful when observations have
/// different reliabilities, frequencies, or precisions.
///
/// For **sample** variance:
/// ```
/// Var_w = (sum w_i * (x_i - mu_w)^2) / (sum(w_i) - 1)
/// ```
///
/// For **population** variance:
/// ```
/// Var_w = (sum w_i * (x_i - mu_w)^2) / sum(w_i)
/// ```
///
/// where `mu_w = sum(w_i * x_i) / sum(w_i)` is the weighted mean.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: An array of non-negative weights corresponding to each value.
///   - pop: Whether to compute sample or population variance. Defaults to `.sample`.
///
/// - Returns: The weighted variance of the dataset.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values or if the
///   denominator (sum of weights minus 1 for sample) is not positive.
public func weightedVariance<T: Real>(
	_ values: [T], weights: [T], _ pop: Population = .sample
) throws -> T {
	guard values.count == weights.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weighted variance requires equal-length arrays",
			expected: "\(values.count)", actual: "\(weights.count)")
	}
	guard values.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: values.count,
			context: "Weighted variance requires at least 2 values")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero")
	}

	// Weighted mean
	let weightedSum = zip(values, weights).reduce(T.zero) { acc, pair in
		acc + pair.0 * pair.1
	}
	let weightedMean = weightedSum / totalWeight

	// Weighted sum of squared deviations
	let wss = zip(values, weights).reduce(T.zero) { acc, pair in
		let deviation = pair.0 - weightedMean
		return acc + pair.1 * deviation * deviation
	}

	switch pop {
	case .population:
		return wss / totalWeight
	case .sample:
		let denominator = totalWeight - T(1)
		guard denominator > T.zero else {
			throw BusinessMathError.insufficientData(
				required: 2, actual: values.count,
				context: "Weighted sample variance requires sum of weights > 1")
		}
		return wss / denominator
	}
}
