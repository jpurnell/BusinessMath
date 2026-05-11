import Foundation
import Numerics

/// Weighted percentile using linear interpolation.
///
/// Computes the p-th percentile of a weighted dataset using linear
/// interpolation between adjacent order statistics. Observations are sorted
/// by value, and cumulative normalized weights determine the percentile
/// boundaries.
///
/// - Parameters:
///   - values: An array of observed values.
///   - weights: Non-negative weights corresponding to each value.
///   - p: Percentile in [0, 1].
///
/// - Returns: The weighted percentile value.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if `values` and `weights` differ in length.
/// - Throws: `BusinessMathError.insufficientData` if `values` is empty.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative or `p` is outside [0, 1].
/// - Throws: `BusinessMathError.divisionByZero` if the sum of weights is zero.
///
/// - Complexity: O(n log n) due to sorting.
public func weightedPercentile<T: Real>(_ values: [T], weights: [T], p: T) throws -> T {
	guard values.count == weights.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weighted percentile requires equal-length arrays",
			expected: "\(values.count)", actual: "\(weights.count)")
	}
	guard !values.isEmpty else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Weighted percentile requires at least 1 value")
	}
	guard p >= T.zero, p <= T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Percentile p must be in [0, 1]",
			value: "\(p)", expectedRange: "[0, 1]")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero in weighted percentile")
	}

	// Sort observations by value, carrying weights along
	let paired = zip(values, weights).sorted { $0.0 < $1.0 }
	let sortedValues = paired.map(\.0)
	let sortedWeights = paired.map(\.1)

	// Boundary cases
	if p == T.zero {
		return sortedValues[0]
	}
	if p == T(1) {
		return sortedValues[sortedValues.count - 1]
	}

	// Compute midpoint cumulative normalized weights for each observation.
	// CW_i = (sum(w_1..w_{i-1}) + w_i / 2) / W
	// This places each observation at the center of its weight range,
	// giving better correspondence with unweighted percentiles.
	var midpoints = [T]()
	midpoints.reserveCapacity(sortedValues.count)
	var runningSum = T.zero
	let two = T(2)
	for w in sortedWeights {
		let midpoint = (runningSum + w / two) / totalWeight
		midpoints.append(midpoint)
		runningSum += w
	}

	// If p is at or below the first midpoint, return the first value
	if p <= midpoints[0] {
		return sortedValues[0]
	}

	// If p is at or above the last midpoint, return the last value
	if p >= midpoints[midpoints.count - 1] {
		return sortedValues[sortedValues.count - 1]
	}

	// Find the interval where midpoints[i-1] < p <= midpoints[i]
	// and linearly interpolate
	for i in 1..<midpoints.count {
		if p <= midpoints[i] {
			let lower = midpoints[i - 1]
			let upper = midpoints[i]
			let range = upper - lower

			guard range > T.zero else {
				// Both midpoints are equal (zero-weight neighbor), return this value
				return sortedValues[i]
			}

			let fraction = (p - lower) / range
			return sortedValues[i - 1] + fraction * (sortedValues[i] - sortedValues[i - 1])
		}
	}

	// Fallback: return maximum (should not reach here with valid input)
	return sortedValues[sortedValues.count - 1]
}
