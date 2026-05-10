import Foundation
import Numerics

/// Regularized incomplete beta function I_x(a, b).
///
/// Computes the ratio of the incomplete beta function to the complete beta function.
/// This is the CDF of the Beta(a, b) distribution evaluated at x, and serves as the
/// building block for F-distribution, t-distribution, and chi-squared CDFs.
///
/// Uses Lentz's continued fraction algorithm (DLMF 8.17.22) with the symmetry
/// relation `I_x(a,b) = 1 - I_{1-x}(b,a)` for numerical stability.
///
/// - Parameters:
///   - x: Upper limit of integration, in [0, 1].
///   - a: First shape parameter (a > 0).
///   - b: Second shape parameter (b > 0).
/// - Returns: I_x(a, b) in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` if x ∉ [0,1] or a,b ≤ 0.
public func regularizedIncompleteBeta<T: Real>(x: T, a: T, b: T) throws -> T {
	guard a > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Shape parameter a must be positive",
			value: "\(a)", expectedRange: "(0, ∞)")
	}
	guard b > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Shape parameter b must be positive",
			value: "\(b)", expectedRange: "(0, ∞)")
	}
	guard x >= T.zero && x <= T(1) else {
		throw BusinessMathError.invalidInput(
			message: "x must be in [0, 1]",
			value: "\(x)", expectedRange: "[0, 1]")
	}

	if x == T.zero { return T.zero }
	if x == T(1) { return T(1) }

	// Use symmetry relation for numerical stability:
	// When x > (a+1)/(a+b+2), the continued fraction converges faster for I_{1-x}(b,a)
	if x > (a + T(1)) / (a + b + T(2)) {
		let complement = try regularizedIncompleteBeta(x: T(1) - x, a: b, b: a)
		return T(1) - complement
	}

	// Compute the prefactor: x^a × (1-x)^b / B(a,b)
	// Work in log space to avoid overflow
	let logPrefactor = a * T.log(x) + b * T.log(T(1) - x) - logBeta(a, b)
	let prefactor = T.exp(logPrefactor)

	// Evaluate continued fraction and divide by a (NR formula: bt * betacf / a)
	let cf = continuedFractionBeta(x: x, a: a, b: b)

	return prefactor * cf / a
}

/// Evaluates the continued fraction for the incomplete beta function
/// using the modified Lentz algorithm (Numerical Recipes §6.4).
///
/// The CF has the form: CF = 1/(1+) d1/(1+) d2/(1+) ...
/// where the first term d₁ = -(a+b)x/(a+1) is handled in initialization.
private func continuedFractionBeta<T: Real>(x: T, a: T, b: T) -> T {
	let maxIterations = 200
	let epsilon = T(sign: .plus, exponent: -52, significand: T(1))
	let tiny = T(sign: .plus, exponent: -100, significand: T(1))

	let qab = a + b
	let qap = a + T(1)
	let qam = a - T(1)

	// Initial setup: first term is 1/(1 - (a+b)*x/(a+1))
	var c = T(1)
	var d = T(1) - qab * x / qap
	if abs(d) < tiny { d = tiny }
	d = T(1) / d
	var h = d

	for m in 1...maxIterations {
		let mT = T(m)
		let m2 = T(2) * mT

		// Even-indexed coefficient: m*(b-m)*x / ((a+2m-1)*(a+2m))
		var aa = mT * (b - mT) * x / ((qam + m2) * (a + m2))

		d = T(1) + aa * d
		if abs(d) < tiny { d = tiny }
		c = T(1) + aa / c
		if abs(c) < tiny { c = tiny }
		d = T(1) / d
		h *= d * c

		// Odd-indexed coefficient: -(a+m)*(a+b+m)*x / ((a+2m)*(a+2m+1))
		aa = -(a + mT) * (qab + mT) * x / ((a + m2) * (qap + m2))

		d = T(1) + aa * d
		if abs(d) < tiny { d = tiny }
		c = T(1) + aa / c
		if abs(c) < tiny { c = tiny }
		d = T(1) / d

		let delta = d * c
		h *= delta

		if abs(delta - T(1)) < epsilon {
			return h
		}
	}

	return h
}
