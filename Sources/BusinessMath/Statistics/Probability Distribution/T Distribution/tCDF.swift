import Foundation
import Numerics

/// Cumulative distribution function of Student's t-distribution.
///
/// Computes P(T ≤ t | ν) using the regularized incomplete beta function.
/// The relationship is: tCDF(t, ν) = 1 - ½ × I_x(ν/2, ½) where x = ν/(ν + t²),
/// adjusted for sign.
///
/// - Parameters:
///   - t: The t-statistic value (any real number).
///   - df: Degrees of freedom (> 0).
/// - Returns: Probability P(T ≤ t) in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` if df ≤ 0.
public func tCDF<T: Real>(t: T, df: Int) throws -> T {
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, ∞)")
	}

	if t == T.zero { return T(1) / T(2) }

	let nu = T(df)
	let x = nu / (nu + t * t)

	let ibeta = try regularizedIncompleteBeta(x: x, a: nu / T(2), b: T(1) / T(2))

	if t > T.zero {
		return T(1) - ibeta / T(2)
	} else {
		return ibeta / T(2)
	}
}
