//
//  besselK.swift
//  BusinessMath
//
//  The modified second kind. Excel calls it BESSELK.
//

import Foundation
import Numerics

/// The modified Bessel function of the second kind, Kₙ(x).
///
/// Kₙ is the decaying solution of the modified equation — it falls like
/// e^(−x)·√(π/2x), reaching the bottom of `Double`'s range a little past x = 745.
/// Like ``besselY(x:order:)`` it is singular at the origin and undefined for
/// x ≤ 0, so a non-positive argument returns `T.nan`.
///
/// ```swift
/// let k2: Double = besselK(x: 1.5, order: 2)   // 0.5836559627…
/// ```
///
/// ## Method
///
/// K₀ and K₁ from Temme's series below x = 2 and Steed's continued fraction above
/// it, then the order recurrence **upward** — stable, because Kₙ grows with n and
/// so dominates the parasitic Iₙ.
///
/// Neither half is an asymptotic expansion, and that is deliberate. K is the worst
/// of the four for the series-plus-asymptotic split the design proposal sketched:
/// its ascending series cancels against a quantity e^(2x) larger than the answer
/// and is spent by x ≈ 4, while the asymptotic is not machine-accurate until
/// x ≈ 20. That is most of a decade of argument with no accurate method in it.
/// Both methods used here converge.
///
/// As in ``besselY(x:order:)``, an integer order collapses Temme's μ-dependent
/// factors to 1 and leaves only γ.
///
/// ### The recurrence carries e^(+x)
///
/// Both halves return e^(+x)·K, the recurrence runs on those, and the exponential
/// is restored at the end from a logarithmic scale. This is not tidiness. K₀ and K₁
/// underflow to zero past x ≈ 745, and an upward recurrence seeded with two zeroes
/// returns zero forever — while Kₙ(x) becomes representable again at high order,
/// K₁₂₀₀(800) being about 6.7e-6. Recurring on the scaled values and exponentiating
/// once at the end gets that right; recurring on the raw values silently returns 0.
///
/// Overflow at high order returns `T.infinity` and underflow returns `T.zero`, both
/// being true limits and both distinguishable from invalid input.
///
/// ## Accuracy
///
/// Better than 1.2e-13 relative, measured against a 30-digit `mpmath` reference
/// over 15,000 argument-order pairs — see `BesselFunctionsTests`.
///
/// - Parameters:
///   - x: The argument. Must be strictly positive.
///   - n: The order. Must be non-negative.
/// - Returns: Kₙ(x), or `T.nan` if `n` is negative, or `x` is non-positive, NaN or
///   infinite.
///
/// ## See Also
/// - ``besselI(x:order:)``
/// - ``besselY(x:order:)``
public func besselK<T: Real>(x: T, order n: Int) -> T {
	guard n >= 0 else { return T.nan }
	guard !x.isNaN, x.isFinite else { return T.nan }
	guard x > T.zero else { return T.nan }

	// Above this the continued fraction's 2(1 + x) would overflow. It costs nothing
	// to refuse: Kₙ(x) < Γ(n)(2/x)ⁿ/2, which at this magnitude is below the
	// smallest subnormal for every order an `Int` can name.
	let quarterRange: T = T.greatestFiniteMagnitude / T(4)
	guard x <= quarterRange else { return T.zero }

	let (k0, k1) = besselK01Scaled(x: x)
	var logScale: T = -x
	var current: T = k0

	if n > 0 {
		let big: T = besselRescaleFactor()
		let logBig: T = besselLogRescaleFactor()
		let logHuge: T = T.log(T.greatestFiniteMagnitude)
		var previous: T = k0
		current = k1
		for j in 1..<n {
			let jT: T = T(j)
			let doubled: T = jT + jT
			let coefficient: T = doubled / x
			let scaled: T = coefficient * current
			let next: T = scaled + previous
			previous = current
			current = next
			if current > big {
				current /= big
				previous /= big
				logScale += logBig
				if logScale > logHuge { return T.infinity }
			}
		}
	}

	if current == T.zero || !current.isFinite { return current }
	let logValue: T = logScale + T.log(current)
	return T.exp(logValue)
}

// MARK: - Orders zero and one, scaled by e^(+x)

private func besselK01Scaled<T: Real>(x: T) -> (T, T) {
	if x < T(2) { return besselK01Temme(x: x) }
	return besselK01Steed(x: x)
}

