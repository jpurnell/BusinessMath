import Foundation
import Numerics

/// Alpha-trimmed weighted mean.
///
/// Excludes observations below the alpha-th and above the (1-alpha)-th
/// weighted percentiles, then computes the weighted mean of retained
/// observations. For boundary observations that straddle a trimming
/// threshold, fractional weight inclusion is used.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - alpha: Trimming proportion (0 < alpha < 0.5). Default 0.05.
///
/// - Returns: The trimmed weighted mean.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 3 values.
/// - Throws: `BusinessMathError.invalidInput` if `alpha` is outside (0, 0.5) or any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
///
/// - Complexity: O(n log n) due to sorting.
public func weightedTrimmedMean<T: Real>(
	_ values: [T], weights: [T], alpha: T = T(5) / T(100)
) throws -> T {
	guard values.count == weights.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weighted trimmed mean requires equal-length arrays",
			expected: "\(values.count)", actual: "\(weights.count)")
	}
	guard values.count >= 3 else {
		throw BusinessMathError.insufficientData(
			required: 3, actual: values.count,
			context: "Weighted trimmed mean requires at least 3 values")
	}
	guard alpha > T.zero, alpha < T(1) / T(2) else {
		throw BusinessMathError.invalidInput(
			message: "Trimming alpha must be in (0, 0.5)",
			value: "\(alpha)", expectedRange: "(0, 0.5)")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero in weighted trimmed mean")
	}

	// Sort observations by value, carrying weights along
	let paired = zip(values, weights).sorted { $0.0 < $1.0 }
	let sortedValues = paired.map(\.0)
	let sortedWeights = paired.map(\.1)

	let lowerThreshold = alpha
	let upperThreshold = T(1) - alpha

	// Build cumulative weight fractions
	// F_i = sum(w_1..w_i) / W (cumulative fraction through observation i)
	var cumulativeFractions = [T]()
	cumulativeFractions.reserveCapacity(sortedValues.count)
	var runningSum = T.zero
	for w in sortedWeights {
		runningSum += w
		cumulativeFractions.append(runningSum / totalWeight)
	}

	// Compute fractional weights for each observation
	// An observation contributes fully if it falls entirely within [alpha, 1-alpha]
	// Partially if it straddles a boundary
	var adjustedWeights = [T]()
	adjustedWeights.reserveCapacity(sortedValues.count)

	for i in 0..<sortedValues.count {
		let fPrev: T = (i == 0) ? T.zero : cumulativeFractions[i - 1]
		let fCurr = cumulativeFractions[i]

		// The observation spans from fPrev to fCurr in cumulative weight space
		// We retain the portion that overlaps with [alpha, 1-alpha]
		let overlapLower = max(fPrev, lowerThreshold)
		let overlapUpper = min(fCurr, upperThreshold)
		let overlap = max(overlapUpper - overlapLower, T.zero)

		adjustedWeights.append(overlap)
	}

	let retainedWeight = adjustedWeights.reduce(T.zero, +)

	guard retainedWeight > T.zero else {
		throw BusinessMathError.divisionByZero(
			context: "No observations retained after trimming in weighted trimmed mean")
	}

	// Weighted mean of retained observations
	let weightedSum = zip(sortedValues, adjustedWeights).reduce(T.zero) { acc, pair in
		acc + pair.0 * pair.1
	}

	return weightedSum / retainedWeight
}
