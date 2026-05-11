import Foundation
import Numerics

/// Cumulative distribution function of the non-central chi-squared distribution.
///
/// Computes P(X <= x | df, lambda) where lambda is the non-centrality parameter.
/// Uses the Poisson-weighted series expansion (Ding 1992):
///
/// P(X <= x | df, lambda) = sum_{j=0}^{inf} e^{-lambda/2} * (lambda/2)^j / j! * P(chi^2_{df+2j} <= x)
///
/// where P(chi^2_k <= x) is the central chi-squared CDF with k degrees of freedom.
///
/// For large non-centrality parameters (lambda > 100), a normal approximation is used:
/// X ~ N(df + lambda, 2 * (df + 2 * lambda)) approximately.
///
/// - Parameters:
///   - x: Value at which to evaluate (x >= 0).
///   - df: Degrees of freedom (> 0).
///   - lambda: Non-centrality parameter (>= 0). When lambda = 0, equals central chi-squared CDF.
/// - Returns: P(X <= x) in [0, 1].
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if x < 0, df <= 0, or lambda < 0.
public func nonCentralChiSquaredCDF<T: Real>(x: T, df: Int, lambda: T) throws -> T {
	guard x >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Chi-squared statistic must be non-negative",
			value: "\(x)", expectedRange: "[0, inf)")
	}
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, inf)")
	}
	guard lambda >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Non-centrality parameter must be non-negative",
			value: "\(lambda)", expectedRange: "[0, inf)")
	}

	// Central case: delegate to central chi-squared CDF
	if lambda == T.zero {
		return try chiSquaredCDF(x: x, df: df)
	}

	if x == T.zero { return T.zero }

	// Normal approximation for large lambda
	let lambdaThreshold = T(100)
	if lambda > lambdaThreshold {
		let mean = T(df) + lambda
		let variance = T(2) * (T(df) + T(2) * lambda)
		let stdDev = T.sqrt(variance)
		guard stdDev > T.zero else { return T.zero }
		return normalCDF(x: x, mean: mean, stdDev: stdDev)
	}

	// Poisson-weighted sum of central chi-squared CDFs
	let halfLambda = lambda / T(2)
	let maxIterations = 500
	let epsilon = T(sign: .plus, exponent: -50, significand: T(1))

	// Start with j=0: weight = exp(-halfLambda)
	var logWeight = -halfLambda
	var sum = T.zero

	for j in 0..<maxIterations {
		let adjustedDf = df + 2 * j
		let centralCDF = try chiSquaredCDF(x: x, df: adjustedDf)

		let weight = T.exp(logWeight)
		let contribution = weight * centralCDF

		sum += contribution

		// Check convergence: when the Poisson weight is negligibly small
		if j > 0 && abs(contribution) < epsilon * abs(sum) {
			break
		}

		// Update log weight for next term: logWeight += log(halfLambda) - log(j+1)
		logWeight += T.log(halfLambda) - T.log(T(j + 1))
	}

	// Clamp to [0, 1]
	return min(max(sum, T.zero), T(1))
}
