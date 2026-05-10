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

	// Use symmetry: if p < 0.5, compute -tQuantile(1-p, df)
	if p < T(1) / T(2) {
		let upper = try tQuantile(p: T(1) - p, df: df)
		return -upper
	}

	// Bisection for p >= 0.5 (result is non-negative)
	var lo = T.zero
	var hi = T(100)
	let tolerance = T(sign: .plus, exponent: -40, significand: T(1))

	// Expand upper bound if needed
	while (try tCDF(t: hi, df: df)) < p {
		hi *= T(2)
	}

	for _ in 0..<100 {
		let mid = (lo + hi) / T(2)
		let cdf: T = try tCDF(t: mid, df: df)

		if abs(cdf - p) < tolerance {
			return mid
		}

		if cdf < p {
			lo = mid
		} else {
			hi = mid
		}

		if (hi - lo) < tolerance {
			return mid
		}
	}

	return (lo + hi) / T(2)
}
