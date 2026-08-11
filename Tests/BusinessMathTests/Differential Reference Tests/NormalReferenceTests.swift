//
//  NormalReferenceTests.swift
//  BusinessMath
//
//  Differential tests for the normal CDF and its inverse against published
//  reference values. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// `normalCDF` and `inverseNormalCDF` against published tables and exact identities.
///
/// ## Why this file exists
///
/// `inverseNormalCDF` was discontinuous for months — it jumped from `0.30` to
/// `1.372` at `u = 0.6`, making an entire interval of outputs unreachable — and it
/// survived because nothing in the suite compared it to a known-good answer. A
/// tolerance test against the library's own output cannot catch that. A comparison
/// against a value someone else published can.
///
/// ## Where the reference values come from
///
/// - **A&S 26.1** — Abramowitz & Stegun, *Handbook of Mathematical Functions*
///   (NBS Applied Mathematics Series 55, 1964), Table 26.1, "Normal Probability
///   Function and Related Functions". Tabulates `P(x)` and `Q(x) = 1 - P(x)` to
///   **15 decimal places**.
/// - **A&S 26.2** — same handbook, Table 26.2, "Normal Curve Percentage Points".
///   Tabulates `x_Q` for given upper-tail area `Q`, to **9 decimal places**.
///   This is the source of the familiar `z(0.975) = 1.959963985`.
/// - **Extended digits** — where a test needs more than the tables print, the
///   value comes from an independent arbitrary-precision evaluation of
///   `erfc(-x/√2)/2` and `√2·erf⁻¹(2p-1)` (mpmath 1.4.1 at 50 decimal digits),
///   *not* from BusinessMath. Every such value's leading digits were checked
///   against the corresponding A&S entry before use.
/// - **Identities** — round trip, symmetry, monotonicity and range need no
///   external source. They are exact claims about the function's definition and
///   are the strongest tests here, because nothing about them can be tuned.
///
/// ## Where the tolerances come from
///
/// | tolerance | used for | justification |
/// |---|---|---|
/// | `1e-15` abs | A&S 26.1 CDF values | the table prints 15 decimals, so the entry itself carries ±5e-16; `Double` ulp near 1 is 2.2e-16. Measured worst case here: **4.4e-16**, at `x = 3.5`, and it is the table's truncation rather than the code's error — the same 4.4e-16 before and after the §2.1 fix. |
/// | `1e-9` abs | A&S 26.2 quantiles | the table prints 9 decimals; this is the reference's precision, not the code's. Measured worst case: **4.4e-16**. |
/// | `1e-14` abs | extended-precision quantiles, \|z\| ≤ 4 | `inverseNormalCDF`'s documented worst case is 1.8e-15 (2 ulp) over `1e-12 ≤ p ≤ 1-1e-12`; 1e-14 leaves ~5× for cross-platform `erfc`/`exp` ulp drift (Darwin vs Linux libm). |
/// | `1e-16` abs | `normalCDF` absolute accuracy, all `x` | held for the old `(1 + erf(x/√2))/2` because `1 + erf` bounds the absolute error at half an ulp at 1, ≈ 5.6e-17, *however small the result is* — measured 2.8e-17. It holds more comfortably for the `erfc(-x/√2)/2` form now in place, which is relatively accurate: measured **6.9e-18**. |
/// | `1e-13` rel | `normalCDF` relative accuracy in the lower tail | the bound §2.1 said the fix had to make true, carried over unchanged from the `withKnownIssue` it used to sit inside. Measured worst case to `x = -8`: **6.5e-15**. |
///
/// No tolerance in this file was chosen by loosening one that failed. Where the
/// library disagreed with the reference the test was marked `withKnownIssue` with
/// the measured magnitude, so that fixing the defect made the marker fail. Three
/// such markers — §2.1's two `normalCDF` tail claims and the duplicate quantile —
/// were removed when the defects were fixed, not when they became inconvenient.
@Suite("Normal CDF and quantile vs published references")
struct NormalReferenceTests {

	// MARK: - normalCDF against A&S Table 26.1

