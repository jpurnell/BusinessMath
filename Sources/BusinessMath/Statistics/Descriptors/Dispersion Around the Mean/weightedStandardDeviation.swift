import Foundation
import Numerics

/// Computes the weighted standard deviation (square root of weighted variance).
///
/// Weighted standard deviation generalizes the standard deviation by assigning
/// different importance to each observation via reliability weights.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: An array of non-negative weights corresponding to each value.
///   - pop: Whether to compute sample or population standard deviation. Defaults to `.sample`.
///
/// - Returns: The weighted standard deviation of the dataset.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 values or if the
///   denominator is not positive.
public func weightedStandardDeviation<T: Real>(
	_ values: [T], weights: [T], _ pop: Population = .sample
) throws -> T {
	let wVar = try weightedVariance(values, weights: weights, pop)
	return T.sqrt(wVar)
}
