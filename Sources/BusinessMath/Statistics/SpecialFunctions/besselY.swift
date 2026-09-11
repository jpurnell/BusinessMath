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
/// remaining constant is γ. The recurrence on `ff` carries the logarithmic
/// singularity so that the sum itself stays well-behaved.
private func besselY01Temme<T: Real>(x: T) -> (T, T) {
	let half: T = x / T(2)
	let gamma: T = besselEulerGamma()
	let logHalf: T = besselLogHalf(x)
	let leading: T = -gamma - logHalf
	let twoOverPi: T = T(2) / T.pi
	let inversePi: T = T(1) / T.pi

	var ff: T = twoOverPi * leading
	var p: T = inversePi
	var q: T = inversePi
	var c: T = T(1)
	let d: T = -half * half
	var sum: T = ff
	var sum1: T = p

	for i in 1...besselIterationLimit {
		let fi: T = T(i)
		let scaled: T = fi * ff
		let numerator: T = scaled + p + q
		let square: T = fi * fi
		ff = numerator / square
		let step: T = d / fi
		c *= step
		p /= fi
		q /= fi
		let del: T = c * ff
		sum += del
		let cp: T = c * p
		let iDel: T = fi * del
		sum1 += cp - iDel
		let magnitude: T = T(1) + abs(sum)
		let tolerance: T = magnitude * T.ulpOfOne
		if abs(del) < tolerance { break }
	}

	let twoOverX: T = T(2) / x
	let y0: T = -sum
	let y1: T = -sum1 * twoOverX
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

/// Steed's continued fraction for the pair (p, q), evaluated in the complex plane
/// with real pairs — *Numerical Recipes* §6.7's CF2.
///
/// Reached only for 2 ≤ x < ``besselAsymptoticThreshold()``, so 2x is small and the
/// plain modulus-squared complex divisions cannot overflow.
private func besselSteedPQ<T: Real>(x: T) -> (p: T, q: T) {
	let xi: T = T(1) / x
	var a: T = T(1) / T(4)
	let half: T = T(1) / T(2)
	var p: T = -half * xi
	var q: T = T(1)
	let br: T = T(2) * x
	var bi: T = T(2)

	let pSquared: T = p * p
	let qSquared: T = q * q
	let modulus: T = pSquared + qSquared
	let aXi: T = a * xi
	var fact: T = aXi / modulus
	var cr: T = br + q * fact
	var ci: T = bi + p * fact

	let brSquared: T = br * br
	let biSquared: T = bi * bi
	var den: T = brSquared + biSquared
	var dr: T = br / den
	var di: T = -bi / den

	let crDr: T = cr * dr
	let ciDi: T = ci * di
	var dlr: T = crDr - ciDi
	let crDi: T = cr * di
	let ciDr: T = ci * dr
	var dli: T = crDi + ciDr

	let pDlr: T = p * dlr
	let qDli: T = q * dli
	var temp: T = pDlr - qDli
	let pDli: T = p * dli
	let qDlr: T = q * dlr
	q = pDli + qDlr
	p = temp

	for i in 2...besselIterationLimit {
		let step: T = T(2 * (i - 1))
		a += step
		bi += T(2)

		let aDr: T = a * dr
		dr = aDr + br
		let aDi: T = a * di
		di = aDi + bi

		let crSquared: T = cr * cr
		let ciSquared: T = ci * ci
		let cModulus: T = crSquared + ciSquared
		fact = a / cModulus
		let crFact: T = cr * fact
		let ciFact: T = ci * fact
		cr = br + crFact
		ci = bi - ciFact

		let drSquared: T = dr * dr
		let diSquared: T = di * di
		den = drSquared + diSquared
		dr /= den
		di /= -den

		let nextCrDr: T = cr * dr
		let nextCiDi: T = ci * di
		dlr = nextCrDr - nextCiDi
		let nextCrDi: T = cr * di
		let nextCiDr: T = ci * dr
		dli = nextCrDi + nextCiDr

		let nextPDlr: T = p * dlr
		let nextQDli: T = q * dli
		temp = nextPDlr - nextQDli
		let nextPDli: T = p * dli
		let nextQDlr: T = q * dlr
		q = nextPDli + nextQDlr
		p = temp

		let realGap: T = abs(dlr - T(1))
		let totalGap: T = realGap + abs(dli)
		if totalGap < T.ulpOfOne { break }
	}
	return (p, q)
}
