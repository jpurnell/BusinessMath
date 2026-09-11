//
//  BesselKernels.swift
//  BusinessMath
//
//  The pieces more than one of the four Bessel functions needs: the ascending
//  series that J and I share (differing only in a sign), the Hankel asymptotic
//  coefficients that J and Y share, and the handful of constants that have to be
//  derived from `T` rather than written down — `Real` refines `FloatingPoint`,
//  not `BinaryFloatingPoint`, so a generic function here cannot write `0.5`.
//

import Foundation
import Numerics

/// The largest number of iterations any Bessel kernel is permitted.
///
/// Every loop in this file converges far inside it whenever the answer is
/// representable. The cap is there so that an argument whose answer is *not*
/// representable terminates rather than spins.
let besselIterationLimit = 1_000_000

/// The largest number of terms taken from an asymptotic expansion.
///
/// Optimal truncation happens near `2x` terms and the loop stops itself the
/// moment a term grows, so this is only reached for an `x` so large that the
/// first term is already negligible.
let besselAsymptoticTermLimit = 200

/// Euler's constant, γ = 0.5772156649015328606…
///
/// Written as a ratio of two integer literals because a `T: Real` generic cannot
/// express a float literal at all. The numerator carries 18 significant digits,
/// which puts the quotient within one ulp of γ for `Double` and for every
/// narrower type. `Int64` is named explicitly so the literal cannot overflow
/// `Int` on a 32-bit target.
func besselEulerGamma<T: Real>() -> T {
	let numerator: T = T(Int64(577_215_664_901_532_861))
	let denominator: T = T(Int64(1_000_000_000_000_000_000))
	return numerator / denominator
}

/// A power of two to divide by when a recurrence's running value grows too large.
///
/// Being a power of two is the point: every value in flight is divided **exactly**,
/// so the ratio the algorithm is really computing is untouched. A decimal factor
/// rounds each of them independently and spends an ulp per rescale. Half the
/// exponent range leaves room for one more recurrence step above the threshold.
func besselRescaleFactor<T: Real>() -> T {
	let halfRange: T.Exponent = T.greatestFiniteMagnitude.exponent / 2
	return T(sign: .plus, exponent: halfRange, significand: T(1))
}

/// The natural logarithm of ``besselRescaleFactor()``.
func besselLogRescaleFactor<T: Real>() -> T {
	let halfRange: T.Exponent = T.greatestFiniteMagnitude.exponent / 2
	let exponent: T = T(halfRange)
	let logTwo: T = T.log(T(2))
	return exponent * logTwo
}

/// log(x/2), formed as log(x) − log 2.
///
/// Halving first would flush a subnormal `x` to zero and then take the logarithm
/// of nothing; this way `x` at `leastNonzeroMagnitude` still answers.
func besselLogHalf<T: Real>(_ x: T) -> T {
	let logX: T = T.log(x)
	let logTwo: T = T.log(T(2))
	return logX - logTwo
}

/// log((x/2)ⁿ / n!).
///
/// An *upper* bound on log|Jₙ(x)| and a *lower* bound on log Iₙ(x), which is what
/// lets it serve as an underflow screen for J and as the leading term for I.
func besselLogLeadingTerm<T: Real>(x: T, order n: Int) -> T {
	guard n > 0 else { return T.zero }
	let orderT: T = T(n)
	let logHalf: T = besselLogHalf(x)
	let scaled: T = orderT * logHalf
	let shifted: T = orderT + T(1)
	let logFactorial: T = T.logGamma(shifted)
	return scaled - logFactorial
}

/// 1/√(πx), formed without ever holding πx — which overflows well before `x` does.
func besselInverseRootPiX<T: Real>(_ x: T) -> T {
	let inversePi: T = T(1) / T.pi
	let rootInversePi: T = T.sqrt(inversePi)
	let rootX: T = T.sqrt(x)
	return rootInversePi / rootX
}

/// Where the Hankel asymptotic expansion reaches full precision.
///
/// The expansion is divergent; its optimal-truncation error is e^(−2x). The
/// crossover is therefore wherever that falls below one ulp — about 18 for
/// `Double`, and it moves right on its own for a wider `T`. Nothing here is
/// tuned to a particular width.
func besselAsymptoticThreshold<T: Real>() -> T {
	let logEpsilon: T = T.log(T.ulpOfOne)
	return -logEpsilon / T(2)
}

