//
//  inverseRegularizedIncompleteBeta.swift
//  BusinessMath
//
//  Created 2026-09-04 as part of the distribution-contract phase.
//

import Foundation
import Numerics

/// The inverse of the regularized incomplete beta function: solves `I_x(a, b) = p` for `x`.
///
/// This is the quantile function of the Beta(a, b) distribution, and every
/// distribution that expresses its CDF through I inherits its quantile from here —
///
/// | Distribution | Quantile in terms of this |
/// |---|---|
/// | Beta(*a*, *b*) | `I⁻¹(p, a, b)` directly |
/// | F(*d₁*, *d₂*) | a rational map of `I⁻¹(p, d₁/2, d₂/2)` |
/// | Student's *t*(*ν*) | via the symmetric `I⁻¹(2p, ν/2, ½)` |
/// | Pearson VI, Johnson SB | change of variable on the beta prime |
///
/// ## Method
///
/// A closed-form initial estimate followed by **Newton's method**, each step
/// safeguarded by a bracket that bisection tightens whenever a Newton step would
/// leave `(0, 1)` or leave the bracket. The estimate is the Abramowitz & Stegun
/// 26.5.22 normal approximation for shapes above 1, and a power-law guess from the
/// density's endpoint behaviour otherwise.
///
/// The bracket is not optional. I is flat to many digits near 0 and 1 for skewed
/// shape pairs — `I⁻¹(1e-10, 2, 50)` and `I⁻¹(1 − 1e-10, 50, 2)` are both in regions
/// where an unguarded Newton step overshoots the unit interval on the first move.
///
/// ## Accuracy
///
/// Agrees with `scipy.special.betaincinv` to better than 1e-9 relative across the
/// shape pairs and probabilities in `SpecialFunctionsTests`, tails included. Held to
/// a relative tolerance as a root-found quantity, per §15.1 of the
/// distribution-contract proposal.
///
/// - Parameters:
///   - p: The probability, in the open interval (0, 1).
///   - a: First shape parameter. Must be positive.
///   - b: Second shape parameter. Must be positive.
/// - Returns: The `x` in [0, 1] for which `I_x(a, b) == p`.
/// - Throws: `BusinessMathError.invalidInput` if `p` is outside (0, 1) or either
///   shape is not positive.
///
/// ## See Also
/// - ``regularizedIncompleteBeta(x:a:b:)``
public func inverseRegularizedIncompleteBeta<T: Real>(p: T, a: T, b: T) throws -> T {
	guard !p.isNaN, p > T.zero, p < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Probability must lie in the open interval (0, 1)",
			value: "\(p)", expectedRange: "(0, 1)")
	}
	guard !a.isNaN, a.isFinite, a > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Shape parameter a must be positive",
			value: "\(a)", expectedRange: "(0, ∞)")
	}
	guard !b.isNaN, b.isFinite, b > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Shape parameter b must be positive",
			value: "\(b)", expectedRange: "(0, ∞)")
	}

	// Above the median, solve the mirrored problem. I is symmetric under
	// `I_x(a, b) = 1 − I_{1−x}(b, a)`, so inverting the small tail and reflecting
	// gives the same root while keeping the residual away from the cancellation that
	// destroys `I_x(a, b) − p` when both are within 1e-10 of 1. The recursion is one
	// level deep by construction: the mirrored probability is below the median, so
	// this guard cannot be taken twice.
	if p > decimal(5, over: 10) {
		let complementProbability: T = T(1) - p
		let mirrored: T = try inverseRegularizedIncompleteBeta(p: complementProbability,
															   a: b, b: a)
		return T(1) - mirrored
	}

	var low: T = T.zero
	var high: T = T(1)
	var x: T = initialBetaQuantileEstimate(p: p, a: a, b: b)

	let epsilon = T(sign: .plus, exponent: -50, significand: T(1))
	let logBeta: T = betaLogNormalization(a: a, b: b)
	let aMinusOne: T = a - T(1)
	let bMinusOne: T = b - T(1)

	for _ in 0..<200 {
		if x <= low || x >= high {
			let span: T = high - low
			let half: T = span / T(2)
			x = low + half
		}

		let value: T = try regularizedIncompleteBeta(x: x, a: a, b: b)
		let error: T = value - p
		if error > T.zero { high = x } else { low = x }

		// The Beta density: x^(a-1) (1-x)^(b-1) / B(a, b), in log space so that a
		// shape of 50 against an x of 1e-8 does not underflow before the division.
		let complement: T = T(1) - x
		let logLeft: T = aMinusOne * T.log(x)
		let logRight: T = bMinusOne * T.log(complement)
		let logDensity: T = logLeft + logRight - logBeta
		let density: T = T.exp(logDensity)

		guard density > T.zero, density.isFinite else {
			let span: T = high - low
			let half: T = span / T(2)
			x = low + half
			if span < epsilon { break }
			continue
		}

		let step: T = error / density
		let candidate: T = x - step
		let insideBracket = candidate > low && candidate < high
		let tolerance: T = epsilon * Swift.max(x, epsilon)

		// Convergence before bisection — see the note in
		// ``inverseRegularizedLowerIncompleteGamma(p:a:)``. An exact hit makes
		// `candidate == x == low`, which the strict comparison rejects; bisecting
		// first would throw the answer away on the one iteration that found it.
		if abs(step) < tolerance {
			if insideBracket { x = candidate }
			break
		}

		if insideBracket {
			x = candidate
		} else {
			let span: T = high - low
			let half: T = span / T(2)
			x = low + half
		}
	}

	return x
}

