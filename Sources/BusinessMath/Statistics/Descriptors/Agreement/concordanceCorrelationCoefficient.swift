import Foundation
import Numerics

/// Result of a concordance correlation coefficient analysis.
public struct CCCResult<T: Real & Sendable>: Sendable, Equatable {
	/// Lin's concordance correlation coefficient in [-1, 1].
	public let ccc: T

	/// Pearson correlation coefficient (precision component).
	public let pearsonR: T

	/// Bias correction factor Cb (accuracy component). CCC = r × Cb.
	public let biasCorrection: T

	/// Lower bound of the confidence interval.
	public let lowerBound: T

	/// Upper bound of the confidence interval.
	public let upperBound: T

	/// Confidence level used.
	public let confidence: T

	/// Number of paired observations.
	public let count: Int
}

/// Lin's concordance correlation coefficient with confidence interval.
///
/// Measures agreement between two measurement methods by evaluating
/// how closely paired observations fall to the 45° identity line.
/// Unlike Pearson's r, CCC penalizes systematic bias between methods.
///
/// CCC = (2 × r × Sx × Sy) / (Sx² + Sy² + (μx - μy)²)
///
/// Equivalently: CCC = r × Cb where Cb is the bias correction factor.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - confidence: Confidence level for the interval (default 0.95).
/// - Returns: `CCCResult` containing CCC, decomposition, and confidence bounds.
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
///           `BusinessMathError.insufficientData` if fewer than 2 observations.
///           `BusinessMathError.divisionByZero` if either series has zero variance.
public func concordanceCorrelationCoefficient<T: Real>(
	_ x: [T], _ y: [T], confidence: T = T(95) / T(100)
) throws -> CCCResult<T> where T: BinaryFloatingPoint {
	guard x.count == y.count else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Arrays must have equal length",
			expected: "\(x.count)", actual: "\(y.count)")
	}
	guard x.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: x.count,
			context: "Concordance correlation requires at least 2 paired observations")
	}

	let n = x.count
	let nT = T(n)

	// Means
	let muX = x.reduce(T.zero, +) / nT
	let muY = y.reduce(T.zero, +) / nT

	// Sample variances (using n-1 denominator for consistency with correlationCoefficient)
	var sxx = T.zero
	var syy = T.zero
	var sxy = T.zero

	for i in 0..<n {
		let dx = x[i] - muX
		let dy = y[i] - muY
		sxx += dx * dx
		syy += dy * dy
		sxy += dx * dy
	}

	guard sxx > T.zero else {
		throw BusinessMathError.divisionByZero(context: "x series has zero variance")
	}
	guard syy > T.zero else {
		throw BusinessMathError.divisionByZero(context: "y series has zero variance")
	}

	// Sample standard deviations
	let sx = T.sqrt(sxx / (nT - T(1)))
	let sy = T.sqrt(syy / (nT - T(1)))

	// Pearson r
	let r = sxy / T.sqrt(sxx * syy)

	// CCC formula: 2 × Sxy / (Sx² + Sy² + (μx - μy)²)
	// Using population-style sums divided by n for the CCC formula (Lin's original)
	let sxPop = sxx / nT
	let syPop = syy / nT
	let sxyPop = sxy / nT
	let meanDiffSq = (muX - muY) * (muX - muY)

	let ccc = (T(2) * sxyPop) / (sxPop + syPop + meanDiffSq)

	// Bias correction factor: Cb = CCC / r
	let cb: T
	if abs(r) < T(sign: .plus, exponent: -50, significand: T(1)) {
		cb = T.zero
	} else {
		cb = ccc / r
	}

	// Confidence interval via Fisher z-transform
	let (lower, upper) = cccConfidenceInterval(
		ccc: ccc, n: n, confidence: confidence)

	return CCCResult(
		ccc: ccc,
		pearsonR: r,
		biasCorrection: cb,
		lowerBound: lower,
		upperBound: upper,
		confidence: confidence,
		count: n
	)
}

/// Short alias for concordance correlation coefficient.
public func linsCCC<T: Real>(
	_ x: [T], _ y: [T], confidence: T = T(95) / T(100)
) throws -> CCCResult<T> where T: BinaryFloatingPoint {
	return try concordanceCorrelationCoefficient(x, y, confidence: confidence)
}

/// Compute confidence interval for CCC using Fisher z-transform.
///
/// z = atanh(CCC), SE ≈ 1/√(n-2), CI in z-space, then back-transform via tanh.
private func cccConfidenceInterval<T: Real>(
	ccc: T, n: Int, confidence: T
) -> (lower: T, upper: T) where T: BinaryFloatingPoint {
	guard n > 2 else {
		return (lower: T(-1), upper: T(1))
	}

	// Fisher z-transform
	// Clamp CCC to avoid atanh(±1) = ±∞
	let clampedCCC = min(max(ccc, T(-1) + T(sign: .plus, exponent: -50, significand: T(1))),
						  T(1) - T(sign: .plus, exponent: -50, significand: T(1)))
	let z = T.atanh(clampedCCC)

	// Approximate SE in z-space (large-sample approximation)
	let se = T(1) / T.sqrt(T(n - 2))

	// Critical z-value for the confidence level
	let zCrit = zScore(ci: confidence)

	// CI in z-space
	let zLower = z - zCrit * se
	let zUpper = z + zCrit * se

	// Back-transform
	let lower = T.tanh(zLower)
	let upper = T.tanh(zUpper)

	return (lower: lower, upper: upper)
}
