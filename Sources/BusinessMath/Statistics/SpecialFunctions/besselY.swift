//
//  besselY.swift
//  BusinessMath
//
//  The second kind — also Weber's, also Neumann's. Excel calls it BESSELY.
//

import Foundation
import Numerics

/// The Bessel function of the second kind, Yₙ(x).
///
/// Yₙ is the solution of Bessel's equation that is *singular* at the origin:
/// Y₀(x) → −∞ logarithmically as x → 0⁺, and Yₙ for n ≥ 1 diverges like −x^(−n).
/// It is genuinely undefined for x ≤ 0, so unlike ``besselJ(x:order:)`` there is no
/// parity relation to apply and a non-positive argument returns `T.nan`.
///
/// ```swift
/// let y2: Double = besselY(x: 1.5, order: 2)   // -0.9321937507…
/// ```
///
/// ## Method
///
/// Y₀ and Y₁ come from one of three sources, then the order recurrence runs
/// **upward** — the stable direction, because Yₙ grows with n and so dominates the
/// parasitic Jₙ:
///
/// | Range | Method |
/// |---|---|
/// | `x < 2` | Temme's series |
/// | `2 ≤ x < ~18` | Steed's continued fraction for (p, q), combined with J₀ and J₁ |
/// | `x ≥ ~18` | Hankel asymptotic |
///
/// The middle band is why this is not the series-plus-asymptotic split the design
/// proposal sketched. Y's ascending series carries about ε·e^x of cancellation and
/// is spent by x ≈ 8; the asymptotic is not machine-accurate until x ≈ 18. A
/// crossover placed anywhere between them is about 1e-11 at its best. Steed's
/// continued fraction *converges* rather than being asymptotic, so it closes the
/// band outright.
///
/// Temme's series normally drags a Chebyshev fit for 1/Γ(1±μ) along with it. Here
/// the order is an integer, so μ = 0 and the whole apparatus collapses to γ and 1.
///
/// ### Overflow is reported, not corrupted
///
/// Yₙ(x) grows without bound in n. Once it leaves the type's range the recurrence
/// would form (−∞) − (−∞) and yield `T.nan`, which a caller would read as invalid
/// input. The loop stops at the first non-finite step and returns `-T.infinity`,
/// which is the true limit.
///
/// ## Accuracy
///
/// Better than 1.2e-14 relative, measured against a 30-digit `mpmath` reference
/// over 15,000 argument-order pairs — see `BesselFunctionsTests`. Near a zero of
/// Yₙ accuracy is measured against the local amplitude √(2/πx), for the reason
/// given in ``besselJ(x:order:)``.
///
/// - Parameters:
///   - x: The argument. Must be strictly positive.
///   - n: The order. Must be non-negative.
/// - Returns: Yₙ(x), or `T.nan` if `n` is negative, or `x` is non-positive, NaN or
///   infinite.
///
/// ## See Also
/// - ``besselJ(x:order:)``
/// - ``besselK(x:order:)``
public func besselY<T: Real>(x: T, order n: Int) -> T {
	guard n >= 0 else { return T.nan }
	guard !x.isNaN, x.isFinite else { return T.nan }
	guard x > T.zero else { return T.nan }

	let (y0, y1) = besselY01(x: x)
	if n == 0 { return y0 }

	var previous: T = y0
	var current: T = y1
	for k in 1..<n {
		let kT: T = T(k)
		let doubled: T = kT + kT
		let coefficient: T = doubled / x
		let scaled: T = coefficient * current
		let next: T = scaled - previous
		guard next.isFinite else { return next }
		previous = current
		current = next
	}
	return current
}

// MARK: - Orders zero and one

private func besselY01<T: Real>(x: T) -> (T, T) {
	if x < T(2) { return besselY01Temme(x: x) }
	let asymptoticBound: T = besselAsymptoticThreshold()
	if x >= asymptoticBound { return besselY01Asymptotic(x: x) }
	return besselY01ContinuedFraction(x: x)
}

