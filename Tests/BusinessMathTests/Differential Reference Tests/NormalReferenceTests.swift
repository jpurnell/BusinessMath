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
/// | `1e-15` abs | A&S 26.1 CDF values | the table prints 15 decimals, so the entry itself carries ±5e-16; `Double` ulp near 1 is 2.2e-16. Measured worst case here: **1.1e-16**. |
/// | `1e-9` abs | A&S 26.2 quantiles | the table prints 9 decimals; this is the reference's precision, not the code's. Measured worst case: **4.4e-16**. |
/// | `1e-14` abs | extended-precision quantiles, \|z\| ≤ 4 | `inverseNormalCDF`'s documented worst case is 1.8e-15 (2 ulp) over `1e-12 ≤ p ≤ 1-1e-12`; 1e-14 leaves ~5× for cross-platform `erfc`/`exp` ulp drift (Darwin vs Linux libm). |
/// | `1e-16` abs | `normalCDF` absolute accuracy, all `x` | `(1 + erf(x/√2))/2` forms `1 + erf` where `erf → -1`, so the absolute error is bounded by half an ulp at 1, ≈ 5.6e-17, *however small the result is*. Measured worst case over the whole sweep: **2.9e-17**. |
/// | `1e-15` rel | `normalCDF` relative accuracy, `Φ(x) ≥ 1e-3` | follows from the 1e-16 absolute bound. |
///
/// No tolerance in this file was chosen by loosening one that failed. Where the
/// library disagrees with the reference the test is marked `withKnownIssue` with
/// the measured magnitude, so that fixing the defect makes the marker fail.
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
		// This is the claim that survives §2.1 being fixed, so it is asserted
		// plainly rather than marked. `(1 + erf(x/√2))/2` forms `1 + erf` where
		// erf → -1, so whatever cancels, the absolute error cannot exceed about
		// half an ulp at 1 (5.6e-17). Measured worst case below: 2.9e-17.
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

	@Test("normalCDF's relative error in the lower tail (TrustPlan §2.1)")
	func lowerTailRelativeAccuracyIsPoor() {
		// TrustPlan §2.1: `(1 + erf(x/√2))/2` cancels catastrophically for negative
		// x. `erfc(-x/√2)/2` computes the same quantity to ~1e-15 relative. This
		// test records the gap; it does not close it — closing it is §2.1's own
		// work, and it moves expectations across the whole suite.
		//
		// Measured today, relative error against the arbitrary-precision reference:
		//
		//   z = -5.0        Φ = 2.87e-07   rel = 3.9e-11
		//   z = -6.0        Φ = 9.87e-10   rel = 1.3e-10
		//   z = -7.0        Φ = 1.28e-12   rel = 2.3e-06
		//   z = -7.0344838  Φ = 1.00e-12   rel = 2.2e-05   <- the figure in §2.1
		//   z = -8.0        Φ = 6.22e-16   rel = 1.8e-02
		//
		// The pattern is the 1e-16 absolute bound divided by Φ, so the relative
		// error grows without limit as the tail deepens.
		let cases: [(z: Double, phi: Double, measuredRelative: Double)] = [
			(-7.0, 1.279812543885835e-12, 2.31e-6),
			(-7.034483825301132, 1e-12, 2.22e-5),
			(-8.0, 6.220960574271782e-16, 1.85e-2)
		]
		for entry in cases {
			let got = normalCDF(x: entry.z)
			let relative = abs(got - entry.phi) / entry.phi
			// The upper bound is the measured value with 15% of headroom. It is an
			// observation of current behaviour, and it stays true if §2.1 improves
			// the function — an erfc formulation lands four orders below it.
			#expect(
				relative < entry.measuredRelative * 1.15,
				"normalCDF(x: \(entry.z)) relative error \(relative) exceeded the recorded \(entry.measuredRelative)"
			)
			// And the claim that fails today and must start passing when §2.1 lands.
			withKnownIssue(
				"TrustPlan §2.1: normalCDF loses relative precision in the lower tail. Measured \(entry.measuredRelative) relative at z = \(entry.z); an erfc(-x/√2)/2 formulation gives ~1e-15. Do not loosen this tolerance — fix the formulation."
			) {
				#expect(relative < 1e-13)
			}
		}
	}

	@Test("Round-tripping an exact tail quantile shows the same loss")
	func roundTripInTheTail() {
		// normalCDF(inverseNormalCDF(p)) == p is exact in the body (tested above)
		// and is where §2.1 becomes visible to a caller: the quantile is right to
		// the last ulp, and the CDF cannot get back.
		//
		// Measured relative error of the round trip:
		//   p = 1e-06   2.9e-11
		//   p = 1e-09   2.8e-08
		//   p = 1e-12   2.2e-05
		let cases: [(p: Double, measuredRelative: Double)] = [
			(1e-6, 2.88e-11),
			(1e-9, 2.83e-8),
			(1e-12, 2.22e-5)
		]
		for entry in cases {
			let back = normalCDF(x: inverseNormalCDF(p: entry.p))
			let relative = abs(back - entry.p) / entry.p
			#expect(
				relative < entry.measuredRelative * 1.15,
				"round trip at p = \(entry.p) returned \(back), relative error \(relative)"
			)
			withKnownIssue(
				"TrustPlan §2.1: the round trip loses \(entry.measuredRelative) relative at p = \(entry.p), entirely in normalCDF."
			) {
				#expect(relative < 1e-13)
			}
		}
	}

	// MARK: - Two implementations of the same function

	/// `inverseNormalCDF` and `zScore(percentile:)` are separate quantile
	/// implementations. Comparing them is exactly the test that would have
	/// exposed the discontinuity.
	@Test("The two quantile implementations agree in the body")
	func quantileImplementationsAgreeInBody() {
		// `zScore(percentile:)` — and `normSInv`, which delegates to it — computes
		// √2·erfInv(2p-1) with two Newton steps against `erf`. `inverseNormalCDF`
		// uses an Acklam seed with one Halley step against `erfc`. Different code,
		// same function; in the body they must agree to a few ulp.
		//
		// Tolerance 1e-15: measured worst case over 0.01 ≤ p ≤ 0.99 is 4.4e-16.
		for p in [0.01, 0.025, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.95, 0.975, 0.99] {
			let acklam = inverseNormalCDF(p: p)
			let erfBased = zScore(percentile: p)
			#expect(
				approximatelyEqual(acklam, erfBased, tolerance: 1e-15),
				"at p = \(p): inverseNormalCDF gives \(acklam), zScore(percentile:) gives \(erfBased)"
			)
		}
	}

	@Test("In the tail the two implementations diverge, and erfInv is the wrong one")
	func quantileImplementationsDivergeInTail() {
		// Against the arbitrary-precision reference, `inverseNormalCDF` is exact to
		// the last bit at all three points and `zScore(percentile:)` is not. The
		// cause is structural: erfInv refines against `erf`, whose argument
		// saturates at ±1 in the tail, so the Newton correction has nothing left to
		// work with.
		//
		//   p       reference z          inverseNormalCDF err   zScore(percentile:) err
		//   1e-06   -4.753424308822899   0.0                    4.6e-12
		//   1e-09   -5.997807015007687   0.0                    5.1e-09
		//   1e-12   -7.034483825301132   0.0                    2.1e-06
		let cases: [(p: Double, z: Double, erfInvError: Double)] = [
			(1e-6, -4.753424308822899, 4.58e-12),
			(1e-9, -5.997807015007687, 5.08e-9),
			(1e-12, -7.034483825301132, 2.14e-6)
		]
		for entry in cases {
			// The Acklam/Halley path is correct — asserted, not marked.
			#expect(
				approximatelyEqual(inverseNormalCDF(p: entry.p), entry.z, tolerance: 1e-14),
				"inverseNormalCDF(p: \(entry.p)) = \(inverseNormalCDF(p: entry.p)), reference \(entry.z)"
			)
			let erfBased = zScore(percentile: entry.p)
			let error = abs(erfBased - entry.z)
			#expect(
				error < entry.erfInvError,
				"zScore(percentile: \(entry.p)) error \(error) exceeded the recorded \(entry.erfInvError)"
			)
			withKnownIssue(
				"zScore(percentile:) / normSInv / erfInv is a second, less accurate quantile implementation: \(entry.erfInvError) absolute error at p = \(entry.p) where inverseNormalCDF is exact. Route it through inverseNormalCDF rather than loosening this."
			) {
				#expect(error < 1e-13)
			}
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
