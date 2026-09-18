import Foundation
import Numerics

/// Probability density function of the chi-squared distribution.
///
/// ```
/// f(x | ν) = x^(ν/2 − 1) · e^(−x/2) / (2^(ν/2) · Γ(ν/2))
/// ```
///
/// The companion to ``chiSquaredCDF(x:df:)``, and the function this module did not have.
/// `chi2pdf(x:dF:)` was named for it and computed something else — see that function's
/// deprecation note.
///
/// ## Assembled in logs
///
/// The closed form has `2^(ν/2) · Γ(ν/2)` beneath it, and both halves overflow a `Double`
/// long before the density does: at ν = 400 the denominator carries `2^200 · Γ(200)` while
/// the answer is an ordinary number near 0.02. Working in logs and exponentiating once at
/// the end keeps the whole range available, which is the same reason
/// ``regularizedLowerIncompleteGamma(a:x:)`` and `DistributionT.pdf(_:)` do it.
///
/// ## At zero, three answers
///
/// The density at the left edge of the support depends on the degrees of freedom, and the
/// cases genuinely differ rather than being a boundary convention:
///
/// - **ν < 2** — unbounded. `x^(ν/2 − 1)` has a negative exponent, so the limit does not
///   exist, and this throws rather than returning a number somebody would plot.
/// - **ν = 2** — exactly ½, from the exponential form.
/// - **ν > 2** — zero.
///
/// - Parameters:
///   - x: The chi-squared statistic value (x ≥ 0).
///   - df: Degrees of freedom (> 0).
/// - Returns: The density at `x`, which is non-negative.
/// - Throws: `BusinessMathError.invalidInput` if `x < 0`, `df ≤ 0`, or the density is
///   unbounded at the point asked for.
public func chiSquaredPDF<T: Real>(x: T, df: Int) throws -> T {
	guard x >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Chi-squared statistic must be non-negative",
			value: "\(x)", expectedRange: "[0, ∞)")
	}
	guard df > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Degrees of freedom must be positive",
			value: "\(df)", expectedRange: "(0, ∞)")
	}

	let shape: T = T(df) / T(2)

	if x == T.zero {
		if df > 2 { return T.zero }
		if df == 2 { return T(1) / T(2) }
		throw BusinessMathError.invalidInput(
			message: "The chi-squared density is unbounded at zero below two degrees of freedom",
			value: "x = 0, df = \(df)", expectedRange: "(0, ∞)")
	}

	let logDensity: T = (shape - T(1)) * T.log(x)
		- x / T(2)
		- shape * T.log(T(2))
		- T.logGamma(shape)
	return T.exp(logDensity)
}