	/// `P(x)` for the standard normal, Abramowitz & Stegun Table 26.1.
	///
	/// The table prints 15 decimals; the 16th and beyond come from the
	/// arbitrary-precision `erfc` evaluation described in the suite comment.
	static let asTable261: [(x: Double, P: Double)] = [
		(0.0, 0.500000000000000),
		(0.5, 0.691462461274013),
		(1.0, 0.841344746068543),
		(1.5, 0.933192798731142),
		(2.0, 0.977249868051821),
		(2.5, 0.993790334674224),
		(3.0, 0.998650101968370),
		(3.5, 0.999767370920964),
		(4.0, 0.999968328758167),
		(5.0, 0.999999713348428)
	]

	@Test("A&S Table 26.1: P(x) for the standard normal")
	func abramowitzStegunTable261() {
		for entry in Self.asTable261 {
			let got = normalCDF(x: entry.x)
			#expect(
				approximatelyEqual(got, entry.P, tolerance: 1e-15),
				"normalCDF(x: \(entry.x)) = \(got), A&S 26.1 gives \(entry.P), differs by \(abs(got - entry.P))"
			)
		}
	}

	@Test("A&S Table 26.1 is reproduced with a mean and standard deviation")
	func table261Shifted() {
		// The same table read through the affine form: P((x-μ)/σ) must equal P(z).
		// Not a second source — a check that the μ/σ parameters do what they claim.
		for entry in Self.asTable261 {
			let shifted = normalCDF(x: 5.6 + 1.2 * entry.x, mean: 5.6, stdDev: 1.2)
			#expect(
				approximatelyEqual(shifted, entry.P, tolerance: 1e-15),
				"normalCDF(x: \(5.6 + 1.2 * entry.x), mean: 5.6, stdDev: 1.2) = \(shifted), A&S 26.1 gives \(entry.P)"
			)
		}
	}

	/// `Q(x) = 1 - P(x)`, the upper tail, from the same A&S table.
	@Test("A&S Table 26.1: Q(x), the upper tail")
	func abramowitzStegunUpperTail() {
		let cases: [(x: Double, Q: Double)] = [
			(1.0, 0.158655253931457),
			(2.0, 0.022750131948179),
			(3.0, 0.001349898031630),
			(4.0, 0.000031671241833),
			(5.0, 0.000000286651572)
		]
		for entry in cases {
			// Q(x) == P(-x) by symmetry, and P(-x) is the well-conditioned way to ask.
			let got = normalCDF(x: -entry.x)
			// Absolute, not relative: see the suite comment on the 1e-16 bound. The
			// table entry itself is only good to ±5e-16 at 15 decimals, so 1e-15
			// is the reference's precision here, not the code's.
			#expect(
				approximatelyEqual(got, entry.Q, tolerance: 1e-15),
				"normalCDF(x: -\(entry.x)) = \(got), A&S 26.1 gives Q = \(entry.Q)"
			)
		}
	}

	// MARK: - inverseNormalCDF against A&S Table 26.2

	@Test("A&S Table 26.2: normal curve percentage points")
	func abramowitzStegunTable262() {
		// x_Q such that Q = 1 - P(x_Q). Printed to 9 decimals, which sets the
		// tolerance: 1e-9 is the table's precision, not the function's.
		let cases: [(Q: Double, x: Double)] = [
			(0.25, 0.674489750),
			(0.1, 1.281551566),
			(0.05, 1.644853627),
			(0.025, 1.959963985),
			(0.01, 2.326347874),
			(0.005, 2.575829304),
			(0.001, 3.090232306),
			(0.0005, 3.290526731),
			(0.0001, 3.719016485)
		]
		for entry in cases {
			let got = inverseNormalCDF(p: 1 - entry.Q)
			#expect(
				approximatelyEqual(got, entry.x, tolerance: 1e-9),
				"inverseNormalCDF(p: \(1 - entry.Q)) = \(got), A&S 26.2 gives \(entry.x)"
			)
		}
		// Q = 0.5 is the one entry the table prints as an exact zero, and the one
		// the implementation short-circuits rather than approximates. `exactlyEqual`
		// and not `identical`: -0.0 is the median too, and pinning the encoding would
		// fail a rewrite that reached zero by mirroring.
		#expect(exactlyEqual(inverseNormalCDF(p: 0.5), 0.0))
	}

	@Test("Extended-precision quantiles across body, shoulders and tails")
	func extendedPrecisionQuantiles() {
		// Each reference is the root of `erfc(-z/√2)/2 = p` at 60 decimal digits,
		// solved for the **exact binary value of the Double `p`** rather than for
		// the decimal it is written as.
		//
		// That distinction is not pedantry, and getting it wrong is the first way
		// this kind of test goes bad. At p = 0.9995 the nearest Double is
		// 0.99950000000000005595…, and dz/dp there is 1/φ(z) = 576, so evaluating
		// the reference at the *decimal* 0.9995 shifts it by 3.1e-14 — seventeen
		// times the function's own worst case, and enough to look like a defect in
		// the code. The library is right; a reference read at the wrong argument is
		// not a reference.
		//
		// The entries that overlap A&S 26.2 reproduce it to all 9 printed decimals.
		let cases: [(p: Double, z: Double)] = [
			(1e-12, -7.034483825301132),
			(1e-9, -5.9978070150076865),
			(1e-6, -4.753424308822899),
			(0.0001, -3.7190164854556804),
			(0.001, -3.0902323061678136),
			(0.005, -2.575829303548901),
			(0.01, -2.326347874040841),
			(0.025, -1.9599639845400543),
			(0.05, -1.6448536269514726),
			(0.1, -1.2815515655446004),
			(0.25, -0.6744897501960817),
			(0.75, 0.6744897501960817),
			(0.9, 1.2815515655446006),
			(0.95, 1.6448536269514722),
			(0.975, 1.9599639845400538),
			(0.99, 2.3263478740408408),
			(0.995, 2.5758293035489004),
			(0.999, 3.090232306167813),
			(0.9995, 3.290526731491926)
		]
		for entry in cases {
			let got = inverseNormalCDF(p: entry.p)
			#expect(
				approximatelyEqual(got, entry.z, tolerance: 1e-14),
				"inverseNormalCDF(p: \(entry.p)) = \(got), reference \(entry.z), differs by \(abs(got - entry.z))"
			)
		}
	}

	@Test("The quantile function stays correct past the old [-10, 10] bracket")
	func deepLowerTailQuantiles() {
		// The bisection body this replaced searched a hard-coded [-10, 10] bracket
		// with a stopping width expressed in z, so it was uniformly coarse and
		// failed outright below about p = 1e-16 — at p = 1e-20 it returned -8.33
		// against a true -9.26. These points are where that failure lived, and
		// they are exactly the region a tail-risk model asks about.
		//
		// Tolerance 1e-13 rather than 1e-14: the documented worst case down the
		// lower tail (to p = 1e-225) is 1.1e-14, an order looser than the 1.8e-15
		// that holds inside 1e-12 ≤ p ≤ 1 - 1e-12. Measured here: 1.8e-15 at
		// p = 1e-30, so the function is holding its inner-range accuracy 18 orders
		// of magnitude further down than that range claims.
		//
		// References are again roots of erfc(-z/√2)/2 = p at the exact binary p,
		// at 60 digits. Note that `√2·erf⁻¹(1 - 2p)` — the obvious way to get these
		// — loses accuracy of its own once 1 - 2p is within an arbitrary-precision
		// library's working epsilon of 1, and produced a value 2.4e-13 away at
		// p = 1e-30. The root of the erfc form does not have that problem.
		let cases: [(p: Double, z: Double)] = [
			(1e-13, -7.348796102800677),
			(1e-15, -7.941345326170997),
			(1e-20, -9.262340089798407),
			(1e-30, -11.464024688443615)
		]
		for entry in cases {
			let got = inverseNormalCDF(p: entry.p)
			#expect(got.isFinite, "inverseNormalCDF(p: \(entry.p)) returned \(got)")
			#expect(
				approximatelyEqual(got, entry.z, tolerance: 1e-13),
				"inverseNormalCDF(p: \(entry.p)) = \(got), reference \(entry.z), differs by \(abs(got - entry.z))"
			)
		}
	}

	// MARK: - Round-trip and symmetry identities

	@Test("normalCDF(inverseNormalCDF(p)) == p in the body")
	func roundTripBody() {
		// Exact claim, no external source. In the body the CDF is well conditioned,
		// so the round trip must return p to within a few ulp. Tolerance is
		// relative at 1e-14: dp/dz = pdf(z), so an error of 2 ulp in z shows up as
		// 2·ulp(z)·pdf(z), under 1e-16 relative for every p here.
		for p in [0.001, 0.01, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.99, 0.999] {
			let back = normalCDF(x: inverseNormalCDF(p: p))
			#expect(
				abs(back - p) / p < 1e-14,
				"round trip at p = \(p) returned \(back), relative error \(abs(back - p) / p)"
			)
		}
	}

	@Test("z(p) == -z(1-p) bit-for-bit for every representable p >= 0.5")
	func symmetryIsExact() {
		// `inverseNormalCDF` documents this as *exact*, not approximate: for
		// p >= 0.5 the subtraction 1 - p is exact in binary floating point
		// (Sterbenz), and the implementation evaluates only the lower tail and
		// mirrors. So this is `identical`, a bit comparison, and it is the
		// assertion that a rewrite reintroducing a two-branch quantile would fail.
		//
		// The direction matters. Starting from p < 0.5 the claim is false, and
		// correctly so: 1 - 0.001 rounds to 0.999, and 1 - 0.999 is
		// 0.0010000000000000009, a different argument. Nothing is wrong; the
		// identity is about a fixed representable p in [0.5, 1).
		for p in [0.55, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99, 0.999, 0.9999, 1 - 1e-9] {
			let upper = inverseNormalCDF(p: p)
			let lower = inverseNormalCDF(p: 1 - p)
			#expect(
				identical(upper, -lower),
				"z(\(p)) = \(upper) but -z(\(1 - p)) = \(-lower)"
			)
		}
		// At p = 0.5 the mirror is +0.0 against -0.0. Both are the median, so the
		// claim there is IEEE equality, not bit equality.
		#expect(exactlyEqual(inverseNormalCDF(p: 0.5), -inverseNormalCDF(p: 0.5)))
	}

	@Test("normalCDF is monotone and lands in [0, 1] over [-10, 10]")
	func cdfMonotoneAndBounded() {
		var previous = -Double.infinity
		var violations = 0
		for step in 0...2000 {
			let x = -10 + 0.01 * Double(step)
			let value = normalCDF(x: x)
			if value < previous { violations += 1 }
			#expect(value >= 0 && value <= 1, "normalCDF(x: \(x)) = \(value) is outside [0, 1]")
			previous = value
		}
		#expect(violations == 0, "normalCDF was non-monotone at \(violations) of 2001 sample points")
	}

	@Test("inverseNormalCDF is monotone over (0, 1)")
	func quantileMonotone() {
		// The discontinuity that motivated this file was a monotonicity break in
		// disguise: an interval of z was unreachable because the function jumped.
		// A dense sweep is the cheapest thing that would have caught it.
		var previous = -Double.infinity
		var violations = 0
		for step in 1...9999 {
			let p = Double(step) / 10000.0
			let z = inverseNormalCDF(p: p)
			if z < previous { violations += 1 }
			previous = z
		}
		#expect(violations == 0, "inverseNormalCDF was non-monotone at \(violations) of 9999 sample points")
	}

	@Test("The quantile function has no unreachable interval near u = 0.6")
	func noJumpAtSixTenths() {
		// The specific defect: 0.30 -> 1.372 at u = 0.6. Neighbouring z values must
		// differ by about pdf⁻¹ · Δp, which at p = 0.6 is 0.0026 per 1e-3 of p.
		// A jump of 1.07 is three orders of magnitude larger than the local slope.
		var previous = inverseNormalCDF(p: 0.55)
		for step in 1...100 {
			let p = 0.55 + 0.001 * Double(step)
			let z = inverseNormalCDF(p: p)
			#expect(
				z - previous < 0.01,
				"inverseNormalCDF jumped from \(previous) to \(z) between p = \(p - 0.001) and \(p)"
			)
			previous = z
		}
	}

	@Test("Domain edges return the limits rather than trapping")
	func domainEdges() {
		#expect(inverseNormalCDF(p: 0.0) == -Double.infinity)
		#expect(inverseNormalCDF(p: 1.0) == Double.infinity)
		#expect(inverseNormalCDF(p: -0.5) == -Double.infinity)
		#expect(inverseNormalCDF(p: 1.5) == Double.infinity)
		#expect(inverseNormalCDF(p: Double.nan).isNaN)
	}

	// MARK: - normalCDF in the lower tail (TrustPlan §2.1)

	@Test("normalCDF's absolute error is under 1e-16 everywhere, including the far tail")
	func lowerTailAbsoluteAccuracy() {
		// The claim that held before §2.1 was fixed and still holds after, which is
		// why it was asserted plainly rather than marked. The old
		// `(1 + erf(x/√2))/2` formed `1 + erf` where erf → -1, so the absolute error
		// could not exceed about half an ulp at 1 (5.6e-17) however small the result
		// was — it was the *relative* error that was unbounded. Measured worst case
		// then: 2.8e-17. The `erfc(-x/√2)/2` form now in place is relatively
		// accurate, so its absolute error here is smaller still: 6.9e-18, and it
		// falls away with the tail instead of staying flat (3.8e-30 at z = -8,
		// against the sum form's 1.1e-17).
		let cases: [(z: Double, phi: Double)] = [
			(-1.0, 0.15865525393145705),
			(-2.0, 0.022750131948179207),
			(-3.0, 0.0013498980316300946),
			(-4.0, 3.1671241833119924e-5),
			(-5.0, 2.866515718791939e-7),
			(-6.0, 9.865876450376981e-10),
			(-7.0, 1.279812543885835e-12),
			(-8.0, 6.220960574271782e-16)
		]
		for entry in cases {
			let got = normalCDF(x: entry.z)
			#expect(
				approximatelyEqual(got, entry.phi, tolerance: 1e-16),
				"normalCDF(x: \(entry.z)) = \(got), reference \(entry.phi), absolute error \(abs(got - entry.phi))"
			)
		}
	}

	@Test("normalCDF holds relative precision in the lower tail (TrustPlan §2.1)")
	func lowerTailRelativeAccuracy() {
		// TrustPlan §2.1, now closed. `(1 + erf(x/√2))/2` cancelled catastrophically
		// for negative x: `erf(x/√2)` is `-1 + ε` there, and adding 1 discards every
		// bit of ε below the ulp of 1, so the answer could only land on a multiple of
		// 1.1e-16 however small the true value was. `erfc(-x/√2)/2` is the same
		// quantity by the identity `erfc(z) = 1 - erf(z)` and never forms the
		// cancelling sum.
		//
		// Relative error against the arbitrary-precision reference, before and after:
		//
		//   z = -5.0        Φ = 2.87e-07   3.9e-11  ->  2.0e-15
		//   z = -6.0        Φ = 9.87e-10   1.3e-10  ->  3.4e-15
		//   z = -7.0        Φ = 1.28e-12   2.3e-06  ->  1.6e-16
		//   z = -7.0344838  Φ = 1.00e-12   2.2e-05  ->  6.5e-15   <- the figure in §2.1
		//   z = -8.0        Φ = 6.22e-16   1.8e-02  ->  5.9e-15
		//
		// The old pattern was the 1e-16 absolute bound divided by Φ, so the relative
		// error grew without limit as the tail deepened. The new one is flat.
		//
		// **One reference moved, and it was the reference that was wrong.** The
		// entry at z = -7.034483825301132 read `1e-12`, on the reasoning that this z
		// is the quantile of p = 1e-12. It is the quantile of 1e-12 only to within
		// the rounding of z to a `Double`: Φ at that exact binary z is
		// 9.9999999999999878e-13, which is 1.2e-14 *relative* away from 1e-12. That
		// was invisible against a 2.2e-05 error and is the dominant term against a
		// 6.5e-15 one. The value below is the true Φ at that argument.
		//
		// The bound is 1e-13 and not the measured 6.5e-15 for the same reason the
		// quantile tests leave headroom: `erfc` is a libm entry point and its last
		// ulp differs between Darwin and Linux. It is *not* a loosened tolerance —
		// 1e-13 is the value that was already written here, inside `withKnownIssue`,
		// as the claim this fix had to make true.
		let cases: [(z: Double, phi: Double)] = [
			(-5.0, 2.8665157187919391e-7),
			(-6.0, 9.8658764503769814e-10),
			(-7.0, 1.2798125438858350e-12),
			(-7.034483825301132, 9.9999999999999878e-13),
			(-8.0, 6.2209605742717841e-16)
		]
		for entry in cases {
			let got = normalCDF(x: entry.z)
			let relative = abs(got - entry.phi) / entry.phi
			#expect(
				relative < 1e-13,
				"normalCDF(x: \(entry.z)) relative error \(relative), reference \(entry.phi), got \(got)"
			)
		}
	}

	@Test("normalCDF reaches the tail the sum form could not represent at all")
	func lowerTailDoesNotFlushToZero() {
		// `(1 + erf(x/√2))/2` returns a hard zero below about x = -8.3, because the
		// true value drops under half an ulp at 1 and the addition swallows it. That
		// is not a small error, it is the loss of the entire quantity, and it is the
		// region a tail-risk model actually asks about. The erfc form carries to the
		// underflow limit of the type — about x = -38 for `Double`.
		//
		// References are the Mills-ratio continued fraction
		// `Q(z) = φ(z) / (z + 1/(z + 2/(z + 3/(z + …))))` evaluated in 80-digit
		// decimal. It converges (unlike the usual asymptotic series) and it
		// reproduces this file's existing mpmath entries at z = -5, -6, -7 and -8 to
		// every digit they print, which is what makes it usable as a source here.
		//
		// ## Why the bound is 1e-12 and not the measured 1e-13
		//
		// Not libm slack — arithmetic. `normalCDF` forms `x/√2` in `Double` before
		// `erfc` sees it, and `Q ~ e^(-a²)` in its argument `a`, so a half-ulp error
		// in `a` becomes a relative error of about `2a·ulp(a)` in the result. That
		// floor is 3.6e-15 at z = -9 but 1.4e-14 at z = -20 and 7.3e-14 at z = -37,
		// and no amount of accuracy in `erfc` can go below it without a
		// double-double argument reduction. Measured, against the floor:
		//
		//   z = -9     1.7e-15   (floor 3.6e-15)
		//   z = -10    8.9e-15   (floor 3.5e-15)
		//   z = -20    3.5e-14   (floor 1.4e-14)
		//   z = -37    9.8e-14   (floor 7.3e-14)
		//
		// A tighter bound here would be pinning the last ulp of one platform's
		// `erfc` at an argument where the input itself is only known to 7e-14.
		let cases: [(z: Double, phi: Double)] = [
			(-9.0, 1.1285884059538406e-19),
			(-10.0, 7.6198530241605261e-24),
			(-20.0, 2.7536241186062337e-89),
			(-37.0, 5.7255712225245768e-300)
		]
		for entry in cases {
			let got = normalCDF(x: entry.z)
			#expect(got > 0, "normalCDF(x: \(entry.z)) = \(got), which is the flush-to-zero §2.1 describes")
			#expect(
				abs(got - entry.phi) / entry.phi < 1e-12,
				"normalCDF(x: \(entry.z)) = \(got), reference \(entry.phi), relative error \(abs(got - entry.phi) / entry.phi)"
			)
		}
	}

	@Test("Round-tripping an exact tail quantile returns the probability")
	func roundTripInTheTail() {
		// normalCDF(inverseNormalCDF(p)) == p is exact in the body (tested above)
		// and this is where §2.1 was visible to a caller: the quantile was right to
		// the last ulp, and the CDF could not get back. The loss was entirely in
		// normalCDF, so it went away when the formulation did — `inverseNormalCDF`
		// was not touched.
		//
		// Relative error of the round trip, before and after:
		//   p = 1e-06   2.9e-11  ->  4.0e-15
		//   p = 1e-09   2.8e-08  ->  7.0e-15
		//   p = 1e-12   2.2e-05  ->  5.3e-15
		//   p = 1e-15   8.0e-04  ->  1.2e-14
		//   p = 1e-20   1.0e+00  ->  9.3e-15   (the old form returned a flat zero)
		//   p = 1e-30   1.0e+00  ->  2.8e-14
		//
		// The last two are the interesting ones: a relative error of exactly 1.0 is
		// what "returned zero" looks like, and 1e-20 is inside the range
		// `inverseNormalCDF` documents itself as accurate over.
		//
		// Bound 1e-13, as in `lowerTailRelativeAccuracy`. Below p = 1e-15 the
		// argument-rounding floor described in `lowerTailDoesNotFlushToZero` applies
		// to the return leg as well, which is why 1e-30 sits an order above the rest.
		let cases: [Double] = [1e-6, 1e-9, 1e-12, 1e-15, 1e-20, 1e-30]
		for p in cases {
			let back = normalCDF(x: inverseNormalCDF(p: p))
			let relative = abs(back - p) / p
			#expect(
				relative < 1e-13,
				"round trip at p = \(p) returned \(back), relative error \(relative)"
			)
		}
	}

	// MARK: - Two implementations of the same function

	/// `inverseNormalCDF` and `zScore(percentile:)` were separate quantile
	/// implementations. Comparing them is exactly the test that would have
	/// exposed the discontinuity; it is also what showed one of them was worse,
	/// which is why `zScore(percentile:)` now delegates rather than duplicating.
	@Test("The two quantile entry points agree in the body")
	func quantileImplementationsAgreeInBody() {
		// `zScore(percentile:)` — and `normSInv`, which delegates to it — computed
		// √2·erfInv(2p-1) with two Newton steps against `erf`, against
		// `inverseNormalCDF`'s Acklam seed and one Halley step against `erfc`. In
		// the body the two agreed to 4.4e-16, which is why the divergence in the
		// tail (below) was the only thing that gave the second one away.
		//
		// Now that `zScore(percentile:)` delegates, agreement is bit-exact rather
		// than approximate. The 1e-15 tolerance is kept rather than tightened to
		// `identical`, because this test's job is to catch a *reintroduced* second
		// implementation, and one that agrees to 1e-15 in the body is exactly the
		// kind that would survive a bit test being deleted as too strict.
		for p in [0.01, 0.025, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99] {
			let acklam = inverseNormalCDF(p: p)
			let shim = zScore(percentile: p)
			#expect(
				approximatelyEqual(acklam, shim, tolerance: 1e-15),
				"at p = \(p): inverseNormalCDF gives \(acklam), zScore(percentile:) gives \(shim)"
			)
		}
	}

	@Test("In the tail the quantile entry points no longer diverge")
	func quantileImplementationsDivergeInTail() {
		// Against the arbitrary-precision reference, `inverseNormalCDF` is exact to
		// the last bit at all three points and `zScore(percentile:)` was not. The
		// cause was structural: `erfInv` refined against `erf`, whose value
		// saturates at ±1 in the tail, so the residual `erf(x) - y` underflowed and
		// the Newton correction had nothing left to work with. No tolerance could
		// have fixed that; only the routing.
		//
		//   p       reference z          inverseNormalCDF   zScore(percentile:)
		//   1e-06   -4.753424308822899   0.0                4.6e-12  ->  0.0
		//   1e-09   -5.997807015007687   0.0                5.1e-09  ->  8.9e-16
		//   1e-12   -7.034483825301132   0.0                2.1e-06  ->  0.0
		//
		// The residual 8.9e-16 at p = 1e-09 is one ulp of z and is `inverseNormalCDF`'s
		// own, not a difference between the two: both entry points return the same
		// bits now.
		let cases: [(p: Double, z: Double)] = [
			(1e-6, -4.753424308822899),
			(1e-9, -5.997807015007687),
			(1e-12, -7.034483825301132)
		]
		for entry in cases {
			// The Acklam/Halley path is correct — asserted, not marked.
			#expect(
				approximatelyEqual(inverseNormalCDF(p: entry.p), entry.z, tolerance: 1e-14),
				"inverseNormalCDF(p: \(entry.p)) = \(inverseNormalCDF(p: entry.p)), reference \(entry.z)"
			)
			let shim = zScore(percentile: entry.p)
			#expect(
				abs(shim - entry.z) < 1e-13,
				"zScore(percentile: \(entry.p)) = \(shim), reference \(entry.z), error \(abs(shim - entry.z))"
			)
			// And the claim that stops a second implementation being reintroduced
			// under this name: the shim must be the canonical function, bit for bit.
			#expect(
				identical(shim, inverseNormalCDF(p: entry.p)),
				"zScore(percentile: \(entry.p)) = \(shim) but inverseNormalCDF gives \(inverseNormalCDF(p: entry.p))"
			)
		}
	}

	@Test("normSInv, normInv, normSDist and normDist match the canonical pair in the body")
	func excelCompatibilityShimsAgree() {
		// These are the Excel-named entry points. They must not be a third and
		// fourth answer; in the body they must agree with the canonical functions.
		for p in [0.05, 0.25, 0.5, 0.75, 0.95, 0.975, 0.99] {
			#expect(
				approximatelyEqual(normSInv(probability: p), zScore(percentile: p), tolerance: 1e-15),
				"normSInv(\(p)) disagrees with zScore(percentile: \(p))"
			)
			#expect(
				approximatelyEqual(normInv(probability: p, mean: 0, stdev: 1), inverseNormalCDF(p: p), tolerance: 1e-15),
				"normInv(\(p), 0, 1) disagrees with inverseNormalCDF(p: \(p))"
			)
		}
		for z in [-3.0, -1.96, -1.0, 0.0, 1.0, 1.96, 3.0] {
			#expect(
				identical(normSDist(zScore: z), normalCDF(x: z)),
				"normSDist(\(z)) disagrees with normalCDF(x: \(z))"
			)
			#expect(
				identical(normDist(x: z, mean: 0, stdev: 1), normalCDF(x: z)),
				"normDist(\(z), 0, 1) disagrees with normalCDF(x: \(z))"
			)
			#expect(
				identical(percentile(zScore: z), normalCDF(x: z)),
				"percentile(zScore: \(z)) disagrees with normalCDF(x: \(z))"
			)
		}
	}

	@Test("zScore(ci:) reproduces the published two-sided critical values")
	func confidenceIntervalCriticalValues() {
		// The three numbers every statistics text prints. A&S 26.2 supplies them as
		// x_Q for Q = 0.05, 0.025 and 0.005; tolerance 1e-9 is that table's
		// precision. Measured worst case: 2.2e-15.
		let cases: [(ci: Double, z: Double)] = [
			(0.90, 1.644853627),
			(0.95, 1.959963985),
			(0.99, 2.575829304)
		]
		for entry in cases {
			let got = zScore(ci: entry.ci)
			#expect(
				approximatelyEqual(got, entry.z, tolerance: 1e-9),
				"zScore(ci: \(entry.ci)) = \(got), A&S 26.2 gives \(entry.z)"
			)
		}
	}

	// MARK: - normalPDF

	@Test("normalPDF against closed-form values")
	func densityValues() {
		// φ(0) = 1/√(2π) and φ(1) = e^(-1/2)/√(2π). Closed forms, so the reference
		// carries the full precision of the type; tolerance is 1e-16 (under one ulp
		// of the values here). Measured worst case: 5.6e-17.
		#expect(approximatelyEqual(normalPDF(x: 0.0), 0.3989422804014327, tolerance: 1e-16))
		#expect(approximatelyEqual(normalPDF(x: 1.0), 0.24197072451914337, tolerance: 1e-16))
		#expect(approximatelyEqual(normalPDF(x: -1.0), 0.24197072451914337, tolerance: 1e-16))
		// The density is the derivative of the CDF: a finite difference must match
		// it to O(h²). h = 1e-5 gives a truncation error near 1e-10 at these points.
		for x in [-2.0, -0.5, 0.0, 0.5, 2.0] {
			let h = 1e-5
			let slope = (normalCDF(x: x + h) - normalCDF(x: x - h)) / (2 * h)
			#expect(
				approximatelyEqual(slope, normalPDF(x: x), tolerance: 1e-9),
				"d/dx normalCDF at \(x) is \(slope) but normalPDF says \(normalPDF(x: x))"
			)
		}
	}
}
