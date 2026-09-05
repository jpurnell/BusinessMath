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

	let d1 = T(df1)
	let d2 = T(df2)
	let shape1: T = d1 / T(2)
	let shape2: T = d2 / T(2)
	let half: T = T(1) / T(2)

	// d₁F/(d₁F + d₂) ~ Beta(d₁/2, d₂/2), so with x that beta's quantile,
	// f = d₂x / (d₁(1 − x)).
	//
	// Above the median that (1 − x) is a subtraction of two numbers near one, and it
	// takes the answer's digits with it. The beta's own symmetry gives the complement
	// directly instead: I⁻¹(1 − p, d₂/2, d₁/2) *is* 1 − x, computed in its own small
	// tail, so the same formula is written with the roles exchanged.
	if p <= half {
		let x: T = try inverseRegularizedIncompleteBeta(p: p, a: shape1, b: shape2)
		guard x > T.zero, x < T(1) else { return x <= T.zero ? T.zero : T.infinity }

		let complement: T = T(1) - x
		let numerator: T = d2 * x
		let denominator: T = d1 * complement
		return numerator / denominator
	}

	let upperTail: T = T(1) - p
	let y: T = try inverseRegularizedIncompleteBeta(p: upperTail, a: shape2, b: shape1)
	guard y > T.zero, y < T(1) else { return y <= T.zero ? T.infinity : T.zero }

	let complement: T = T(1) - y
	let numerator: T = d2 * complement
	let denominator: T = d1 * y
	return numerator / denominator
}
