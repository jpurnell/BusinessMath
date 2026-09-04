//
//  regularizedLowerIncompleteGamma.swift
//  BusinessMath
//
//  Promoted 2026-09-04 from a private function inside chiSquaredCDF.swift, where it
//  was computed correctly and reachable by nothing. It is the shared kernel under
//  the gamma, Erlang and chi-squared families, and — through its inverse — under
//  their quantiles too.
//

import Foundation
import Numerics

/// The regularized lower incomplete gamma function, P(a, x).
///
/// ```
/// P(a, x) = γ(a, x) / Γ(a)
/// ```
///
/// P is the CDF of a gamma distribution with shape `a` and unit scale, so it is a
/// probability: it rises monotonically from 0 at `x = 0` to 1 as `x → ∞`. Several
/// distributions are a change of variable away from it —
///
/// | Distribution | In terms of P |
/// |---|---|
/// | Gamma(shape *k*, scale *θ*) | `P(k, x/θ)` |
/// | Erlang(*k*, *β*) | `P(k, x/β)`, integer *k* |
/// | Chi-squared(*ν*) | `P(ν/2, x/2)` |
///
/// ## Method
///
/// Two representations, split where each converges quickly — the standard treatment
/// from *Numerical Recipes* §6.2:
///
/// - **Series** for `x < a + 1`, summing `Γ(a)xⁿ/Γ(a+1+n)`.
/// - **Continued fraction** for `x ≥ a + 1`, evaluated by Lentz's algorithm on the
///   *upper* function Q(a, x) and returned as `1 - Q`.
///
/// Both are capped at 200 iterations and exit early on convergence; the cap is a
/// backstop, not the expected path.
///
/// ## Accuracy
///
/// Agrees with `scipy.special.gammainc` to better than 1e-12 across shapes from 0.5
/// to 50 and both branches — see `SpecialFunctionsTests`.
///
/// - Parameters:
///   - a: The shape parameter. Must be positive; a non-positive `a` returns `T.nan`
///     rather than a plausible-looking number.
///   - x: The upper limit of integration. Must be non-negative.
/// - Returns: P(a, x) in [0, 1], or `T.nan` for invalid input.
///
/// ## See Also
/// - ``inverseRegularizedLowerIncompleteGamma(p:a:)``
/// - ``regularizedIncompleteBeta(x:a:b:)``
public func regularizedLowerIncompleteGamma<T: Real>(a: T, x: T) -> T {
	guard a > T.zero, !a.isNaN, a.isFinite else { return T.nan }
	guard x >= T.zero, !x.isNaN else { return T.nan }

	if x == T.zero { return T.zero }
	if x.isInfinite { return T(1) }

	let branchPoint: T = a + T(1)
	if x < branchPoint {
		return gammaSeries(a: a, x: x)
	}
	let upper: T = gammaContinuedFraction(a: a, x: x)
	return T(1) - upper
}

/// The regularized **upper** incomplete gamma function, Q(a, x) = 1 − P(a, x).
///
/// This is the survival function of a unit-scale gamma: the probability of exceeding
/// `x`. It is published alongside P rather than left to the caller to subtract,
/// because `1 - P(a, x)` is worthless in the far upper tail — when P is 1 − 1e-12,
/// the subtraction keeps three digits of a quantity that Q computes to full
/// precision. ``inverseRegularizedLowerIncompleteGamma(p:a:)`` depends on that
/// distinction to invert the upper tail at all.
///
/// The branch is the mirror of P's: continued fraction where it converges quickly,
/// series subtracted from one where it does not.
///
/// - Parameters:
///   - a: The shape parameter. Must be positive.
///   - x: The lower limit of integration. Must be non-negative.
/// - Returns: Q(a, x) in [0, 1], or `T.nan` for invalid input.
///
/// ## See Also
/// - ``regularizedLowerIncompleteGamma(a:x:)``
public func regularizedUpperIncompleteGamma<T: Real>(a: T, x: T) -> T {
	guard a > T.zero, !a.isNaN, a.isFinite else { return T.nan }
	guard x >= T.zero, !x.isNaN else { return T.nan }

	if x == T.zero { return T(1) }
	if x.isInfinite { return T.zero }

	let branchPoint: T = a + T(1)
	if x < branchPoint {
		let lower: T = gammaSeries(a: a, x: x)
		return T(1) - lower
	}
	return gammaContinuedFraction(a: a, x: x)
}

/// Series expansion of P(a, x), used where `x < a + 1`.
///
/// ```
/// P(a, x) = e^(-x) · x^a / Γ(a) · Σ_{n≥0} xⁿ / (a(a+1)…(a+n))
/// ```
///
/// The prefactor is formed in log space so that a large `a` cannot overflow `x^a`
/// before the division by `Γ(a)` brings it back into range.
private func gammaSeries<T: Real>(a: T, x: T) -> T {
	let maxIterations = 200
	let epsilon = T(sign: .plus, exponent: -52, significand: T(1))

	var sum: T = T(1) / a
	var term: T = T(1) / a

	for n in 1...maxIterations {
		let denominator: T = a + T(n)
		term *= x / denominator
		sum += term
		let magnitude: T = abs(sum) * epsilon
		if abs(term) < magnitude { break }
	}

	let logPower: T = a * T.log(x)
	let logPrefix: T = logPower - x - T.logGamma(a)
	return sum * T.exp(logPrefix)
}

/// Continued fraction for the regularized *upper* incomplete gamma, Q(a, x) = 1 - P(a, x),
/// used where `x ≥ a + 1`. Evaluated by Lentz's algorithm.
private func gammaContinuedFraction<T: Real>(a: T, x: T) -> T {
	let maxIterations = 200
	let epsilon = T(sign: .plus, exponent: -52, significand: T(1))
	let tiny = T(sign: .plus, exponent: -100, significand: T(1))

	var b: T = x + T(1) - a
	var c: T = T(1) / tiny
	var d: T = T(1) / b
	var h: T = d

	for i in 1...maxIterations {
		let iT = T(i)
		let an: T = -iT * (iT - a)
		b += T(2)

		let dScaled: T = an * d
		d = dScaled + b
		if abs(d) < tiny { d = tiny }

		let cScaled: T = an / c
		c = b + cScaled
		if abs(c) < tiny { c = tiny }

		d = T(1) / d
		let delta: T = d * c
		h *= delta

		let deviation: T = delta - T(1)
		if abs(deviation) < epsilon { break }
	}

	let logPower: T = a * T.log(x)
	let logPrefix: T = logPower - x - T.logGamma(a)
	return T.exp(logPrefix) * h
}
