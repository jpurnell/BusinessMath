import Foundation
import Numerics

/// Quantile function (inverse CDF) of Student's t-distribution.
///
/// Finds t such that P(T ≤ t | df) = p using bisection search.
///
/// - Parameters:
///   - p: Probability in (0, 1) exclusive.
///   - df: Degrees of freedom (> 0).
/// - Returns: The t value at the given quantile.
/// - Throws: `BusinessMathError.invalidInput` if p ∉ (0,1) or df ≤ 0.
public func tQuantile<T: Real>(p: T, df: Int) throws -> T {
	guard p > T.zero && p < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Probability must be in (0, 1) exclusive",
			value: "\(p)", expectedRange: "(0, 1)")
	}
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, ∞)")
	}

	let half: T = T(1) / T(2)
	if p == half { return T.zero }

	let nu = T(df)
	let shape: T = nu / T(2)

	// The two-sided tail probability, P(|T| > |t|). Taking it from whichever side is
	// small keeps the argument away from 1, where the beta inverse would be inverting
	// a quantity that has lost its digits to the subtraction.
	let twoSidedTail: T = p < half ? T(2) * p : T(2) * (T(1) - p)

	let x: T = try inverseRegularizedIncompleteBeta(p: twoSidedTail, a: shape, b: half)
	guard x > T.zero, x <= T(1) else { return T.nan }

	// x = ν/(ν + t²), so t² = ν(1 − x)/x.
	let complement: T = T(1) - x
	let ratio: T = complement / x
	let magnitude: T = T.sqrt(nu * ratio)

	return p < half ? -magnitude : magnitude
}
