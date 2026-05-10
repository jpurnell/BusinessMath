import Foundation
import Numerics

/// Weighted Bland-Altman analysis of agreement between two measurement methods.
///
/// Uses weighted statistics to compute the bias, standard deviation of differences,
/// and limits of agreement, allowing different observations to carry different
/// importance. Proportional bias is assessed by weighted regression of
/// differences on means.
///
/// - Parameters:
///   - x: Measurements from method A.
///   - y: Measurements from method B (same length as x).
///   - weights: Non-negative weights for each observation pair.
///
/// - Returns: `BlandAltmanResult` with weighted bias, SD, limits of agreement,
///            and proportional bias indicators.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 observations.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if sum of weights is zero.
public func blandAltman<T: Real>(
	_ x: [T], _ y: [T], weights: [T]
) throws -> BlandAltmanResult<T> {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count == weights.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Weights must have same length as data",
			expected: "\(x.count)", actual: "\(weights.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "Weighted Bland-Altman analysis requires at least 2 paired observations")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero")
	}

	let n = x.count

	// Compute differences and means of each pair
	let differences: [T] = zip(x, y).map { $0 - $1 }
	let pairMeans: [T] = zip(x, y).map { ($0 + $1) / T(2) }

	// Weighted mean of differences (bias)
	let weightedDiffSum = zip(differences, weights).reduce(T.zero) { acc, pair in
		acc + pair.0 * pair.1
	}
	let bias = weightedDiffSum / totalWeight

	// Weighted SD of differences
	let wss = zip(differences, weights).reduce(T.zero) { acc, pair in
		let dev = pair.0 - bias
		return acc + pair.1 * dev * dev
	}

	let sd: T
	let denominator = totalWeight - T(1)
	if denominator > T.zero {
		sd = T.sqrt(wss / denominator)
	} else {
		sd = T.zero
	}

	// 95% limits of agreement
	let z95 = T(196) / T(100) // 1.96
	let loaLower = bias - z95 * sd
	let loaUpper = bias + z95 * sd

	// Weighted proportional bias: regress differences on pair means
	let weightedMeanOfMeans = zip(pairMeans, weights).reduce(T.zero) { acc, pair in
		acc + pair.0 * pair.1
	} / totalWeight

	var sumXY = T.zero
	var sumXX = T.zero
	var sumYY = T.zero

	for i in 0..<n {
		let dx = pairMeans[i] - weightedMeanOfMeans
		let dy = differences[i] - bias
		sumXY += weights[i] * dx * dy
		sumXX += weights[i] * dx * dx
		sumYY += weights[i] * dy * dy
	}

	let propSlope: T
	let propRSquared: T

	if sumXX == T.zero {
		propSlope = T.zero
		propRSquared = T.zero
	} else {
		propSlope = sumXY / sumXX
		if sumYY == T.zero {
			propRSquared = T.zero
		} else {
			propRSquared = (sumXY * sumXY) / (sumXX * sumYY)
		}
	}

	return BlandAltmanResult(
		bias: bias,
		standardDeviation: sd,
		loaLower: loaLower,
		loaUpper: loaUpper,
		proportionalBiasSlope: propSlope,
		proportionalBiasRSquared: propRSquared,
		count: n
	)
}