/// Temme's series for Y₀ and Y₁, for small argument.
///
/// At integer order the general form's μ-dependent factors — `πμ/sin πμ`,
/// `sinh(μd)/μd`, and the Chebyshev fit for 1/Γ(1±μ) — are all exactly 1, and the
/// remaining constant is γ. The recurrence on `f` carries the logarithmic
/// singularity so that the sum itself stays well-behaved.
private func besselY01Temme<T: Real>(x: T) -> (T, T) {
	let half: T = x / T(2)
	let gamma: T = besselEulerGamma()
	let logHalf: T = besselLogHalf(x)
	let leading: T = -gamma - logHalf
	let twoOverPi: T = T(2) / T.pi
	let inversePi: T = T(1) / T.pi

	var f: T = twoOverPi * leading
	var p: T = inversePi
	var q: T = inversePi
	var c: T = T(1)
	let negativeQuarterSquare: T = -half * half
	var ySum: T = f
	var ySumNext: T = p

	for i in 1...besselIterationLimit {
		let fi: T = T(i)
		let scaled: T = fi * f
		let numerator: T = scaled + p + q
		let square: T = fi * fi
		f = numerator / square
		let step: T = negativeQuarterSquare / fi
		c *= step
		p /= fi
		q /= fi
		let increment: T = c * f
		ySum += increment
		let weighted: T = c * p
		let scaledIncrement: T = fi * increment
		ySumNext += weighted - scaledIncrement
		let magnitude: T = T(1) + abs(ySum)
		let tolerance: T = magnitude * T.ulpOfOne
		if abs(increment) < tolerance { break }
	}

	let twoOverX: T = T(2) / x
	let y0: T = -ySum
	let y1: T = -ySumNext * twoOverX
	return (y0, y1)
}

/// Y₀ and Y₁ from the Hankel asymptotic, phase-reduced onto cos x and sin x for
/// the reason set out in ``besselJ(x:order:)``.
///
/// ```
/// Y₀ = √(1/πx)·[(P+Q)sin x + (Q−P)cos x]
/// Y₁ = √(1/πx)·[(Q−P)sin x − (P+Q)cos x]
/// ```
private func besselY01Asymptotic<T: Real>(x: T) -> (T, T) {
	let amplitude: T = besselInverseRootPiX(x)
	let cosX: T = T.cos(x)
	let sinX: T = T.sin(x)

	let (p0, q0) = besselAsymptoticPQ(x: x, order: 0)
	let sum0: T = p0 + q0
	let difference0: T = q0 - p0
	let sinPart0: T = sum0 * sinX
	let cosPart0: T = difference0 * cosX
	let combined0: T = sinPart0 + cosPart0
	let y0: T = amplitude * combined0

	let (p1, q1) = besselAsymptoticPQ(x: x, order: 1)
	let sum1: T = p1 + q1
	let difference1: T = q1 - p1
	let sinPart1: T = difference1 * sinX
	let cosPart1: T = sum1 * cosX
	let combined1: T = sinPart1 - cosPart1
	let y1: T = amplitude * combined1
	return (y0, y1)
}

/// Y₀ and Y₁ from Steed's (p, q) and the already-computed J₀ and J₁.
///
/// Temme's identities give Y/J = (p − J′/J)/q; at order zero J′ = −J₁, so
///
/// ```
/// Y₀ = (p·J₀ + J₁)/q
/// Y₁ = −p·Y₀ − q·J₀
/// ```
///
/// Written this way rather than as J₀·(p − f)/q on purpose: the ratio form divides
/// by J₀, which is fine until x sits on a zero of J₀, where it is not. These two
/// expressions never divide by anything that vanishes.
private func besselY01ContinuedFraction<T: Real>(x: T) -> (T, T) {
	let j0: T = besselJ(x: x, order: 0)
	let j1: T = besselJ(x: x, order: 1)
	let (p, q) = besselSteedPQ(x: x)

	let scaled: T = p * j0
	let numerator: T = scaled + j1
	let y0: T = numerator / q
	let first: T = -p * y0
	let second: T = q * j0
	let y1: T = first - second
	return (y0, y1)
}

/// A complex value carried as a real pair, with the three operations Steed's
/// recurrence needs.
///
/// `Complex<T>` from swift-numerics would serve, and is deliberately not used:
/// its division applies Smith's scaling to survive overflow, which changes the
/// last ulp. This fraction is only ever evaluated for 2 ≤ x < 18, where nothing
/// can overflow, so the straightforward form is both safe and exactly
/// reproducible. The operations are written as named methods rather than
/// operators so the order of the real arithmetic inside them is visible and
/// fixed.
private struct BesselComplexPair<T: Real> {
	var real: T
	var imaginary: T