/// `log B(a, b)` — the log of the complete beta function, the density's normalizer.
private func betaLogNormalization<T: Real>(a: T, b: T) -> T {
	let logA: T = T.logGamma(a)
	let logB: T = T.logGamma(b)
	let logSum: T = T.logGamma(a + b)
	return logA + logB - logSum
}

/// A closed-form starting point for the Newton iteration.
///
/// Abramowitz & Stegun 26.5.22 for shapes above 1 — a normal approximation in a
/// transformed variable — and the endpoint power law otherwise, where the density
/// diverges and the normal approximation is worthless. As with the gamma inverse,
/// the estimate only has to land inside `(0, 1)`; the bracket handles the rest.
private func initialBetaQuantileEstimate<T: Real>(p: T, a: T, b: T) -> T {
	if a >= T(1), b >= T(1) {
		let tail: T = p < decimal(5, over: 10) ? p : T(1) - p
		let logTail: T = T.log(tail)
		let t: T = T.sqrt(T(-2) * logTail)

		let numerator: T = decimal(230_753, over: 100_000) + t * decimal(27_061, over: 100_000)
		let innerDenominator: T = decimal(99_229, over: 100_000) + t * decimal(4_481, over: 100_000)
		let denominator: T = T(1) + t * innerDenominator
		var z: T = numerator / denominator - t
		if p < decimal(5, over: 10) { z = -z }

		// A&S 26.5.22: λ = (z² − 3)/6, then a symmetric correction in the two shapes.
		let zSquared: T = z * z
		let lambda: T = (zSquared - T(3)) / T(6)

		let twoAMinusOne: T = T(2) * a - T(1)
		let twoBMinusOne: T = T(2) * b - T(1)
		let reciprocalA: T = T(1) / twoAMinusOne
		let reciprocalB: T = T(1) / twoBMinusOne

		let harmonic: T = reciprocalA + reciprocalB
		let h: T = T(2) / harmonic

		let difference: T = reciprocalA - reciprocalB
		let lambdaTerm: T = lambda + T(5) / T(6) - T(2) / (T(3) * h)
		let correction: T = difference * lambdaTerm

		let hOffset: T = h + T(1) / T(3)
		let zRoot: T = z * T.sqrt(hOffset)
		let exponent: T = T(2) * (zRoot - correction)

		let ratio: T = a / (a + b * T.exp(exponent))
		return clampToUnitInterior(ratio)
	}

	// One shape below 1: the density diverges at that endpoint, so the normal
	// approximation is worthless. Match the leading term of I instead.
	//
	//   near 0:  I_x(a, b) ≈ x^a / (a · B(a, b))
	//   near 1:  1 − I_x(a, b) ≈ (1−x)^b / (b · B(a, b))
	//
	// Inverting whichever tail `p` sits in. Which side is chosen matters little —
	// the bracket corrects a poor guess — but it must land inside (0, 1).
	let logBetaTerm: T = betaLogNormalization(a: a, b: b)
	let completeBeta: T = T.exp(logBetaTerm)

	if p < decimal(5, over: 10) {
		let scaled: T = p * a
		let target: T = scaled * completeBeta
		let reciprocalShape: T = T(1) / a
		return clampToUnitInterior(T.pow(target, reciprocalShape))
	}

	let complementProbability: T = T(1) - p
	let scaled: T = complementProbability * b
	let target: T = scaled * completeBeta
	let reciprocalShape: T = T(1) / b
	let fromTop: T = T.pow(target, reciprocalShape)
	return clampToUnitInterior(T(1) - fromTop)
}


/// Keeps an estimate strictly inside `(0, 1)`, where the density is defined.
private func clampToUnitInterior<T: Real>(_ x: T) -> T {
	let floor = T(sign: .plus, exponent: -40, significand: T(1))
	let ceiling: T = T(1) - floor
	if !x.isFinite || x.isNaN { return decimal(5, over: 10) }
	if x < floor { return floor }
	if x > ceiling { return ceiling }
	return x
}
