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
/// Newton's method inside a bracket, with bisection whenever a Newton step would leave
/// it.
///
/// **Every quantity here is derived.** The textbook opening — Abramowitz & Stegun
/// 26.5.22, a normal approximation in a transformed variable — needs a rational fit to
/// the normal quantile and a handful of fitted constants besides. None of them can be
/// derived; they are curve-fit output.
///
/// None of them is needed either. The support of a Beta variate is `[0, 1]` by
/// definition, so the bracket requires no search whatsoever, and the iteration starts
/// at the distribution's own **mean, `a/(a+b)`** — which follows from the definition in
/// one line. What the fitted estimate buys is a few iterations, and what it costs is
/// several numbers a reader has to take on trust.
///
/// ## Accuracy
///
/// Agrees with `scipy.special.betaincinv` to better than 1e-9 relative across the shape
/// pairs and probabilities in `SpecialFunctionsTests`, tails included. Held to a
/// relative tolerance as a root-found quantity, per §15.1 of the distribution-contract
/// proposal.
///
/// - Parameters:
///   - p: The probability, in the open interval (0, 1).
///   - a: First shape parameter. Must be positive.
///   - b: Second shape parameter. Must be positive.
/// - Returns: The `x` in [0, 1] for which `I_x(a, b) == p`.
/// - Throws: `BusinessMathError.invalidInput` if `p` is outside (0, 1) or either shape
///   is not positive.
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
	// `I_x(a, b) = 1 − I_{1−x}(b, a)`, so inverting the small tail and reflecting gives
	// the same root while keeping the residual away from the cancellation that destroys
	// `I_x(a, b) − p` when both are within 1e-10 of 1. The recursion is one level deep
	// by construction: the mirrored probability is below the median, so this guard
	// cannot be taken twice.
	let median: T = T(1) / T(2)
	if p > median {
		let complementProbability: T = T(1) - p
		let mirrored: T = try inverseRegularizedIncompleteBeta(p: complementProbability,
															   a: b, b: a)
		return T(1) - mirrored
	}

	// The support is [0, 1], so the bracket is the support and needs no search. The
	// iteration starts at the distribution's mean.
	var low: T = T.zero
	var high: T = T(1)
	var x: T = a / (a + b)

	// Convergence is measured in ulps of the running estimate, so the same code is
	// right for Float and for Double. The factor of four is the slack a safeguarded
	// iteration needs: the residual, the density and the division each cost up to half
	// an ulp, so demanding a step below one ulp would loop until the cap without ever
	// improving the answer.
	let relativeTolerance: T = T.ulpOfOne * T(4)
	let logBeta: T = betaLogNormalization(a: a, b: b)
	let aMinusOne: T = a - T(1)
	let bMinusOne: T = b - T(1)
	let iterationLimit = bisectionStepsToFullPrecision(of: T.self)

	for _ in 0..<iterationLimit {
		let value: T = try regularizedIncompleteBeta(x: x, a: a, b: b)
		let error: T = value - p
		if error > T.zero { high = x } else { low = x }

		// The Beta density: x^(a−1)(1−x)^(b−1) / B(a, b), in log space so that a shape
		// of 50 against an x of 1e-8 does not underflow before the division.
		let complement: T = T(1) - x
		let logLeft: T = aMinusOne * T.log(x)
		let logRight: T = bMinusOne * T.log(complement)
		let logDensity: T = logLeft + logRight - logBeta
		let density: T = T.exp(logDensity)

		var step: T = T.nan
		if density > T.zero, density.isFinite {
			step = error / density
		}

		let candidate: T = x - step
		let insideBracket = candidate > low && candidate < high
		let tolerance: T = relativeTolerance * Swift.max(x, T.ulpOfOne)

		// Convergence before bisection — see the note in
		// ``inverseRegularizedLowerIncompleteGamma(p:a:)``. An exact hit makes
		// `candidate == x == low`, which the strict comparison rejects; bisecting first
		// would throw the answer away on the one iteration that found it.
		if insideBracket, abs(step) < tolerance {
			return candidate
		}

		if insideBracket {
			x = candidate
		} else {
			let span: T = high - low
			let half: T = span / T(2)
			x = low + half
			if span < tolerance { break }
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
