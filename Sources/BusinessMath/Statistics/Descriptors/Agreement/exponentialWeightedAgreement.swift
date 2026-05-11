import Foundation
import Numerics

/// Exponentially decaying weights for time-ordered observations.
///
/// Generates weights where the most recent observation (index `count - 1`)
/// receives weight 1.0, and each earlier observation is discounted by a
/// factor of lambda: `w_i = lambda^(count - 1 - i)`.
///
/// - Parameters:
///   - count: Number of observations.
///   - lambda: Decay factor in (0, 1]. A value of 1.0 gives equal weights.
///
/// - Returns: Array of `count` weights with exponential decay.
///
/// - Throws: `BusinessMathError.invalidInput` if lambda is not in (0, 1].
/// - Throws: `BusinessMathError.insufficientData` if count < 1.
public func exponentialDecayWeights<T: Real>(count: Int, lambda: T) throws -> [T] {
	guard lambda > T.zero, lambda <= T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Lambda must be in (0, 1]",
			value: "\(lambda)", expectedRange: "(0, 1]")
	}
	guard count >= 1 else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: count,
			context: "Exponential decay weights require at least 1 observation")
	}

	return (0..<count).map { i in
		T.pow(lambda, T(count - 1 - i))
	}
}

/// Exponentially weighted Bland-Altman analysis.
///
/// Applies exponentially decaying weights to a Bland-Altman analysis,
/// giving more influence to recent observations. Useful for detecting
/// drift in measurement agreement over time.
///
/// - Parameters:
///   - x: Measurements from method A (time-ordered, oldest first).
///   - y: Measurements from method B (same length as x, time-ordered).
///   - lambda: Decay factor in (0, 1]. 1.0 gives equal weights (unweighted).
///
/// - Returns: `BlandAltmanResult` with exponentially weighted statistics.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 observations.
/// - Throws: `BusinessMathError.invalidInput` if lambda is not in (0, 1].
public func exponentialWeightedBlandAltman<T: Real>(
	_ x: [T], _ y: [T], lambda: T
) throws -> BlandAltmanResult<T> {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "Exponentially weighted Bland-Altman requires at least 2 observations")
	}

	let weights = try exponentialDecayWeights(count: x.count, lambda: lambda)
	return try blandAltman(x, y, weights: weights)
}
