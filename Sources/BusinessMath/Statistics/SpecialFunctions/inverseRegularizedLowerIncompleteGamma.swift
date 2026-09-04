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
/// A closed-form initial estimate followed by **Halley's method**, each step
/// safeguarded by a bracket that bisection tightens whenever a Halley step would
/// leave it. The initial estimate is Wilson–Hilferty for `a > 1` and a small-shape
/// expansion otherwise, both from *Numerical Recipes* §6.2.1.
///
/// The safeguard matters more than the iteration. P is extremely flat in the far
/// tails, so an unguarded Newton or Halley step from a poor start can jump past zero
/// or to infinity; keeping every iterate inside a known bracket means the worst case
/// degrades to bisection rather than diverging.
///
/// ## Accuracy
///
/// Agrees with `scipy.special.gammaincinv` to better than 1e-9 relative across shapes
/// from 0.5 to 50 and probabilities from 1e-10 to 1 − 1e-10, tails included. This is
/// a root-found quantity and is held to a relative rather than absolute tolerance,
/// as permitted by §15.1 of the distribution-contract proposal: the returned values
/// span roughly 1e-8 to 1e3 across that range, where a single absolute bound would be
/// vacuous at one end and unattainable at the other.
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

	var x: T = initialGammaQuantileEstimate(p: p, a: a)

	// Above the median, iterate on Q(a, x) = 1 − p rather than P(a, x) = p. The two
	// are the same equation, but the residual `P(a, x) − p` subtracts two numbers
	// that are both within 1e-10 of 1, which leaves roughly six significant digits
	// of a quantity Q computes to full precision. The tail is where a risk model
	// actually reads a quantile, so this is not a corner case.
	let useUpperTail = p > decimal(5, over: 10)
	let target: T = useUpperTail ? T(1) - p : p

	// Bracket the root. The residual below is increasing in x either way, so
	// expanding outward from the estimate until the ends straddle zero gives an
	// interval the root cannot escape.
	var low: T = T.zero
	var high: T = x
	var expansions = 0
	while gammaResidual(a: a, x: high, target: target, useUpperTail: useUpperTail) < T.zero,
		  expansions < 200 {
		low = high
		high *= T(2)
		expansions += 1
	}
	if high <= T.zero { high = T(1) }

	let epsilon = T(sign: .plus, exponent: -50, significand: T(1))
	let logGammaA: T = T.logGamma(a)
	let shapeMinusOne: T = a - T(1)

	for _ in 0..<100 {
		if x <= low || x >= high {
			let span: T = high - low
			let half: T = span / T(2)
			x = low + half
		}

		let error: T = gammaResidual(a: a, x: x, target: target, useUpperTail: useUpperTail)
		if error > T.zero { high = x } else { low = x }

		// The density of the unit-scale gamma: P'(a, x) = x^(a-1) e^(-x) / Γ(a),
		// formed in log space so a large shape cannot overflow the power.
		let logPower: T = shapeMinusOne * T.log(x)
		let logDensity: T = logPower - x - logGammaA
		let density: T = T.exp(logDensity)
		guard density > T.zero, density.isFinite else { break }

		let newtonStep: T = error / density

		// Halley's correction. The second-derivative ratio of P is (a-1)/x - 1, and
		// the product is capped at 1 — as in Numerical Recipes — so that a large
		// Newton step cannot drive the denominator through zero and flip the sign.
		let curvature: T = shapeMinusOne / x - T(1)
		let rawFactor: T = newtonStep * curvature
		let clampedFactor: T = Swift.min(T(1), rawFactor)
		let halved: T = clampedFactor / T(2)
		let denominator: T = T(1) - halved
		let step: T = denominator == T.zero ? newtonStep : newtonStep / denominator

		let candidate: T = x - step
		let insideBracket = candidate > low && candidate < high
		let tolerance: T = epsilon * x

		// Convergence is tested *before* the bisection fallback, and this order is
		// load-bearing. On the final step the root is exact, so `candidate == x`, and
		// x has just become a bracket endpoint — which fails the strict comparison
		// below. Bisecting first would replace the exact answer with the midpoint of
		// the remaining bracket and then break, returning a converged-looking value
		// that is wrong in the third digit.
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

/// A closed-form starting point for the Halley iteration.
///
/// Wilson–Hilferty for `a > 1` — the cube-root transform that makes a gamma nearly
/// normal — and a two-branch expansion for smaller shapes, where that transform is
/// poor. Neither needs to be accurate; both need to be on the right side of nothing
/// and finite, because the bracket does the rest.
private func initialGammaQuantileEstimate<T: Real>(p: T, a: T) -> T {
	if a > T(1) {
		// Invert the standard normal by the Beasley–Springer rational approximation,
		// then map through Wilson–Hilferty.
		let tail: T = p < decimal(5, over: 10) ? p : T(1) - p
		let logTail: T = T.log(tail)
		let t: T = T.sqrt(T(-2) * logTail)

		let numerator: T = decimal(230_753, over: 100_000) + t * decimal(27_061, over: 100_000)
		let innerDenominator: T = decimal(99_229, over: 100_000) + t * decimal(4_481, over: 100_000)
		let denominator: T = T(1) + t * innerDenominator
		var z: T = numerator / denominator - t
		if p < decimal(5, over: 10) { z = -z }

		let ninthOfShape: T = T(1) / (T(9) * a)
		let scaledDeviate: T = z / (T(3) * T.sqrt(a))
		// Minus, not plus: the rational approximation above returns the *lower*-tail
		// deviate, so a probability above the median arrives here negative.
		let base: T = T(1) - ninthOfShape - scaledDeviate
		let cubed: T = base * base * base
		let estimate: T = a * cubed
		return Swift.max(decimal(1, over: 1_000), estimate)
	}

	// Small shape: P rises almost vertically near zero, so the two branches meet at
	// the value of P where the power-law behaviour gives way to the exponential.
	let quadratic: T = decimal(253, over: 1_000) + a * decimal(12, over: 100)
	let crossover: T = T(1) - a * quadratic

	if p < crossover {
		let ratio: T = p / crossover
		let reciprocalShape: T = T(1) / a
		return T.pow(ratio, reciprocalShape)
	}

	let excess: T = p - crossover
	let remaining: T = T(1) - crossover
	let fraction: T = excess / remaining
	let argument: T = T(1) - fraction
	return T(1) - T.log(argument)
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
