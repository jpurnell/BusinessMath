import Foundation
import Numerics

/// Computes the weighted Pearson correlation coefficient.
///
/// The weighted correlation is defined as:
/// ```
/// r_w = Cov_w(x, y) / (SD_w(x) * SD_w(y))
/// ```
///
/// where `Cov_w` is the weighted covariance and `SD_w` is the weighted standard
/// deviation. Uses sample-based weighted statistics internally.
///
/// - Parameters:
///   - x: An array of values for the first variable.
///   - y: An array of values for the second variable.
///   - weights: An array of non-negative weights corresponding to each observation.
///
/// - Returns: The weighted Pearson correlation coefficient in [-1, 1].
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if either variable has zero weighted
///   variance, or if the sum of weights is zero.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 observations.
public func weightedCorrelation<T: Real>(
	_ x: [T], _ y: [T], weights: [T]
) throws -> T {
	// Compute weighted standard deviations (will validate inputs)
	let sdX = try weightedStandardDeviation(x, weights: weights, .sample)
	let sdY = try weightedStandardDeviation(y, weights: weights, .sample)

	guard sdX > T.zero else {
		throw BusinessMathError.divisionByZero(
			context: "Weighted correlation: x series has zero weighted variance")
	}
	guard sdY > T.zero else {
		throw BusinessMathError.divisionByZero(
			context: "Weighted correlation: y series has zero weighted variance")
	}

	let cov = try weightedCovariance(x, y, weights: weights, .sample)

	return cov / (sdX * sdY)
}