/// Temme's series for K₀ and K₁, for small argument, returned scaled by e^(+x).
private func besselK01Temme<T: Real>(x: T) -> (T, T) {
	let half: T = x / T(2)
	let gamma: T = besselEulerGamma()
	let logHalf: T = besselLogHalf(x)

	var f: T = -gamma - logHalf
	var p: T = T(1) / T(2)
	var q: T = T(1) / T(2)
	var c: T = T(1)
	let quarterSquare: T = half * half
	var kSum: T = f
	var kSumNext: T = p

	for i in 1...besselIterationLimit {
		let fi: T = T(i)
		let scaled: T = fi * f
		let numerator: T = scaled + p + q
		let square: T = fi * fi
		f = numerator / square
		let step: T = quarterSquare / fi
		c *= step
		p /= fi
		q /= fi
		let increment: T = c * f
		kSum += increment
		let weighted: T = fi * f
		let inner: T = p - weighted
		kSumNext += c * inner
		let tolerance: T = abs(kSum) * T.ulpOfOne
		if abs(increment) < tolerance { break }
	}

	let scale: T = T.exp(x)
	let twoOverX: T = T(2) / x
	let k0: T = kSum * scale
	let k1Unscaled: T = kSumNext * twoOverX
	let k1: T = k1Unscaled * scale
	return (k0, k1)
}

/// Steed's continued fraction for K₀ and K₁, for x ≥ 2, returned scaled by e^(+x).
///
/// The e^(−x) that the closed form carries is simply not applied — which is what
/// keeps the order recurrence alive past the point where K itself underflows.
/// K₀ and K₁ for x ≥ 2 by Steed's algorithm, returned scaled by e^(+x).
///
/// Steed's method drives the continued fraction for Kμ₊₁/Kμ alongside an auxiliary
/// two-term sequence that supplies the normalisation, so a single pass yields both
/// orders. The method is Steed's, published in Barnett, Feng, Steed and Goldfarb
/// (1974) and set out with the auxiliary sequence in Thompson and Barnett (1987);
/// the fraction itself advances by the modified Lentz recurrence this directory
/// already uses — compare ``regularizedUpperIncompleteGamma(a:x:)``, which carries
/// the same `lentzD`/`increment`/`deviation` shape.
///
/// The exponential factor is deliberately *not* applied here.
/// ``besselK(x:order:)`` carries it in logarithms so the order recurrence survives
/// the range where K itself underflows.
private func besselK01Steed<T: Real>(x: T) -> (T, T) {
	let two: T = T(2)
	let quarter: T = T(1) / T(4)
	let onePlusX: T = T(1) + x

	// aₙ and bₙ of the continued fraction, and Lentz's Dⱼ with its running factor.
	var numerator: T = -quarter
	var denominator: T = two * onePlusX
	var lentzD: T = T(1) / denominator
	var increment: T = lentzD
	var fraction: T = lentzD

	// Steed's auxiliary sequence, held as an explicit two-term state rather than a
	// pair of scalars shuffled by hand: the recurrence is second order and reads as
	// one when it is written that way.
	var auxiliary: (previous: T, current: T) = (T.zero, T(1))
	var coefficient: T = quarter
	var weight: T = quarter
	var normalizer: T = T(1) + weight * increment

	for index in 2...besselIterationLimit {
		let position: T = T(index)
		let shift: T = T(2 * (index - 1))
		numerator -= shift
		let negated: T = -numerator
		let scaled: T = negated * coefficient
		coefficient = scaled / position

		let weighted: T = denominator * auxiliary.current
		let difference: T = auxiliary.previous - weighted
		let next: T = difference / numerator
		auxiliary = (auxiliary.current, next)
		weight += coefficient * next

		denominator += two
		let tail: T = numerator * lentzD
		let divisor: T = denominator + tail
		lentzD = T(1) / divisor
		let scaledD: T = denominator * lentzD
		let delta: T = scaledD - T(1)
		increment = delta * increment
		fraction += increment

		let contribution: T = weight * increment
		normalizer += contribution
		let deviation: T = contribution / normalizer
		if abs(deviation) < T.ulpOfOne { break }
	}

	fraction = quarter * fraction
	let twoX: T = two * x
	let piOverTwoX: T = T.pi / twoX
	let amplitude: T = T.sqrt(piOverTwoX)
	let k0: T = amplitude / normalizer
	let half: T = T(1) / two
	let shifted: T = x + half - fraction
	let ratio: T = shifted / x
	let k1: T = k0 * ratio
	return (k0, k1)
}