	/// `self * other`.
	func multiplied(by other: BesselComplexPair<T>) -> BesselComplexPair<T> {
		let crossReal: T = real * other.real
		let crossImaginary: T = imaginary * other.imaginary
		let productReal: T = crossReal - crossImaginary
		let firstOuter: T = real * other.imaginary
		let secondOuter: T = imaginary * other.real
		let productImaginary: T = firstOuter + secondOuter
		return BesselComplexPair(real: productReal, imaginary: productImaginary)
	}

	/// `1 / self`, as conj(self) over the squared modulus.
	func reciprocal() -> BesselComplexPair<T> {
		let realSquared: T = real * real
		let imaginarySquared: T = imaginary * imaginary
		let modulus: T = realSquared + imaginarySquared
		let inverseReal: T = real / modulus
		let inverseImaginary: T = -imaginary / modulus
		return BesselComplexPair(real: inverseReal, imaginary: inverseImaginary)
	}

	/// `base + scalar / self`, the one fused step the recurrence repeats.
	func addedTo(_ base: BesselComplexPair<T>, scaling scalar: T) -> BesselComplexPair<T> {
		let realSquared: T = real * real
		let imaginarySquared: T = imaginary * imaginary
		let modulus: T = realSquared + imaginarySquared
		let factor: T = scalar / modulus
		let shiftedReal: T = base.real + real * factor
		let shiftedImaginary: T = base.imaginary - imaginary * factor
		return BesselComplexPair(real: shiftedReal, imaginary: shiftedImaginary)
	}
}

/// Steed's continued fraction for the pair (p, q).
///
/// The fraction is complex-valued and is advanced by the modified Lentz recurrence,
/// with the running value `estimate` accumulating the product of successive ratios.
/// The method is Steed's — Barnett, Feng, Steed and Goldfarb (1974), with the
/// complex form for Yν set out in Temme (1976) — and the (p, q) it returns combine
/// with J₀ and J₁ to give Y₀ and Y₁ in ``besselY01ContinuedFraction(x:)``.
///
/// Reached only for 2 ≤ x < ``besselAsymptoticThreshold()``, so 2x is small and no
/// intermediate can overflow.
private func besselSteedPQ<T: Real>(x: T) -> (p: T, q: T) {
	let two: T = T(2)
	let quarter: T = T(1) / T(4)
	let half: T = T(1) / two
	let inverseX: T = T(1) / x

	var coefficient: T = quarter
	var estimate = BesselComplexPair<T>(real: -half * inverseX, imaginary: T(1))
	let denominator = BesselComplexPair<T>(real: two * x, imaginary: two)
	var shifted = denominator

	// The opening step is NOT the loop's step, and must not be folded into it. Here
	// the shift is b + i·a·ξ/(p+iq) — the real part takes q and the imaginary part
	// takes p, both added — where every later step is b + a/c. The two differ by a
	// factor of i, and unifying them silently costs three significant figures.
	let squaredReal: T = estimate.real * estimate.real
	let squaredImaginary: T = estimate.imaginary * estimate.imaginary
	let openingModulus: T = squaredReal + squaredImaginary
	let scaled: T = coefficient * inverseX
	let opening: T = scaled / openingModulus
	var numerator = BesselComplexPair<T>(
		real: shifted.real + estimate.imaginary * opening,
		imaginary: shifted.imaginary + estimate.real * opening
	)
	var inverse: BesselComplexPair<T> = shifted.reciprocal()
	var ratio: BesselComplexPair<T> = numerator.multiplied(by: inverse)
	estimate = estimate.multiplied(by: ratio)

	for index in 2...besselIterationLimit {
		let step: T = T(2 * (index - 1))
		coefficient += step
		shifted.imaginary += two

		let scaledReal: T = coefficient * inverse.real
		let scaledImaginary: T = coefficient * inverse.imaginary
		inverse.real = scaledReal + denominator.real
		inverse.imaginary = scaledImaginary + shifted.imaginary

		numerator = numerator.addedTo(
			BesselComplexPair(real: denominator.real, imaginary: shifted.imaginary),
			scaling: coefficient
		)
		inverse = inverse.reciprocal()
		ratio = numerator.multiplied(by: inverse)
		estimate = estimate.multiplied(by: ratio)

		let realGap: T = abs(ratio.real - T(1))
		let totalGap: T = realGap + abs(ratio.imaginary)
		if totalGap < T.ulpOfOne { break }
	}
	return (estimate.real, estimate.imaginary)
}
