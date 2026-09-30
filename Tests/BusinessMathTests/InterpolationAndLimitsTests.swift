//
//  InterpolationAndLimitsTests.swift
//  BusinessMathTests
//
//  The items the five-phase contaminated-input campaign located and deliberately left,
//  because folding them in would have mixed two contract clauses in one diff.
//
//  Two groups, and they are unrelated except in provenance:
//
//  **Interpolation.** `Interpolation/` was not probed until the campaign's last phase. Two
//  defects here are about validation that never ran rather than about NaN: five of the ten
//  vector interpolators reached `validateXY` only through the per-channel scalar initialiser,
//  and an empty `ys` builds zero channels, so `xs` was never examined at all. The third is a
//  boundary condition that discarded its own parameters.
//
//  **The other clauses of the distribution contract.** The campaign made `cdf(nan) → .nan`
//  uniform across all 46 conformers. Its neighbours were already broken and stayed broken: a
//  *finite* argument outside the support, which owes 0 or 1, and an *infinity*, which owes the
//  limit. All three must hold at once, and the screen that makes that possible is `isNaN` —
//  never `isFinite`, which gets the finite half right and the infinite half wrong.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Campaign leftovers: interpolation validation and CDF limits")
struct InterpolationAndLimitsTests {

	// MARK: - Helpers

