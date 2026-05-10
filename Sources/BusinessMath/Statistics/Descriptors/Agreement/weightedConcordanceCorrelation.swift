import Foundation
import Numerics

/// Weighted concordance correlation coefficient with confidence interval.
///
/// Measures agreement between two measurement methods using observation weights.
/// The weighted CCC is defined as:
/// ```
/// CCC_w = (2 * Cov_w(x, y)) / (Var_w(x) + Var_w(y) + (mu_wx - mu_wy)^2)
/// ```
///
/// Uses **population-style** weighted statistics in the CCC formula (Lin's convention).
/// The confidence interval uses the Fisher z-transform with effective sample size
/// `n_eff = (sum(w))^2 / sum(w^2)`.
///
/// - Parameters:
///   - x: First measurement series.
///   - y: Second measurement series (same length as x).
///   - weights: Non-negative weights for each observation.
///   - confidence: Confidence level for the interval (default 0.95).
///
/// - Returns: `CCCResult` containing CCC, decomposition, and confidence bounds.
///
/// - Throws: `BusinessMathError.mismatchedDimensions` if arrays differ in length.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 observations.
/// - Throws: `BusinessMathError.invalidInput` if any weight is negative.
/// - Throws: `BusinessMathError.divisionByZero` if either series has zero weighted
///   variance or if sum of weights is zero.
public func concordanceCorrelationCoefficient<T: Real>(
	_ x: [T], _ y: [T], weights: [T], confidence: T = T(95) / T(100)
) throws -> CCCResult<T> where T: BinaryFloatingPoint {
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
			context: "Weighted CCC requires at least 2 paired observations")
	}
	guard weights.allSatisfy({ $0 >= T.zero }) else {
		throw BusinessMathError.invalidInput(message: "Weights must be non-negative")
	}

	let totalWeight = weights.reduce(T.zero, +)

	guard totalWeight > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Total weight is zero")
	}

	let n = x.count

	// Weighted means
	var sumWX = T.zero
	var sumWY = T.zero
	for i in 0..<n {
		sumWX += weights[i] * x[i]
		sumWY += weights[i] * y[i]
	}
	let muX = sumWX / totalWeight
	let muY = sumWY / totalWeight

	// Population-style weighted variances and covariance (Lin's convention)
	var sxx = T.zero
	var syy = T.zero
	var sxy = T.zero
	for i in 0..<n {
		let dx = x[i] - muX
		let dy = y[i] - muY
		sxx += weights[i] * dx * dx
		syy += weights[i] * dy * dy
		sxy += weights[i] * dx * dy
	}

	let varX = sxx / totalWeight
	let varY = syy / totalWeight
	let covXY = sxy / totalWeight

	guard varX > T.zero else {
		throw BusinessMathError.divisionByZero(context: "x series has zero weighted variance")
	}
	guard varY > T.zero else {
		throw BusinessMathError.divisionByZero(context: "y series has zero weighted variance")
	}

	// CCC formula
	let meanDiffSq = (muX - muY) * (muX - muY)
	let ccc = (T(2) * covXY) / (varX + varY + meanDiffSq)

	// Weighted Pearson r
	let r = covXY / T.sqrt(varX * varY)

	// Bias correction factor: Cb = CCC / r
	let cb: T
	if abs(r) < T(sign: .plus, exponent: -50, significand: T(1)) {
		cb = T.zero
	} else {
		cb = ccc / r
	}

	// Effective sample size for CI: n_eff = (sum(w))^2 / sum(w^2)
	let sumWSq = weights.reduce(T.zero) { acc, w in acc + w * w }
	guard sumWSq > T.zero else {
		throw BusinessMathError.divisionByZero(context: "Sum of squared weights is zero")
	}
	let nEff = (totalWeight * totalWeight) / sumWSq

	// Confidence interval via Fisher z-transform using effective n
	let (lower, upper) = weightedCCCConfidenceInterval(
		ccc: ccc, nEff: nEff, confidence: confidence)

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

/// Compute confidence interval for weighted CCC using Fisher z-transform.
///
/// Uses effective sample size instead of raw n.
private func weightedCCCConfidenceInterval<T: Real>(
	ccc: T, nEff: T, confidence: T
) -> (lower: T, upper: T) where T: BinaryFloatingPoint {
	guard nEff > T(2) else {
		return (lower: T(-1), upper: T(1))
	}

	// Fisher z-transform
	let clampedCCC = min(max(ccc, T(-1) + T(sign: .plus, exponent: -50, significand: T(1))),
						  T(1) - T(sign: .plus, exponent: -50, significand: T(1)))
	let z = T.atanh(clampedCCC)

	// Approximate SE in z-space using effective sample size
	let se = T(1) / T.sqrt(nEff - T(2))

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
