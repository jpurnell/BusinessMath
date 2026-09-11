//
//  besselJ.swift
//  BusinessMath
//
//  The first of the four Bessel functions, and the one the other three borrow
//  their structure from. Excel calls it BESSELJ.
//

import Foundation
import Numerics

/// The Bessel function of the first kind, Jₙ(x).
///
/// Jₙ is the solution of Bessel's equation
///
/// ```
/// x²y″ + xy′ + (x² − n²)y = 0
/// ```
///
/// that stays finite at the origin. It oscillates, with an amplitude decaying like
/// x^(−1/2), and it crosses zero infinitely often — so it takes every value in its
/// range repeatedly, and no sentinel could be told apart from an answer. Invalid
/// input therefore returns `T.nan`.
///
/// ```swift
/// let j2: Double = besselJ(x: 1.5, order: 2)   // 0.2320876721442…
/// let j0: Double = besselJ(x: 0.0, order: 0)   // exactly 1
/// ```
///
/// ## Method
///
/// Three regimes, chosen so that no argument falls between two methods that are
/// each inaccurate there:
///
/// | Range | Method | Why |
/// |---|---|---|
/// | `x ≤ 4` | ascending series | Its largest term is only a few times the answer, so cancellation costs a few ulp. |
/// | `4 < x`, `n < x`, `x ≥ ~18` | Hankel asymptotic for J₀, J₁, then the order recurrence **upward** | Upward is dominated by the wanted solution while `n < x`. |
/// | otherwise | **Miller's downward recurrence** | The only stable direction once `n > x`. |
///
/// The proposal for this work suggested series-below/asymptotic-above with a single
/// crossover. That leaves a real hole: the series carries about ε·e^x and the
/// asymptotic about e^(−2x), and the best the two can do where they meet near
/// x ≈ 13 is roughly 1e-11. Miller's recurrence covers the middle instead, and it
/// has no such floor.
///
/// ### Negative x
///
/// Jₙ(−x) = (−1)ⁿJₙ(x), and Excel agrees: `BESSELJ(-1.5, 1)` returns
/// `-0.557936508`, where treating the argument as an absolute value would give
/// `+0.557936508`. Settled by sign, not by tolerance.
///
/// ## Accuracy
///
/// Better than 2e-15 relative, measured against a 30-digit `mpmath` reference over
/// 15,000 argument-order pairs spanning 1e-6 to 3000 and orders 0 to 200 — see
/// `BesselFunctionsTests`. Near a zero of Jₙ no method achieves a *relative*
/// bound, so accuracy there is measured against the local amplitude √(2/πx)
/// instead, and meets the same figure.
///
/// - Parameters:
///   - x: The argument. Any finite value; negative arguments use the parity
///     relation above.
///   - n: The order. Must be non-negative — Excel's truncation of a fractional
///     order is a spreadsheet convention and belongs at the spreadsheet binding,
///     not here.
/// - Returns: Jₙ(x), or `T.nan` if `n` is negative or `x` is NaN or infinite.
///
/// ## See Also
/// - ``besselY(x:order:)``
/// - ``besselI(x:order:)``
/// - ``besselK(x:order:)``
public func besselJ<T: Real>(x: T, order n: Int) -> T {
	guard n >= 0 else { return T.nan }
	guard !x.isNaN, x.isFinite else { return T.nan }

	if x < T.zero {
		let magnitude: T = besselJ(x: -x, order: n)
		return n % 2 == 0 ? magnitude : -magnitude
	}
	if x == T.zero { return n == 0 ? T(1) : T.zero }

	// |Jₙ(x)| ≤ (x/2)ⁿ/n! for every x > 0, so a bound that underflows is an answer
	// that underflows. This is also what keeps the cost finite when a caller asks
	// for an order far above the argument.
	let logBound: T = besselLogLeadingTerm(x: x, order: n)
	let logTiny: T = T.log(T.leastNonzeroMagnitude)
	if logBound < logTiny { return T.zero }

	let seriesBound: T = besselSeriesThreshold()
	if x <= seriesBound {
		return besselAscendingSeries(x: x, order: n, alternating: true)
	}

	let asymptoticBound: T = besselAsymptoticThreshold()
	let orderT: T = T(n)
	if x >= asymptoticBound && orderT < x {
		return besselJUpward(x: x, order: n)
	}
	return besselJMiller(x: x, order: n)
}

// MARK: - Large argument: asymptotic J₀ and J₁, then upward

