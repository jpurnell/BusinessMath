import Foundation
import Numerics

/// Cumulative distribution function of the chi-squared distribution (exact).
///
/// Computes P(X ≤ x | df) using the regularized incomplete beta function.
/// The chi-squared CDF is related to the regularized lower incomplete gamma function,
/// which in turn is a special case of the incomplete beta:
/// P(X ≤ x | k) = 1 - I_{exp(-x/2)}(k/2, ...) or equivalently via F-distribution identity.
///
/// Uses the identity: chi-squared with k df is F(k, ∞) scaled, or equivalently
/// uses the gamma-beta relationship: P(X ≤ x | k) = I_{x/(x+k)}(k/2, k/2) is NOT right.
/// Correct: P(X ≤ x | k) = regularizedGammaP(k/2, x/2)
///           = 1 - I_{exp(-x/2)}... actually let's use the series/CF for gamma.
///
/// For integer and half-integer df, we use the incomplete beta via the identity:
/// chiSquaredCDF(x, df) = 1 - regularizedIncompleteBeta(x: exp(-x/2), a: df/2, b: 0.5)
/// Actually the correct relationship is:
/// chiSquaredCDF(x, k) = fCDF(f: x/k * large_df / 1, df1: k, df2: large_df) ... no.
///
/// The correct formula: chi-squared CDF = regularized lower incomplete gamma function
/// P(k/2, x/2) where P(a, x) = γ(a, x) / Γ(a)
///
/// We implement this directly using a series expansion for the regularized lower
/// incomplete gamma function.
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

/// Regularized lower incomplete gamma function P(a, x) = γ(a, x) / Γ(a).
///
/// Uses the series representation for x < a+1 and the continued fraction
/// (complementary) for x ≥ a+1.
private func regularizedLowerIncompleteGamma<T: Real>(a: T, x: T) -> T {
	if x < a + T(1) {
		return gammaSeries(a: a, x: x)
	} else {
		return T(1) - gammaContinuedFraction(a: a, x: x)
	}
}

/// Series expansion for the regularized lower incomplete gamma: P(a, x)
/// P(a, x) = e^(-x) × x^a × Σ_{n=0}^∞ x^n / (Γ(a+1+n)/Γ(a))
///         = e^(-x) × x^a / Γ(a) × Σ_{n=0}^∞ Γ(a) × x^n / Γ(a+1+n)
///         = e^(-x) × x^a / Γ(a) × (1/a + x/(a(a+1)) + x²/(a(a+1)(a+2)) + ...)
private func gammaSeries<T: Real>(a: T, x: T) -> T {
	let maxIterations = 200
	let epsilon = T(sign: .plus, exponent: -52, significand: T(1))

	var sum = T(1) / a
	var term = T(1) / a

	for n in 1...maxIterations {
		let nT = T(n)
		term *= x / (a + nT)
		sum += term
		if abs(term) < abs(sum) * epsilon {
			break
		}
	}

	let logPrefix = a * T.log(x) - x - T.logGamma(a)
	return sum * T.exp(logPrefix)
}

/// Continued fraction for the regularized upper incomplete gamma: Q(a, x) = 1 - P(a, x)
/// Uses Lentz's algorithm on the CF representation of Q(a, x).
private func gammaContinuedFraction<T: Real>(a: T, x: T) -> T {
	let maxIterations = 200
	let epsilon = T(sign: .plus, exponent: -52, significand: T(1))
	let tiny = T(sign: .plus, exponent: -100, significand: T(1))

	var b = x + T(1) - a
	var c = T(1) / tiny
	var d = T(1) / b
	var h = d

	for i in 1...maxIterations {
		let iT = T(i)
		let an = -iT * (iT - a)
		b += T(2)
		d = an * d + b
		if abs(d) < tiny { d = tiny }
		c = b + an / c
		if abs(c) < tiny { c = tiny }
		d = T(1) / d
		let delta = d * c
		h *= delta
		if abs(delta - T(1)) < epsilon {
			break
		}
	}

	let logPrefix = a * T.log(x) - x - T.logGamma(a)
	return T.exp(logPrefix) * h
}
