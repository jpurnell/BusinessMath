//
//  inverseRegularizedLowerIncompleteGamma.swift
//  BusinessMath
//
//  Created 2026-09-04 as part of the distribution-contract phase.
//

import Foundation
import Numerics

/// The inverse of the regularized lower incomplete gamma function: solves `P(a, x) = p` for `x`.
///
/// This is the quantile function of a unit-scale gamma distribution, and through a
/// change of variable it is the quantile of every distribution built on P —
///
/// | Distribution | Quantile in terms of this |
/// |---|---|
/// | Gamma(shape *k*, scale *θ*) | `θ · P⁻¹(p, k)` |
/// | Erlang(*k*, *β*) | `β · P⁻¹(p, k)` |
/// | Chi-squared(*ν*) | `2 · P⁻¹(p, ν/2)` |
///
/// ## Method
///
/// Halley's method inside a bracket, with bisection whenever a Halley step would
/// leave it.
///
/// **Every quantity here is derived.** The textbook treatments open with a fitted
/// initial estimate — Wilson–Hilferty over a rational approximation to the normal
/// quantile, four or five decimal coefficients from a minimax fit. Those coefficients
/// cannot be derived from anything; they are the output of a curve fit, and reciting
/// them here would put five unexplainable numbers in a library that has no other kind.
///
/// They are also unnecessary. Their only job is to start the iteration somewhere
/// reasonable, and a bracket does that job with a number the distribution supplies
/// itself: **its mean, which for unit scale is the shape `a`.** Zero is always a valid
/// lower bound, because `P(a, 0) = 0` for every shape, so the bracket needs no lower
/// search at all — only doubling upward from the mean until the residual changes sign.
/// The iteration then converges from a worse starting point at the cost of a few extra
/// steps, and the code contains nothing a reader cannot check.
///
/// ## Accuracy
///
/// Agrees with `scipy.special.gammaincinv` to better than 1e-9 relative across shapes
/// from 0.5 to 50 and probabilities from 1e-10 to 1 − 1e-10, tails included. This is a
/// root-found quantity and is held to a relative rather than absolute tolerance, as
/// permitted by §15.1 of the distribution-contract proposal.
///
/// - Parameters:
///   - p: The probability, in the open interval (0, 1). The endpoints are excluded
///     because `P⁻¹(0, a)` is 0 only in the limit and `P⁻¹(1, a)` is infinite.
///   - a: The shape parameter. Must be positive.
/// - Returns: The `x` for which `P(a, x) == p`.
/// - Throws: `BusinessMathError.invalidInput` if `p` is outside (0, 1) or `a` is not positive.
///
/// ## See Also
/// - ``regularizedLowerIncompleteGamma(a:x:)``
/// - ``regularizedUpperIncompleteGamma(a:x:)``
public func inverseRegularizedLowerIncompleteGamma<T: Real>(p: T, a: T) throws -> T {
	guard !p.isNaN, p > T.zero, p < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Probability must lie in the open interval (0, 1)",
			value: "\(p)", expectedRange: "(0, 1)")
	}
	guard !a.isNaN, a.isFinite, a > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Shape parameter must be positive",
			value: "\(a)", expectedRange: "(0, ∞)")
	}

	// Above the median, iterate on Q(a, x) = 1 − p rather than P(a, x) = p. The two
	// are the same equation, but the residual `P(a, x) − p` subtracts two numbers that
	// are both within 1e-10 of 1, which leaves roughly six significant digits of a
	// quantity Q computes in full. The tail is where a risk model reads a quantile, so
	// this is not a corner case.
	let median: T = T(1) / T(2)
	let useUpperTail = p > median
	let target: T = useUpperTail ? T(1) - p : p

	// The bracket. `P(a, 0) = 0` for every shape, so zero is a lower bound without
	// any search; the residual there is `-target`, which is negative by construction.
	// The upper end starts at the distribution's mean — `a`, for unit scale — and
	// doubles until the residual changes sign.
	var low: T = T.zero
	var high: T = a
	var expansions = 0
	let doublingLimit = exponentRangeInDoublings(of: T.self)
	while expansions < doublingLimit {
		let residual = gammaResidual(a: a, x: high, target: target, useUpperTail: useUpperTail)
		if residual >= T.zero { break }
		low = high
		high *= T(2)
		expansions += 1
	}

	// Convergence is measured in ulps of the running estimate rather than against a
	// fixed epsilon, so the same code is right for Float and for Double.
	// Convergence is measured in ulps of the running estimate, so the same code is
	// right for Float and for Double. The factor of four is the slack a safeguarded
	// iteration needs: the residual, the density and the division each cost up to half
	// an ulp, so demanding a step below one ulp would loop until the cap without ever
	// improving the answer.
	let relativeTolerance: T = T.ulpOfOne * T(4)
	let logGammaA: T = T.logGamma(a)
	let shapeMinusOne: T = a - T(1)
	var x: T = low + (high - low) / T(2)

	let iterationLimit = bisectionStepsToFullPrecision(of: T.self)
	for _ in 0..<iterationLimit {
		let error: T = gammaResidual(a: a, x: x, target: target, useUpperTail: useUpperTail)
		if error > T.zero { high = x } else { low = x }

		// The density of the unit-scale gamma: P′(a, x) = x^(a−1) e^(−x) / Γ(a),
		// formed in log space so a large shape cannot overflow the power.
		let logPower: T = shapeMinusOne * T.log(x)
		let logDensity: T = logPower - x - logGammaA
		let density: T = T.exp(logDensity)

		var step: T
		if density > T.zero, density.isFinite {
			let newtonStep: T = error / density

			// Halley's correction. P″/P′ is (a−1)/x − 1, and the product is capped at
			// one so a large Newton step cannot drive the denominator through zero and
			// flip the step's sign.
			let curvature: T = shapeMinusOne / x - T(1)
			let rawFactor: T = newtonStep * curvature
			let clampedFactor: T = Swift.min(T(1), rawFactor)
			let halved: T = clampedFactor / T(2)
			let denominator: T = T(1) - halved
			step = denominator == T.zero ? newtonStep : newtonStep / denominator
		} else {
			// No usable derivative: fall through to bisection.
			step = T.nan
		}

		let candidate: T = x - step
		let insideBracket = candidate > low && candidate < high
		let tolerance: T = relativeTolerance * x

		// Convergence is tested *before* the bisection fallback, and this order is
		// load-bearing. On the final step the root is exact, so `candidate == x`, and x
		// has just become a bracket endpoint — which fails the strict comparison below.
		// Bisecting first would replace the exact answer with the midpoint of the
		// remaining bracket and then break, returning a converged-looking value that is
		// wrong in the third digit.
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

/// The quantity the iteration drives to zero, computed through whichever tail keeps
/// its significant digits.
///
/// Both branches equal `P(a, x) − p` in exact arithmetic. They differ in floating
/// point precisely where it matters: near `p = 1`, the lower branch cancels and the
/// upper one does not.
private func gammaResidual<T: Real>(a: T, x: T, target: T, useUpperTail: Bool) -> T {
	if useUpperTail {
		// target is 1 − p, and (1 − p) − Q(a, x) == P(a, x) − p without the cancellation.
		let upper: T = regularizedUpperIncompleteGamma(a: a, x: x)
		return target - upper
	}
	let lower: T = regularizedLowerIncompleteGamma(a: a, x: x)
	return lower - target
}

// MARK: - Iteration bounds, derived from the arithmetic

/// The most doublings that can carry a positive value across `T`'s exponent range.
///
/// A backstop, not a tuning parameter. The bracket search stops the moment the
/// residual changes sign; this bound exists only so the loop is provably finite, and
/// reaching it would mean no finite value of `T` satisfies the equation.
internal func exponentRangeInDoublings<T: Real>(of _: T.Type) -> Int {
	let top = T.greatestFiniteMagnitude.exponent
	let bottom = T.leastNormalMagnitude.exponent
	return Int(top - bottom)
}

/// The most bisection steps needed to close a bracket to the last representable bit.
///
/// Bisection resolves one bit per step, so closing a bracket that may span the whole
/// exponent range takes one step per exponent plus one per significand bit. The
/// significand width is read off `ulpOfOne`, which is 2^−(precision−1) by definition.
///
/// Halley converges cubically once it is near the root, so this bound is never
/// approached; like the doubling bound, it is here to make the loop finite rather than
/// to describe its behaviour.
internal func bisectionStepsToFullPrecision<T: Real>(of type: T.Type) -> Int {
	let significandBits = -Int(T.ulpOfOne.exponent)
	return exponentRangeInDoublings(of: type) + significandBits
}
