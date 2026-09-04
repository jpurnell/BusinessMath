import Foundation
import Numerics

/// Cumulative distribution function of the chi-squared distribution (exact).
///
/// A chi-squared variable with *ν* degrees of freedom is a gamma variable with shape
/// *ν*/2 and scale 2, so its CDF is the regularized lower incomplete gamma function
/// evaluated at half the statistic:
///
/// ```
/// P(X ≤ x | ν) = P(ν/2, x/2)
/// ```
///
/// The work is done by ``regularizedLowerIncompleteGamma(a:x:)``, which chooses
/// between a series and a continued fraction according to where `x` sits relative to
/// the shape. This function contributes the change of variable and the validation.
///
/// - Parameters:
///   - x: The chi-squared statistic value (x ≥ 0).
///   - df: Degrees of freedom (> 0).
/// - Returns: Probability P(X ≤ x) in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` if x < 0 or df ≤ 0.
public func chiSquaredCDF<T: Real>(x: T, df: Int) throws -> T {
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

	if x == T.zero { return T.zero }

	let a = T(df) / T(2)
	let z = x / T(2)

	return regularizedLowerIncompleteGamma(a: a, x: z)
}
