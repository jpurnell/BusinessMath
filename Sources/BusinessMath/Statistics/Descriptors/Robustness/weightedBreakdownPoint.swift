import Foundation
import Numerics

/// Breakdown point of a weighted estimator.
///
/// The finite-sample breakdown point is the smallest fraction of observations
/// (by weight) that can make the estimate arbitrarily bad. A higher breakdown
/// point indicates a more robust estimator.
///
/// - Without trimming: the breakdown point equals `min(w_i) / sum(w_i)`,
///   reflecting that corrupting the lightest observation is sufficient.
/// - With trimming at level `alpha`: the breakdown point equals `alpha`,
///   since the trimmed estimator discards observations beyond that fraction.
///
/// - Parameters:
///   - weights: Non-negative weights.
///   - trimming: Optional trimming proportion (for trimmed estimators).
///
/// - Returns: The breakdown point in [0, 0.5].
///
/// - Throws: `BusinessMathError.insufficientData` if `weights` is empty.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
///
/// - Complexity: O(n).
public func weightedBreakdownPoint<T: Real>(_ weights: [T], trimming: T? = nil) throws -> T {
	guard !weights.isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Weighted breakdown point requires at least 1 weight")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(
			context: "Total weight is zero in weighted breakdown point")
	}

	// With trimming, the breakdown point equals the trimming proportion
	if let alpha = trimming {
		return alpha
	}

	// Without trimming: breakdown = min(w_i) / sum(w_i)
	guard let minWeight = weights.min() else {
		// Should not reach here since we checked isEmpty above
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Weighted breakdown point requires at least 1 weight")
	}

	return minWeight / totalWeight
}
