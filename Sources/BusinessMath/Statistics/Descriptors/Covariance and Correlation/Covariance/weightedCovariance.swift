import Foundation
import Numerics

/// Computes the weighted covariance between two datasets.
///
/// Weighted covariance measures the joint variability of two variables,
/// with each observation weighted by its reliability or importance.
///
/// For **sample** covariance:
/// ```
/// Cov_w(x, y) = (sum w_i * (x_i - mu_wx) * (y_i - mu_wy)) / (sum(w_i) - 1)
/// ```
///
/// For **population** covariance:
/// ```
/// Cov_w(x, y) = (sum w_i * (x_i - mu_wx) * (y_i - mu_wy)) / sum(w_i)
/// ```
///
/// - Parameters:
///   - x: An array of values for the first variable.
///   - y: An array of values for the second variable.
///   - weights: An array of non-negative weights corresponding to each observation.
///   - pop: Whether to compute sample or population covariance. Defaults to `.sample`.
///
/// - Returns: The weighted covariance of `x` and `y`.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `x`, `y`, and `weights` differ in length.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values or if the
///   sample denominator is not positive.
public func weightedCovariance<T: Real>(
	_ x: [T], _ y: [T], weights: [T], _ pop: Population = .sample
) throws -> T {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weighted covariance requires x and y of equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count == weights.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weighted covariance requires weights of same length as data",
			expected: "\(x.count)", actual: "\(weights.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "Weighted covariance requires at least 2 observations")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero")
	}

	// Weighted means
	var sumWX = T.zero
	var sumWY = T.zero
	for i in 0..<x.count {
		sumWX += weights[i] * x[i]
		sumWY += weights[i] * y[i]
	}
	let muX = sumWX / totalWeight
	let muY = sumWY / totalWeight

	// Weighted cross-deviation sum
	var wCrossSum = T.zero
	for i in 0..<x.count {
		wCrossSum += weights[i] * (x[i] - muX) * (y[i] - muY)
	}

	switch pop {
	case .population:
		return wCrossSum / totalWeight
	case .sample:
		let denominator = totalWeight - T(1)
		guard denominator > T.zero else {
			throw BusinessMathError.insufficientData(
				required: 2, actual: x.count,
				context: "Weighted sample covariance requires sum of weights > 1")
		}
		return wCrossSum / denominator
	}
}
