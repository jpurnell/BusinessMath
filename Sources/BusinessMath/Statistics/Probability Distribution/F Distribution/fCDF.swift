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

	// d₁F/(d₁F + d₂) ~ Beta(d₁/2, d₂/2), so the CDF is that beta evaluated directly.
	//
	// The complementary route — `1 − I_{d₂/(d₂+d₁f)}(d₂/2, d₁/2)` — is the same
	// quantity and is unusable for small `f`: the argument `d₂/(d₂+d₁f)` rounds to
	// within an ulp of 1 and carries none of the information the answer needs. At
	// f = 1.65e-16 with (1, 10) degrees of freedom it returned exactly zero where the
	// answer is 1e-8. This form subtracts nothing anywhere.
	let scaled: T = d1 * f
	let x: T = scaled / (scaled + d2)
	return try regularizedIncompleteBeta(x: x, a: d1 / T(2), b: d2 / T(2))
}
