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
/// - Throws: `BusinessMathError.dataQuality` if any weight is not finite. A `nan` weight
///   fails `>= 0`, so before this screen existed it was refused as a *negative* weight —
///   the right refusal reported through a guard written for a different condition, sending
///   the reader hunting for a minus sign that is not there.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero. This now means
///   only what it says: every weight was finite and they summed to zero.
///
/// - Complexity: O(n).
public func weightedBreakdownPoint<T: Real>(_ weights: [T], trimming: T? = nil) throws -> T {
	guard !weights.isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Weighted breakdown point requires at least 1 weight")
	}
	// A `nan` weight fails `>= T.zero`, so without this screen the caller is told "Weights must
	// be non-negative" for data containing no negative weight; and an all-infinite set passes
	// every guard below and reaches `minWeight / totalWeight` as `inf / inf`, returning `nan`
	// from a function that refuses by throwing rather than by returning one. Neither outcome
	// names the contamination, which is the only thing wrong with the input.
	let invalidWeights = weights.filter { !$0.isFinite }.count
	guard invalidWeights == 0 else {
		throw BusinessMathError.dataQuality(
			message: "Weighted breakdown point requires finite weights",
			context: ["invalid_count": "\(invalidWeights)"])
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
