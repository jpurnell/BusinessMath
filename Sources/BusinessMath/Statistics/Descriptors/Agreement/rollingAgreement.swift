import Foundation
import Numerics

/// Rolling (moving-window) concordance correlation coefficient.
///
/// Slides a fixed-size window across paired measurement series and computes
/// the CCC for each window position. Useful for detecting changes in
/// agreement over time or across ordered observations.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - windowSize: Number of observations in each window (must be >= 3).
///   - step: Number of observations to advance between windows (default: 1).
///
/// - Returns: Array of (startIndex, CCCResult) tuples for each window.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.invalidInput` if windowSize < 3 or step < 1.
/// - Throws: `BusinessMathError.insufficientData` if series is shorter than windowSize.
public func rollingCCC<T: Real>(
	_ x: [T], _ y: [T],
	windowSize: Int, step: Int = 1
) throws -> [(startIndex: Int, ccc: CCCResult<T>)] where T: BinaryFloatingPoint {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard windowSize >= 3 else {
		throw BusinessMathError.invalidInput(
			message: "Window size must be at least 3 for CCC",
			value: "\(windowSize)", expectedRange: "[3, +inf)")
	}
	guard step >= 1 else {
		throw BusinessMathError.invalidInput(
			message: "Step must be at least 1",
			value: "\(step)", expectedRange: "[1, +inf)")
	}
	guard x.count >= windowSize else {
		throw BusinessMathError.insufficientData(
			required: windowSize, actual: x.count,
			context: "Series must have at least windowSize observations for rolling CCC")
	}

	var results: [(startIndex: Int, ccc: CCCResult<T>)] = []
	var start = 0

	while start + windowSize <= x.count {
		let xSlice = Array(x[start..<(start + windowSize)])
		let ySlice = Array(y[start..<(start + windowSize)])
		let result = try concordanceCorrelationCoefficient(xSlice, ySlice)
		results.append((startIndex: start, ccc: result))
		start += step
	}

	return results
}

/// Rolling (moving-window) Bland-Altman analysis.
///
/// Slides a fixed-size window across paired measurement series and computes
/// Bland-Altman statistics for each window position. Useful for detecting
/// drift in bias or limits of agreement over time.
///
/// - Parameters:
///   - x: Measurements from method A.
///   - y: Measurements from method B (same length as x).
///   - windowSize: Number of observations in each window (must be >= 2).
///   - step: Number of observations to advance between windows (default: 1).
///
/// - Returns: Array of (startIndex, BlandAltmanResult) tuples for each window.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.invalidInput` if windowSize < 2 or step < 1.
/// - Throws: `BusinessMathError.insufficientData` if series is shorter than windowSize.
public func rollingBlandAltman<T: Real>(
	_ x: [T], _ y: [T],
	windowSize: Int, step: Int = 1
) throws -> [(startIndex: Int, result: BlandAltmanResult<T>)] {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard windowSize >= 2 else {
		throw BusinessMathError.invalidInput(
			message: "Window size must be at least 2 for Bland-Altman",
			value: "\(windowSize)", expectedRange: "[2, +inf)")
	}
	guard step >= 1 else {
		throw BusinessMathError.invalidInput(
			message: "Step must be at least 1",
			value: "\(step)", expectedRange: "[1, +inf)")
	}
	guard x.count >= windowSize else {
		throw BusinessMathError.insufficientData(
			required: windowSize, actual: x.count,
			context: "Series must have at least windowSize observations for rolling Bland-Altman")
	}

	var results: [(startIndex: Int, result: BlandAltmanResult<T>)] = []
	var start = 0

	while start + windowSize <= x.count {
		let xSlice = Array(x[start..<(start + windowSize)])
		let ySlice = Array(y[start..<(start + windowSize)])
		let result = try blandAltman(xSlice, ySlice)
		results.append((startIndex: start, result: result))
		start += step
	}

	return results
}
