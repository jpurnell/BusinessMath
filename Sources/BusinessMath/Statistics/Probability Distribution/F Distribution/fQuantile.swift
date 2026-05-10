import Foundation
import Numerics

/// Quantile function (inverse CDF) of the F-distribution.
///
/// Finds f such that P(F ≤ f | df1, df2) = p using bisection with Newton refinement.
///
/// - Parameters:
///   - p: Probability in (0, 1) exclusive.
///   - df1: Numerator degrees of freedom (> 0).
///   - df2: Denominator degrees of freedom (> 0).
/// - Returns: The f value at the given quantile.
/// - Throws: `BusinessMathError.invalidInput` if p ∉ (0,1) or df1/df2 ≤ 0.
public func fQuantile<T: Real>(p: T, df1: Int, df2: Int) throws -> T {
	guard p > T.zero && p < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Probability must be in (0, 1) exclusive",
			value: "\(p)", expectedRange: "(0, 1)")
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

	// Bisection search
	var lo = T(1) / T(10000)
	var hi = T(1000)
	let tolerance = T(sign: .plus, exponent: -40, significand: T(1))

	// Expand upper bound if needed
	while (try fCDF(f: hi, df1: df1, df2: df2)) < p {
		hi *= T(2)
	}

	for _ in 0..<100 {
		let mid = (lo + hi) / T(2)
		let cdf: T = try fCDF(f: mid, df1: df1, df2: df2)

		if abs(cdf - p) < tolerance {
			return mid
		}

		if cdf < p {
			lo = mid
		} else {
			hi = mid
		}

		if (hi - lo) < tolerance * mid {
			return mid
		}
	}

	return (lo + hi) / T(2)
}