/// J₀ and J₁ from the Hankel asymptotic, then the order recurrence upward.
///
/// The expansion is normally written against ω = x − (2ν+1)π/4. Expanding cos ω
/// and sin ω into cos x and sin x removes the subtraction, and with it the one
/// thing that would otherwise ruin large arguments: forming `x − π/4` rounds away
/// ulp(x), which is an absolute error of 2e-10 in the phase at x = 1e6. `cos` and
/// `sin` reduce their own argument against a far better π than a `T` can hold.
///
/// ```
/// J₀ = √(1/πx)·[(P+Q)cos x + (P−Q)sin x]
/// J₁ = √(1/πx)·[(Q−P)cos x + (P+Q)sin x]
/// ```
private func besselJUpward<T: Real>(x: T, order n: Int) -> T {
	let amplitude: T = besselInverseRootPiX(x)
	let cosX: T = T.cos(x)
	let sinX: T = T.sin(x)

	let (p0, q0) = besselAsymptoticPQ(x: x, order: 0)
	let sum0: T = p0 + q0
	let difference0: T = p0 - q0
	let cosPart0: T = sum0 * cosX
	let sinPart0: T = difference0 * sinX
	let combined0: T = cosPart0 + sinPart0
	let j0: T = amplitude * combined0
	if n == 0 { return j0 }

	let (p1, q1) = besselAsymptoticPQ(x: x, order: 1)
	let sum1: T = p1 + q1
	let difference1: T = q1 - p1
	let cosPart1: T = difference1 * cosX
	let sinPart1: T = sum1 * sinX
	let combined1: T = cosPart1 + sinPart1
	let j1: T = amplitude * combined1
	if n == 1 { return j1 }

	var previous: T = j0
	var current: T = j1
	for k in 1..<n {
		let kT: T = T(k)
		let doubled: T = kT + kT
		let coefficient: T = doubled / x
		let scaled: T = coefficient * current
		let next: T = scaled - previous
		previous = current
		current = next
	}
	return current
}

// MARK: - Miller's downward recurrence

/// log|Jₙ(x)|, estimated closely enough to size Miller's seed order.
///
/// Two regimes, because the function has two:
///
/// - **n ≤ x, oscillatory.** The envelope √(2/πx) — the *smallest* amplitude the
///   band attains, so a seed order chosen from it is adequate at a zero crossing
///   too, where no relative bound is achievable and absolute error is the target.
/// - **n > x, exponentially small.** Debye's uniform asymptotic.
///
/// The crude bound (x/2)ⁿ/n! must **not** be used here, tempting as it is: it
/// overstates |Jₙ(x)| by a factor of e³¹² at x = n = 1000, which relaxes the seed
/// order enough to return a wrong answer of entirely plausible magnitude.
private func besselLogMagnitudeJ<T: Real>(x: T, order n: Int) -> T {
	let logTwo: T = T.log(T(2))
	let logPi: T = T.log(T.pi)
	let logX: T = T.log(x)
	let logSquaredEnvelope: T = logTwo - logPi - logX
	let envelope: T = logSquaredEnvelope / T(2)
	guard n > 0 else { return envelope }

	let orderT: T = T(n)
	let z: T = x / orderT
	if z >= T(1) { return envelope }

	let zSquared: T = z * z
	let remainder: T = T(1) - zSquared
	let s: T = T.sqrt(remainder)
	let onePlusS: T = T(1) + s
	let ratio: T = onePlusS / z
	let eta: T = T.log(ratio) - s
	let principal: T = -orderT * eta
	let twoPi: T = T(2) * T.pi
	let twoPiN: T = twoPi * orderT
	let correction: T = T.log(twoPiN) / T(2)
	return principal - correction
}

/// The lowest even order at which seeding the downward recurrence contaminates the
/// answer by less than one ulp.
///
/// Seeding f₍ₘ₊₁₎ = 0 means the computed solution is αJ + βY with β/α = −J₍ₘ₊₁₎/Y₍ₘ₊₁₎,
/// so the relative error carried down to order `n` goes as J₍ₘ₊₁₎ measured against
/// the magnitude of the answer. The search walks up one order at a time; below the
/// turning point the estimate is flat and the test cannot pass, so `m` necessarily
/// finishes above `x` without ever converting `x` to an `Int` — which `T: Real`
/// could not do anyway.
private func besselMillerStartingOrder<T: Real>(x: T, order n: Int) -> Int {
	let logEpsilon: T = T.log(T.ulpOfOne)
	let logAnswer: T = besselLogMagnitudeJ(x: x, order: n)
	let target: T = logEpsilon + logAnswer

	var m: Int = n + 2
	while m < besselIterationLimit {
		let logSeed: T = besselLogMagnitudeJ(x: x, order: m + 1)
		if logSeed < target { break }
		m += 1
	}
	return m + (m % 2)
}

/// Miller's downward recurrence, normalised by J₀(x) + 2·Σ J₂ₖ(x) = 1.
///
/// Downward is the direction in which Jₙ dominates Yₙ, so the arbitrary seed decays
/// out of the answer instead of swamping it. The running values are rescaled by a
/// power of two whenever they grow large, which is exact and so leaves the ratio
/// this function actually returns untouched.
private func besselJMiller<T: Real>(x: T, order n: Int) -> T {
	let m: Int = besselMillerStartingOrder(x: x, order: n)
	let two: T = T(2)
	let twoOverX: T = two / x
	let big: T = besselRescaleFactor()

	var jPlus1: T = T.zero
	var j: T = T(1)
	var sum: T = T.zero
	var answer: T = T.zero

	var k: Int = m
	while k >= 1 {
		let kT: T = T(k)
		let coefficient: T = kT * twoOverX
		let product: T = coefficient * j
		let jMinus1: T = product - jPlus1
		jPlus1 = j
		j = jMinus1
		if abs(j) > big {
			j /= big
			jPlus1 /= big
			sum /= big
			answer /= big
		}
		let index: Int = k - 1
		if index >= 2 && index % 2 == 0 { sum += j }
		if index == n { answer = j }
		k -= 1
	}

	let twiceSum: T = two * sum
	let normalizer: T = j + twiceSum
	guard normalizer != T.zero else { return T.nan }
	return answer / normalizer
}
