import Foundation
import Numerics

/// Result of a Bland-Altman agreement analysis.
public struct BlandAltmanResult<T: Real>: Sendable, Equatable {
	/// Mean difference (x - y). Positive means x reads higher than y.
	public let bias: T

	/// Standard deviation of the differences (sample SD).
	public let standardDeviation: T

	/// Lower 95% limit of agreement (bias - 1.96 × SD).
	public let loaLower: T

	/// Upper 95% limit of agreement (bias + 1.96 × SD).
	public let loaUpper: T

	/// Slope of differences regressed on means.
	/// Non-zero indicates proportional bias (disagreement scales with magnitude).
	public let proportionalBiasSlope: T

	/// R² of the proportional bias regression (differences ~ means).
	public let proportionalBiasRSquared: T

	/// Number of paired observations.
	public let count: Int
}

/// Bland-Altman analysis of agreement between two measurement methods.
///
/// Computes the mean difference (bias) and 95% limits of agreement
/// between paired measurements from two methods. Also detects proportional
/// bias by regressing differences on means.
///
/// - Parameters:
///   - x: Measurements from method A.
///   - y: Measurements from method B (same length as x).
/// - Returns: Bias, standard deviation of differences, limits of agreement,
///            and proportional bias indicators.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///           `BusinessMathError.insufficientData` if fewer than 2 observations.
public func blandAltman<T: Real>(_ x: [T], _ y: [T]) throws -> BlandAltmanResult<T> {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "Bland-Altman analysis requires at least 2 paired observations")
	}

	let n = x.count
	let nT = T(n)

	// Compute differences and means
	let differences: [T] = zip(x, y).map { $0 - $1 }
	let means: [T] = zip(x, y).map { ($0 + $1) / T(2) }

	// Bias = mean of differences
	let bias = differences.reduce(T.zero, +) / nT

	// Sample standard deviation of differences
	let sumSquaredDeviations = differences.reduce(T.zero) { acc, d in
		let dev = d - bias
		return acc + dev * dev
	}
	let sd = T.sqrt(sumSquaredDeviations / T(n - 1))

	// 95% limits of agreement
	let z95 = T(196) / T(100) // 1.96
	let loaLower = bias - z95 * sd
	let loaUpper = bias + z95 * sd

	// Proportional bias: regress differences on means
	let meanOfMeans = means.reduce(T.zero, +) / nT
	let meanOfDiffs = bias

	var sumXY = T.zero
	var sumXX = T.zero
	var sumYY = T.zero

	for i in 0..<n {
		let dx = means[i] - meanOfMeans
		let dy = differences[i] - meanOfDiffs
		sumXY += dx * dy
		sumXX += dx * dx
		sumYY += dy * dy
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