/// Where the ascending series is still free of meaningful cancellation.
///
/// Its largest term is about e^x/(πx) while the answer is O(x^(−1/2)), so the
/// relative error it carries is about ε·e^x. Four holds that to a few ulp for
/// `Double` and to fewer for anything wider, so a fixed bound errs in the safe
/// direction as precision grows.
func besselSeriesThreshold<T: Real>() -> T { T(4) }

/// Σₖ (∓1)ᵏ (x/2)^(n+2k) / (k!·(n+k)!) — the ascending series Jₙ and Iₙ share.
///
/// `alternating` selects J's signs. Without it this is Iₙ, whose terms are all
/// positive and therefore free of cancellation at *any* argument — which is why
/// I needs no second method and J needs two.
///
/// The sum is carried relative to its own leading term with the scale held in
/// logarithms, so neither (x/2)ⁿ/n! nor the running sum has to be representable.
/// Only the answer does.
///
/// - Parameters:
///   - x: A positive argument.
///   - n: A non-negative order.
///   - alternating: `true` for Jₙ, `false` for Iₙ.
/// - Returns: The sum, or `T.infinity` when Iₙ overflows.
func besselAscendingSeries<T: Real>(x: T, order n: Int, alternating: Bool) -> T {
	let logHuge: T = T.log(T.greatestFiniteMagnitude)
	var logScale: T = besselLogLeadingTerm(x: x, order: n)
	if logScale > logHuge { return alternating ? T.nan : T.infinity }

	let square: T = x * x
	let quarterSquare: T = square / T(4)
	let big: T = besselRescaleFactor()
	let logBig: T = besselLogRescaleFactor()
	let orderT: T = T(n)
	var term: T = T(1)
	var sum: T = T(1)

	for k in 1...besselIterationLimit {
		let kk: T = T(k)
		let shifted: T = kk + orderT
		let denominator: T = kk * shifted
		let ratio: T = quarterSquare / denominator
		term *= alternating ? -ratio : ratio
		sum += term
		if abs(term) <= T.ulpOfOne { break }
		if !alternating && sum > big {
			sum /= big
			term /= big
			logScale += logBig
			if logScale > logHuge { return T.infinity }
		}
	}

	if sum == T.zero { return T.zero }
	let scale: T = T.exp(logScale)
	if scale > T.zero && scale.isFinite { return scale * sum }
	let logMagnitude: T = logScale + T.log(abs(sum))
	let magnitude: T = T.exp(logMagnitude)
	return sum < T.zero ? -magnitude : magnitude
}

/// The Hankel asymptotic coefficients P(ν, x) and Q(ν, x).
///
/// Terms come from the ratio aₖ = aₖ₋₁·(μ − (2k−1)²)/(8kx) with μ = 4ν², and are
/// distributed Q, P, Q, P with the sign turning over every second term:
///
/// ```
/// P = a₀ − a₂ + a₄ − …
/// Q = a₁ − a₃ + a₅ − …
/// ```
///
/// The expansion diverges, so the loop stops the moment a term stops shrinking.
/// That is optimal truncation, and it is what makes the error e^(−2x) rather than
/// whatever the last term happened to be.
func besselAsymptoticPQ<T: Real>(x: T, order nu: Int) -> (p: T, q: T) {
	let nuT: T = T(nu)
	let nuSquared: T = nuT * nuT
	let mu: T = T(4) * nuSquared
	let eightX: T = T(8) * x

	var term: T = T(1)
	var p: T = T(1)
	var q: T = T.zero
	var previous: T = T.infinity

	for k in 1...besselAsymptoticTermLimit {
		let kk: T = T(k)
		let odd: T = T(2 * k - 1)
		let oddSquared: T = odd * odd
		let numerator: T = mu - oddSquared
		let denominator: T = kk * eightX
		let factor: T = numerator / denominator
		term *= factor
		let magnitude: T = abs(term)
		if magnitude >= previous { break }
		switch k % 4 {
		case 1: q += term
		case 2: p -= term
		case 3: q -= term
		default: p += term
		}
		previous = magnitude
		if magnitude < T.ulpOfOne { break }
	}
	return (p, q)
}
