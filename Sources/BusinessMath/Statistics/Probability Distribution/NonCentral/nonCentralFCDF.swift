import Foundation
import Numerics

/// Cumulative distribution function of the non-central F-distribution.
///
/// Computes P(F <= f | d1, d2, lambda) using the Poisson-weighted mixture:
///
/// P(F <= f | d1, d2, lambda) = sum_{j=0}^{inf} e^{-lambda/2} * (lambda/2)^j / j! * I_x(d1/2 + j, d2/2)
///
/// where x = d1 * f / (d1 * f + d2) and I_x is the regularized incomplete beta function.
///
/// When lambda = 0, this reduces to the central F CDF.
///
/// - Parameters:
///   - f: Value at which to evaluate (f >= 0).
///   - df1: Numerator degrees of freedom (> 0).
///   - df2: Denominator degrees of freedom (> 0).
///   - lambda: Non-centrality parameter (>= 0).
/// - Returns: P(F <= f) in [0, 1].
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if f < 0, df1/df2 <= 0, or lambda < 0.
public func nonCentralFCDF<T: Real>(f: T, df1: Int, df2: Int, lambda: T) throws -> T {
	guard f >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "F-statistic must be non-negative",
			value: "\(f)", expectedRange: "[0, inf)")
	}
	guard df1 > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Numerator degrees of freedom must be positive",
			value: "\(df1)", expectedRange: "(0, inf)")
	}
	guard df2 > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Denominator degrees of freedom must be positive",
			value: "\(df2)", expectedRange: "(0, inf)")
	}
	guard lambda >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Non-centrality parameter must be non-negative",
			value: "\(lambda)", expectedRange: "[0, inf)")
	}

	// Central case: delegate to central F CDF
	if lambda == T.zero {
		return try fCDF(f: f, df1: df1, df2: df2)
	}

	if f == T.zero { return T.zero }

	let d1 = T(df1)
	let d2 = T(df2)
	let x = d1 * f / (d1 * f + d2)

	// Poisson-weighted sum of regularized incomplete beta terms
	let halfLambda = lambda / T(2)
	let maxIterations = 500
	let epsilon = T(sign: .plus, exponent: -50, significand: T(1))

	var logWeight = -halfLambda
	var sum = T.zero

	for j in 0..<maxIterations {
		let a = d1 / T(2) + T(j)
		let b = d2 / T(2)

		let betaTerm = try regularizedIncompleteBeta(x: x, a: a, b: b)
		let weight = T.exp(logWeight)
		let contribution = weight * betaTerm

		sum += contribution

		// Check convergence
		if j > 0 && abs(contribution) < epsilon * abs(sum) {
			break
		}

		// Update log weight for next term
		logWeight += T.log(halfLambda) - T.log(T(j + 1))
	}

	return min(max(sum, T.zero), T(1))
}