	/// Elementwise agreement that treats two NaNs as agreeing.
	///
	/// `isEqual(to:)` is IEEE equality, so `Double.nan.isEqual(to: .nan)` is `false` and a
	/// plain `zip(...).allSatisfy` would call two NaN channels a disagreement. `==` on
	/// `[Double]` is not an option at all.
	private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
		lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
	}

	/// The nonsense input the bypass accepted: unsorted, duplicated and contaminated, with no
	/// ordinates at all to check it against.
	private static let nonsenseXs: [Double] = [5, 1, .nan, 1]

	// MARK: - PART A, item 1: the validation bypass in the vector interpolators

	/// `VectorCubicSplineInterpolator(xs: [5, 1, nan, 1], ys: [])` used to **succeed**.
	///
	/// `validateVectorYs` answers dimension 0 for an empty `ys` rather than throwing;
	/// `transposeChannels` then builds zero channels; `vectorChannels` calls `makeChannel`
	/// zero times; and `makeChannel` is the only thing in the vector path that reaches
	/// `validateXY`. So the abscissae were never examined. The constructed value then answered
	/// every query with an empty `VectorN` — which ``VectorSpace`` documents as the additive
	/// identity at every dimension, so it reads as a number rather than as a refusal.
	///
	/// Five of the ten types in the file called `validateXY` directly and were fine. That
	/// asymmetry inside one file is what named the defect, and the fix is the five agreeing
	/// with the five.
	@Test("The five bypassed vector interpolators now refuse nonsense abscissae")
	func bypassedVectorInterpolatorsRefuseNonsense() throws {
		let xs = Self.nonsenseXs
		let empty: [VectorN<Double>] = []
		let expected = InterpolationError.mismatchedSizes(xsCount: 4, ysCount: 0)

		#expect(throws: expected) {
			_ = try VectorCubicSplineInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorPCHIPInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorAkimaInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorCatmullRomInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorBSplineInterpolator(xs: xs, ys: empty)
		}
	}

	/// CONTROL for the five that were already right, so the assertion above is about the fix
	/// and not about something the file did everywhere.
	///
	/// These threw before this change and throw the same error after it. If they had not, the
	/// "make the five agree with the five" reading of the defect would have been wrong.
	@Test("The five already-correct vector interpolators are unchanged")
	func alreadyCorrectVectorInterpolatorsUnchanged() throws {
		let xs = Self.nonsenseXs
		let empty: [VectorN<Double>] = []
		let expected = InterpolationError.mismatchedSizes(xsCount: 4, ysCount: 0)

		#expect(throws: expected) {
			_ = try VectorNearestNeighborInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorPreviousValueInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorNextValueInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorLinearInterpolator(xs: xs, ys: empty)
		}
		#expect(throws: expected) {
			_ = try VectorBarycentricLagrangeInterpolator(xs: xs, ys: empty)
		}
	}

	/// The count check is not the whole of it: **zero-dimension vectors** bypass the same way.
	///
	/// `ys` here has four elements, so the length agreement `validateXY` checks is satisfied,
	/// but every element has dimension 0 — so `transposeChannels` still builds zero channels
	/// and `makeChannel` still never runs. Before the fix this constructed successfully with a
	/// NaN in `xs`; now the contamination screen inside `validateXY` reaches it.
	///
	/// This is the assertion that proves the fix is "validate `xs` up front" rather than
	/// "notice that `ys` is empty".
	@Test("Zero-dimension vectors no longer bypass the abscissa check")
	func zeroDimensionVectorsDoNotBypass() throws {
		let xs = Self.nonsenseXs
		let flat: [VectorN<Double>] = [VectorN<Double>([]), VectorN<Double>([]),
									   VectorN<Double>([]), VectorN<Double>([])]
		var caught: (any Error)?
		do {
			_ = try VectorCubicSplineInterpolator(xs: xs, ys: flat)
		} catch {
			caught = error
		}
		let thrown = try #require(caught, "constructor accepted xs = [5, 1, nan, 1] with four zero-dimension vectors")
		guard case let BusinessMathError.dataQuality(_, context) = thrown else {
			Issue.record("expected dataQuality for the NaN abscissa; got \(thrown)")
			return
		}
		// `xs` carries exactly one NaN, at index 2. The context is what tells a caller which
		// knot to look at, so it is asserted rather than the error case alone.
		#expect(context["first_invalid_index"] == "2", "got \(context)")
		#expect(context["invalid_count"] == "1", "got \(context)")
	}

	/// The empty-everything case, which the count check cannot catch because `0 == 0`.
	///
	/// Two minimums are exercised so the guard is not merely present but carries the number
	/// its scalar counterpart uses: a natural cubic spline needs three points, PCHIP two.
	@Test("Empty xs and ys are refused by the point-count minimum")
	func emptyInputsAreRefusedByTheMinimum() throws {
		let noXs: [Double] = []
		let noYs: [VectorN<Double>] = []

		#expect(throws: InterpolationError.insufficientPoints(required: 3, got: 0)) {
			_ = try VectorCubicSplineInterpolator(xs: noXs, ys: noYs)
		}
		#expect(throws: InterpolationError.insufficientPoints(required: 2, got: 0)) {
			_ = try VectorPCHIPInterpolator(xs: noXs, ys: noYs)
		}
	}

	/// CONTROL. A well-formed vector interpolator still builds, and still agrees channel for
	/// channel with the scalar interpolators it is made of.
	///
	/// A guard added at the top of an initialiser is the cheapest possible way to break the
	/// thing it was meant to protect, and "it throws now" is not evidence that it still works.
	@Test("A well-formed vector cubic spline still builds and interpolates")
	func wellFormedVectorSplineStillWorks() throws {
		let xs: [Double] = [0, 1, 2, 3, 4]
		let squares: [Double] = [0, 1, 4, 9, 16]
		let doubles: [Double] = [0, 2, 4, 6, 8]
		let ys: [VectorN<Double>] = [
			VectorN([squares[0], doubles[0]]),
			VectorN([squares[1], doubles[1]]),
			VectorN([squares[2], doubles[2]]),
			VectorN([squares[3], doubles[3]]),
			VectorN([squares[4], doubles[4]])
		]
		let interp = try VectorCubicSplineInterpolator(xs: xs, ys: ys)
		#expect(interp.outputDimension == 2, "got \(interp.outputDimension)")

		// Pass-through at every knot, the invariant every interpolator in the package holds.
		for i in 0..<xs.count {
			let atKnot: [Double] = interp(xs[i]).toArray()
			let expectedKnot: [Double] = [squares[i], doubles[i]]
			try #require(atKnot.count == expectedKnot.count,
						 "knot \(i): got \(atKnot.count) channels, wanted \(expectedKnot.count)")
			for channel in 0..<expectedKnot.count {
				let deviation: Double = abs(atKnot[channel] - expectedKnot[channel])
				#expect(deviation < 1e-12,
						"knot \(i), channel \(channel): got \(atKnot[channel]), wanted \(expectedKnot[channel])")
			}
		}

		// And off the knots it is exactly the two scalar splines, which is the whole claim the
		// vector flavour makes about itself.
		let channelA = try CubicSplineInterpolator(xs: xs, ys: squares)
		let channelB = try CubicSplineInterpolator(xs: xs, ys: doubles)
		let vectorAt: [Double] = interp(2.5).toArray()
		let scalarAt: [Double] = [channelA(2.5), channelB(2.5)]
		#expect(agree(vectorAt, scalarAt), "got \(vectorAt), channels gave \(scalarAt)")
	}

	// MARK: - PART A, item 2: the two-point clamped spline

	/// The two-point `.clamped` case returned `[0, 0]` for the second derivatives, with the
	/// comment "second derivatives are 0".
	///
	/// That is true only when `left == right == delta` — the straight line the slopes already
	/// describe. For any other endpoint slopes the caller's `left` and `right` were silently
	/// discarded while `interp.boundary` went on reporting them, so `.clamped` ignored the one
	/// thing it exists to specify, and the interpolant collapsed to the chord.
	///
	/// The expected values are **derived here from the interpolation conditions**, not copied
	/// from the implementation: there is exactly one cubic `p` with `p(x0) = y0`, `p(x1) = y1`,
	/// `p'(x0) = left` and `p'(x1) = right`, and solving those four equations for
	/// `p(x) = y0 + L·u + c·u² + d·u³` in `u = x - x0` gives
	/// `c = (3δ - 2L - R)/h` and `d = (L + R - 2δ)/h²`. The spline's own route to the same
	/// curve — a tridiagonal solve for second derivatives, then the `A`/`B` evaluation — shares
	/// no arithmetic with that, so agreement is a real cross-check rather than a restatement.
	@Test("Two-point clamped spline honours endpoint slopes that differ")
	func twoPointClampedHonoursItsSlopes() throws {
		let x0: Double = 0
		let x1: Double = 2
		let y0: Double = 1
		let y1: Double = 5
		let left: Double = 0.5
		let right: Double = 3.0
		// Deliberately all different: left != right, and neither equals the chord slope. The
		// fixture this replaces used left == right == delta, which is the one case the old
		// code got right, so it could not fail however wrong the branch was.
		let h: Double = x1 - x0
		let delta: Double = (y1 - y0) / h
		#expect(!left.isEqual(to: right), "fixture must not be symmetric in its slopes")
		#expect(!left.isEqual(to: delta), "fixture must not sit on the chord")
		#expect(!right.isEqual(to: delta), "fixture must not sit on the chord")

		let cubicC: Double = (3 * delta - 2 * left - right) / h
		let quarticD: Double = (left + right - 2 * delta) / (h * h)
		func hermite(_ t: Double) -> Double {
			let u: Double = t - x0
			let linear: Double = y0 + left * u
			let quadratic: Double = cubicC * u * u
			let cubic: Double = quarticD * u * u * u
			return linear + quadratic + cubic
		}

		let interp = try CubicSplineInterpolator(
			xs: [x0, x1], ys: [y0, y1], boundary: .clamped(left: left, right: right)
		)

		// Four interior probes plus both knots. Four points determine a cubic, so agreeing at
		// six pins the whole curve, not one convenient spot.
		let probes: [Double] = [0.0, 0.25, 0.5, 1.0, 1.5, 2.0]
		for t in probes {
			let got: Double = interp(t)
			let want: Double = hermite(t)
			let error: Double = abs(got - want)
			#expect(error < 1e-12, "at t = \(t): got \(got), wanted \(want), off by \(error)")
		}

		// COMPUTE THE WRONG VERSION TOO. `[0, 0]` second derivatives make the interpolant the
		// chord. Showing the result is far from the chord, and naming the gap, proves the
		// mechanism rather than merely that something changed.
		let chordAtOne: Double = y0 + delta * (1.0 - x0)
		let gotAtOne: Double = interp(1.0)
		let gap: Double = abs(gotAtOne - chordAtOne)
		#expect(gap > 0.5,
				"the old branch returned the chord \(chordAtOne) here; got \(gotAtOne), gap \(gap)")
	}

	/// CONTROL. The degenerate case the old branch was written for still gives a straight line.
	///
	/// This is the assertion the replaced fixture was making, kept deliberately: when
	/// `left == right == delta` the second derivatives really are zero, and the fix must not
	/// have moved that. It passes before and after, which is what makes it a control.
	@Test("Two-point clamped is still linear when both slopes equal the chord")
	func twoPointClampedStillLinearWhenSlopesMatchTheChord() throws {
		let interp = try CubicSplineInterpolator(
			xs: [0.0, 1.0], ys: [0.0, 1.0], boundary: .clamped(left: 1.0, right: 1.0)
		)
		let probes: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
		for t in probes {
			let got: Double = interp(t)
			let error: Double = abs(got - t)
			#expect(error < 1e-12, "at t = \(t): got \(got), wanted \(t)")
		}
	}

	// MARK: - PART B: the other clauses of the distribution contract
	//
	// Three answers must hold at the same time, per conformer:
	//   - a **finite** argument outside the support returns 0 or 1;
	//   - an **infinity** returns the limit, because it is an ordered point on the line;
	//   - a **NaN** returns `.nan`, because it names no point at all.
	// Screening `isFinite` satisfies the first and breaks the second, which is how an agent
	// nearly shipped this during the campaign. Each test below asserts all three together for
	// that reason, plus an interior value against an independent closed form so a guard that
	// swallowed ordinary arguments would be caught here and not downstream.

	/// `DistributionBeta` routes through `regularizedIncompleteBeta`, whose
	/// `guard x >= 0 && x <= 1` **throws**; `totalizedResult` turns that into `nan`. So every
	/// argument outside `[0, 1]` — `1.5` as much as `+infinity` — answered "cannot be
	/// computed" where the answer is 0 or 1.
	@Test("DistributionBeta: below support, above support, both infinities, NaN")
	func betaObeysAllThreeClauses() throws {
		let beta = DistributionBeta(alpha: 2, beta: 3)

		let belowFinite: Double = beta.cdf(-0.5)
		#expect(belowFinite.isEqual(to: 0.0), "finite below support; got \(belowFinite)")
		let aboveFinite: Double = beta.cdf(1.5)
		#expect(aboveFinite.isEqual(to: 1.0), "finite above support; got \(aboveFinite)")

		let atMinusInfinity: Double = beta.cdf(-Double.infinity)
		#expect(atMinusInfinity.isEqual(to: 0.0), "at -inf; got \(atMinusInfinity)")
		let atPlusInfinity: Double = beta.cdf(Double.infinity)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")

		let atNaN: Double = beta.cdf(Double.nan)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")

		// The support boundaries themselves, which the new guards now answer rather than the
		// special function. Both were already correct and must stay so.
		let atZero: Double = beta.cdf(0.0)
		#expect(atZero.isEqual(to: 0.0), "at 0; got \(atZero)")
		let atOne: Double = beta.cdf(1.0)
		#expect(atOne.isEqual(to: 1.0), "at 1; got \(atOne)")

		// INTERIOR ORACLE. For integer shapes the regularized incomplete beta is a binomial
		// tail: I_x(a, b) = Σ_{j=a}^{n} C(n, j) x^j (1-x)^(n-j) with n = a + b - 1. For
		// Beta(2, 3), n = 4, so I_x(2,3) = 6x²(1-x)² + 4x³(1-x) + x⁴ — no continued fraction
		// anywhere in it.
		let x: Double = 0.5
		let complement: Double = 1 - x
		let termTwo: Double = 6 * x * x * complement * complement
		let termThree: Double = 4 * x * x * x * complement
		let termFour: Double = x * x * x * x
		let closedForm: Double = termTwo + termThree + termFour
		let interior: Double = beta.cdf(x)
		let interiorError: Double = abs(interior - closedForm)
		#expect(interiorError < 1e-12,
				"interior: got \(interior), binomial tail gives \(closedForm)")
	}

	/// `DistributionF` fails at both ends for different reasons. Below the support `fCDF`
	/// throws ("F-statistic must be non-negative"); above it, `fCDF` forms
	/// `d₁x / (d₁x + d₂)` = `inf/inf` = `nan` internally, and `regularizedIncompleteBeta`
	/// throws on *that*. `totalizedResult` reported both as `nan`.
	@Test("DistributionF: below support, both infinities, NaN")
	func fObeysAllThreeClauses() throws {
		let f = DistributionF(df1: 5, df2: 9)

		let belowFinite: Double = f.cdf(-1.0)
		#expect(belowFinite.isEqual(to: 0.0), "finite below support; got \(belowFinite)")
		let atZero: Double = f.cdf(0.0)
		#expect(atZero.isEqual(to: 0.0), "at 0; got \(atZero)")

		let atMinusInfinity: Double = f.cdf(-Double.infinity)
		#expect(atMinusInfinity.isEqual(to: 0.0), "at -inf; got \(atMinusInfinity)")
		let atPlusInfinity: Double = f.cdf(Double.infinity)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")

		let atNaN: Double = f.cdf(Double.nan)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")

		// INTERIOR ORACLE. With df1 = 2 the F CDF has an elementary closed form,
		// P(F ≤ f) = 1 - (1 + (d₁/d₂)·f)^(-d₂/2), which shares no code with the incomplete
		// beta the implementation uses. At d₂ = 4 and f = 2 it is 1 - 2⁻² = 0.75 exactly.
		let elementary = DistributionF(df1: 2, df2: 4)
		let statistic: Double = 2.0
		let ratio: Double = 1 + statistic / 2
		let closedForm: Double = 1 - 1 / (ratio * ratio)
		let interior: Double = elementary.cdf(statistic)
		let interiorError: Double = abs(interior - closedForm)
		#expect(interiorError < 1e-12,
				"interior: got \(interior), closed form gives \(closedForm)")
	}

	/// `DistributionPearson6` already answered 0 below the support. At `+infinity` its map
	/// `y/(1+y)` formed `inf/inf` = `nan`, the incomplete beta threw on it, and the `catch`
	/// annotated "unreachable" returned `nan` where a CDF is certainly 1.
	@Test("DistributionPearson6: below support, both infinities, NaN")
	func pearson6ObeysAllThreeClauses() throws {
		let p6 = try #require(DistributionPearson6(alpha1: 2, alpha2: 3, beta: 1))

		let belowFinite: Double = p6.cdf(-1.0)
		#expect(belowFinite.isEqual(to: 0.0), "finite below support; got \(belowFinite)")
		let atZero: Double = p6.cdf(0.0)
		#expect(atZero.isEqual(to: 0.0), "at 0; got \(atZero)")

		let atMinusInfinity: Double = p6.cdf(-Double.infinity)
		#expect(atMinusInfinity.isEqual(to: 0.0), "at -inf; got \(atMinusInfinity)")
		let atPlusInfinity: Double = p6.cdf(Double.infinity)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")

		let atNaN: Double = p6.cdf(Double.nan)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")

		// INTERIOR ORACLE. F(x) = I(y/(1+y); α₁, α₂) with y = x/β. At β = 1 and x = 1 the map
		// gives exactly 0.5, and I_0.5(2, 3) is the same binomial tail used above: 0.6875.
		let x: Double = 0.5
		let complement: Double = 1 - x
		let termTwo: Double = 6 * x * x * complement * complement
		let termThree: Double = 4 * x * x * x * complement
		let termFour: Double = x * x * x * x
		let closedForm: Double = termTwo + termThree + termFour
		let interior: Double = p6.cdf(1.0)
		let interiorError: Double = abs(interior - closedForm)
		#expect(interiorError < 1e-12,
				"interior: got \(interior), binomial tail gives \(closedForm)")
	}

	/// `gammaCDF` had **one guard answering two questions** —
	/// `guard x >= T.zero, !x.isNaN else { return T.nan }`. "Below the support" and "cannot be
	/// evaluated" are different answers, and conflating them told a caller who asked for
	/// P(X ≤ -1) that the probability could not be computed, when it is exactly 0.
	@Test("gammaCDF: below support, both infinities, NaN")
	func gammaCDFObeysAllThreeClauses() throws {
		let shape: Double = 2
		let scale: Double = 1

		let belowFinite: Double = gammaCDF(-1.0, shape: shape, scale: scale)
		#expect(belowFinite.isEqual(to: 0.0), "finite below support; got \(belowFinite)")
		let atZero: Double = gammaCDF(0.0, shape: shape, scale: scale)
		#expect(atZero.isEqual(to: 0.0), "at 0; got \(atZero)")

		let atMinusInfinity: Double = gammaCDF(-Double.infinity, shape: shape, scale: scale)
		#expect(atMinusInfinity.isEqual(to: 0.0), "at -inf; got \(atMinusInfinity)")
		let atPlusInfinity: Double = gammaCDF(Double.infinity, shape: shape, scale: scale)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")

		let atNaN: Double = gammaCDF(Double.nan, shape: shape, scale: scale)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")

		// A bad shape or scale is still `nan`, and that is a different question from a bad `x`
		// — the whole point of splitting the guard is that the two no longer share an answer
		// by accident.
		let badShape: Double = gammaCDF(1.0, shape: 0, scale: scale)
		#expect(badShape.isNaN, "non-positive shape; got \(badShape)")
		let badScale: Double = gammaCDF(1.0, shape: shape, scale: 0)
		#expect(badScale.isNaN, "non-positive scale; got \(badScale)")

		// INTERIOR ORACLE. Gamma(shape 2, scale 1) is Erlang-2, whose CDF is the elementary
		// 1 - e^(-x)(1 + x) — no series, no continued fraction, no shared code.
		let x: Double = 1.0
		let decay: Double = Double.exp(-x)
		let closedForm: Double = 1 - decay * (1 + x)
		let interior: Double = gammaCDF(x, shape: shape, scale: scale)
		let interiorError: Double = abs(interior - closedForm)
		#expect(interiorError < 1e-12,
				"interior: got \(interior), Erlang-2 closed form gives \(closedForm)")

		// `erlangCDF` delegates, so it inherits the fix rather than restating it. Asserted so
		// that a future divergence between the two is a failure and not a surprise.
		let erlangBelow: Double = erlangCDF(-1.0, k: 2, beta: scale)
		#expect(erlangBelow.isEqual(to: 0.0), "erlangCDF below support; got \(erlangBelow)")
		let erlangAbove: Double = erlangCDF(Double.infinity, k: 2, beta: scale)
		#expect(erlangAbove.isEqual(to: 1.0), "erlangCDF at +inf; got \(erlangAbove)")
	}

	/// `DistributionGamma` was not on the list, and is fixed anyway: its `cdf` is a thin
	/// forward to `gammaCDF`, so it inherited the conflated guard and answered `nan` below its
	/// own support. Asserted here so the inheritance is recorded rather than assumed.
	@Test("DistributionGamma inherits the gammaCDF fix")
	func gammaDistributionInheritsTheFix() throws {
		let gamma = try #require(DistributionGamma(shape: 2, rate: 1))
		let belowFinite: Double = gamma.cdf(-1.0)
		#expect(belowFinite.isEqual(to: 0.0), "finite below support; got \(belowFinite)")
		let atMinusInfinity: Double = gamma.cdf(-Double.infinity)
		#expect(atMinusInfinity.isEqual(to: 0.0), "at -inf; got \(atMinusInfinity)")
		let atPlusInfinity: Double = gamma.cdf(Double.infinity)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")
		let atNaN: Double = gamma.cdf(Double.nan)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")
	}

	/// CONTROL for the whole of Part B: the special function underneath is **not** a CDF and
	/// keeps its own contract.
	///
	/// `regularizedLowerIncompleteGamma`'s domain is the integral's — γ(a, x) is undefined for
	/// a negative upper limit — so `nan` below zero is the right answer there and was left
	/// alone. The distribution built on it owes 0; the special function does not. If this ever
	/// starts returning 0, the two contracts have been tidied into agreement and one of them
	/// is now wrong.
	@Test("The special function keeps its own domain, and its +infinity")
	func specialFunctionKeepsItsOwnContract() throws {
		let belowDomain: Double = regularizedLowerIncompleteGamma(a: 2.0, x: -1.0)
		#expect(belowDomain.isNaN, "negative upper limit is outside γ's domain; got \(belowDomain)")
		let atNaN: Double = regularizedLowerIncompleteGamma(a: 2.0, x: Double.nan)
		#expect(atNaN.isNaN, "at nan; got \(atNaN)")
		// `+infinity` is kept, not screened: the whole mass lies below it, so P is 1.
		let atPlusInfinity: Double = regularizedLowerIncompleteGamma(a: 2.0, x: Double.infinity)
		#expect(atPlusInfinity.isEqual(to: 1.0), "at +inf; got \(atPlusInfinity)")
	}
}
