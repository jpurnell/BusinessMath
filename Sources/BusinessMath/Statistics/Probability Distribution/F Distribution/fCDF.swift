import Foundation
import Numerics

/// Cumulative distribution function of the F-distribution.
///
/// Computes P(F ≤ f | df1, df2) using the regularized incomplete beta function.
/// The relationship is: F-CDF = 1 - I_x(df2/2, df1/2) where x = df2/(df2 + df1×f).
///
/// - Parameters:
///   - f: The F-statistic value (f ≥ 0).
///   - df1: Numerator degrees of freedom (> 0).
///   - df2: Denominator degrees of freedom (> 0).
/// - Returns: Probability P(F ≤ f) in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` if f < 0 or df1/df2 ≤ 0.
public func fCDF<T: Real>(f: T, df1: Int, df2: Int) throws -> T {
	guard f >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "F-statistic must be non-negative",
			value: "\(f)", expectedRange: "[0, ∞)")
	}
	guard df1 > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Numerator degrees of freedom must be positive",
			value: "\(df1)", expectedRange: "(0, ∞)")
	}
	guard df2 > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Denominator degrees of freedom must be positive",
			value: "\(df2)", expectedRange: "(0, ∞)")
	}

	if f == T.zero { return T.zero }

	let d1 = T(df1)
	let d2 = T(df2)
	let x = d2 / (d2 + d1 * f)

	let ibeta = try regularizedIncompleteBeta(x: x, a: d2 / T(2), b: d1 / T(2))
	return T(1) - ibeta
}
