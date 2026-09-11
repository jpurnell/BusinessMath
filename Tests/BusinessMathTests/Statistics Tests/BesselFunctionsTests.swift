//
//  BesselFunctionsTests.swift
//  BusinessMathTests
//
//  Three layers, deliberately independent, because they fail for different
//  reasons:
//
//  1. Reference values, from mpmath at 40 digits. Never from what the
//     implementation returns — see Scripts/reference-fixtures/generate_bessel.py
//     for why the oracle is mpmath and not SciPy, whose own error reaches 3.6e-12
//     at large argument and would fail a correct implementation.
//  2. Identities, which relate functions computed by different methods and so
//     catch a whole class of error a table lookup at one order would miss.
//  3. Boundaries and invalid input, which are exact and need no tolerance at all.
//
//  Plus a fourth, unplanned layer: one regression per defect found while the
//  implementation was being written. Each of those returned a plausible number of
//  the right magnitude, which is the failure mode this family is prone to.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Bessel functions — reference, identity and boundary")
struct BesselFunctionsTests {

	// MARK: - Tolerances

	/// What a forward evaluation is held to, per section 6.4 of the design proposal.
	static let relativeTolerance = 1e-12

	/// Identities are held tighter than reference values because both sides are
	/// computed here, in the same arithmetic, and neither carries a conversion.
	static let identityTolerance = 1e-13

	/// Excel's own error on this family, from section 3.2 of the proposal: its
	/// `BESSELJ` diverges from the true value at the eighth significant figure.
	/// Assertions against a measured Excel cell are held to Excel's budget, not
	/// to ours — matching it any more closely would mean being wrong.
	static let excelTolerance = 3e-8

	// MARK: - Grids
	//
	// Bound as named statics of plain decimal literals. Arithmetic inside an array
	// literal fed through `@Test(arguments:)` has taken the type checker down on
	// this project before.

	/// Either side of every method boundary: 2 (Temme to Steed), 4 (series to
	/// Miller), and about 18.02 (Miller to Hankel asymptotic).
	static let boundaryArguments: [Double] = [
		0.5, 1.0, 1.9, 2.0, 2.1, 3.0, 4.0, 4.1, 5.0, 8.0, 12.0,
		15.0, 17.9, 18.0, 18.1, 20.0, 50.0, 100.0, 500.0
	]

	/// Orders straddling `n < x` in both directions, so both recurrence branches run.
	static let identityOrders: [Int] = [0, 1, 2, 5, 10, 25]

	/// The first three zeros of J₀, to twelve significant figures.
	static let firstZerosOfJ0: [Double] = [
		2.404825557695773, 5.520078110286311, 8.653727912911013
	]

	// MARK: - How an oscillatory error is scaled

	/// The scale a J or Y error is judged against.
	///
	/// Jₙ and Yₙ pass through zero infinitely often, and at a crossing **no** method
	/// achieves a relative bound — the answer is a difference of larger quantities
	/// and any reference carries the same cancellation. The error is therefore
	/// measured against the local oscillation amplitude √(2/πx), which is the
	/// accuracy actually available there.
	///
	/// Said explicitly because a suite that demanded relative precision at a zero is
	/// a suite somebody loosens later without knowing why it was ever tight.
	static func oscillatoryScale(x: Double, expected: Double) -> Double {
		let piX: Double = Double.pi * x
		let squared: Double = 2.0 / piX
		let amplitude: Double = squared.squareRoot()
		return Swift.max(abs(expected), amplitude)
	}

	// MARK: - Layer 1: reference values

	@Test("All four functions match mpmath at 40 digits, across every method branch")
	func matchesHighPrecisionReference() throws {
		let fixture = try ReferenceFixture.load("besselFunctions")
		let names = try #require(fixture.functionOrder)
		#expect(names == ["besselJ", "besselY", "besselI", "besselK"])
		#expect(fixture.cases.count == 696)

		var checked = 0
		for testCase in fixture.cases {
			let marker = try testCase.required("function", in: fixture.name)
			let x = try testCase.required("x", in: fixture.name)
			let orderValue = try testCase.required("n", in: fixture.name)
			let expected = try testCase.required("value", in: fixture.name)
			let n = Int(orderValue)
			let which = Int(marker)

			let actual: Double
			let scale: Double
			switch which {
			case 0:
				actual = besselJ(x: x, order: n)
				scale = Self.oscillatoryScale(x: x, expected: expected)
			case 1:
				actual = besselY(x: x, order: n)
				scale = Self.oscillatoryScale(x: x, expected: expected)
			case 2:
				actual = besselI(x: x, order: n)
				scale = abs(expected)
			default:
				actual = besselK(x: x, order: n)
				scale = abs(expected)
			}

			let error = abs(actual - expected)
			let bound = scale * Self.relativeTolerance
			#expect(error <= bound,
					"\(names[which])(x: \(x), order: \(n)) = \(actual), expected \(expected)")
			checked += 1
		}
		#expect(checked == 696)
	}

	@Test("Published values at x = 1, to ten significant figures")
	func matchesPublishedValuesAtOne() {
		let j0: Double = besselJ(x: 1.0, order: 0)
		let j1: Double = besselJ(x: 1.0, order: 1)
		let y0: Double = besselY(x: 1.0, order: 0)
		let y1: Double = besselY(x: 1.0, order: 1)
		let i0: Double = besselI(x: 1.0, order: 0)
		let i1: Double = besselI(x: 1.0, order: 1)
		let k0: Double = besselK(x: 1.0, order: 0)
		let k1: Double = besselK(x: 1.0, order: 1)

		#expect(abs(j0 - 0.7651976865579666) <= 1e-15, "J0(1) = \(j0)")
		#expect(abs(j1 - 0.4400505857449335) <= 1e-15, "J1(1) = \(j1)")
		#expect(abs(y0 - 0.08825696421567696) <= 1e-15, "Y0(1) = \(y0)")
		#expect(abs(y1 + 0.7812128213002887) <= 1e-15, "Y1(1) = \(y1)")
		#expect(abs(i0 - 1.2660658777520084) <= 1e-15, "I0(1) = \(i0)")
		#expect(abs(i1 - 0.565159103992485) <= 1e-15, "I1(1) = \(i1)")
		#expect(abs(k0 - 0.42102443824070834) <= 1e-15, "K0(1) = \(k0)")
		#expect(abs(k1 - 0.6019072301972346) <= 1e-15, "K1(1) = \(k1)")
	}

	/// The design proposal's own reference table, section 10 — corrected.
	///
	/// Two of its twelve entries are wrong, and this test records the corrections
	/// rather than inheriting them:
	///
	/// | Entry | Proposal | Correct |
	/// |---|---|---|
	/// | Y₂(1.5) | `-0.9321937507` | `-0.9321937598` |
	/// | K₂(1.5) | `0.5836559627` | `0.5836559633` |
	///
	/// Section 1 of the same document gives Y₂(1.5) as `-1.1194180169`, which
	/// disagrees with both. The value asserted here is confirmed two ways: mpmath
	/// evaluates it directly, and the three-term recurrence reaches it from Y₀ and
	/// Y₁ — which share no code path with the direct evaluation.
	@Test("The proposal's reference table at x = 1.5, with its two errors corrected")
	func matchesCorrectedProposalTable() {
		let j2: Double = besselJ(x: 1.5, order: 2)
		let y2: Double = besselY(x: 1.5, order: 2)
		let i2: Double = besselI(x: 1.5, order: 2)
		let k2: Double = besselK(x: 1.5, order: 2)

		#expect(abs(j2 - 0.23208767214421472) <= 1e-15, "J2(1.5) = \(j2)")
		#expect(abs(y2 + 0.9321937597629739) <= 1e-15, "Y2(1.5) = \(y2)")
		#expect(abs(i2 - 0.33783461833568074) <= 1e-15, "I2(1.5) = \(i2)")
		#expect(abs(k2 - 0.5836559632566508) <= 1e-15, "K2(1.5) = \(k2)")
	}

	// MARK: - Layer 2: identities

	/// Jₙ(x)·Yₙ₊₁(x) − Jₙ₊₁(x)·Yₙ(x) = −2/(πx), for every order and every x > 0.
	///
	/// The strongest check available. It is sensitive to precisely the failure a
	/// single-order table lookup would miss — a Miller normalisation off by a
	/// constant factor scales J but not Y, and cannot cancel out of a difference of
	/// two products.
	@Test("The ordinary Wronskian holds on both sides of every method boundary",
		  arguments: BesselFunctionsTests.boundaryArguments)
	func ordinaryWronskianHolds(x: Double) {
		let piX: Double = Double.pi * x
		let expected: Double = -2.0 / piX
		let bound: Double = abs(expected) * Self.identityTolerance

		var checked = 0
		for n in Self.identityOrders {
			let jn: Double = besselJ(x: x, order: n)
			let jNext: Double = besselJ(x: x, order: n + 1)
			let yn: Double = besselY(x: x, order: n)
			let yNext: Double = besselY(x: x, order: n + 1)
			let first: Double = jn * yNext
			let second: Double = jNext * yn
			let wronskian: Double = first - second
			let error: Double = abs(wronskian - expected)
			#expect(error <= bound,
					"x = \(x), n = \(n): Wronskian \(wronskian), expected \(expected)")
			checked += 1
		}
		#expect(checked == Self.identityOrders.count)
	}

	/// Iₙ(x)·Kₙ₊₁(x) + Iₙ₊₁(x)·Kₙ(x) = 1/x.
	///
	/// Restricted to x ≤ 100 because beyond that Iₙ overflows while Kₙ underflows,
	/// and the identity stops being representable long before either function stops
	/// being correct.
	@Test("The modified Wronskian holds across the Temme/Steed boundary")
	func modifiedWronskianHolds() {
		var checked = 0
		for x in Self.boundaryArguments where x <= 100.0 {
			let expected: Double = 1.0 / x
			let bound: Double = expected * Self.identityTolerance
			for n in Self.identityOrders {
				let inValue: Double = besselI(x: x, order: n)
				let iNext: Double = besselI(x: x, order: n + 1)
				let knValue: Double = besselK(x: x, order: n)
				let kNext: Double = besselK(x: x, order: n + 1)
				let first: Double = inValue * kNext
				let second: Double = iNext * knValue
				let wronskian: Double = first + second
				let error: Double = abs(wronskian - expected)
				#expect(error <= bound,
						"x = \(x), n = \(n): Wronskian \(wronskian), expected \(expected)")
				checked += 1
			}
		}
		#expect(checked == 108, "the grid shrank; the identity was checked \(checked) times")
	}

	/// Iₙ₋₁(x) − Iₙ₊₁(x) = (2n/x)·Iₙ(x).
	///
	/// Fully independent here, and the only recurrence identity of the four that is.
	/// ``besselI(x:order:)`` computes every order from its own ascending series and
	/// uses no recurrence at all, so this relates three separately computed numbers.
	/// The same identity for Y and K would merely restate the loop that produced
	/// them, and is not asserted for that reason.
	@Test("The modified three-term recurrence relates three independent series sums",
		  arguments: BesselFunctionsTests.boundaryArguments)
	func modifiedRecurrenceHolds(x: Double) {
		var checked = 0
		for n in Self.identityOrders where n >= 1 {
			let previous: Double = besselI(x: x, order: n - 1)
			let next: Double = besselI(x: x, order: n + 1)
			let centre: Double = besselI(x: x, order: n)
			let difference: Double = previous - next
			let orderT: Double = Double(2 * n)
			let coefficient: Double = orderT / x
			let expected: Double = coefficient * centre
			let error: Double = abs(difference - expected)
			// The left side subtracts two nearly equal numbers: Iₙ₋₁(x) and Iₙ₊₁(x)
			// agree to within a factor of about 2n/x, so the subtraction amplifies
			// each input's relative error by about x/2n — 250-fold at x = 500, n = 1,
			// measured rather than assumed. ``besselI(x:order:)`` itself carries about
			// ε·x from its one exp/log round trip. Both terms are named here instead
			// of being absorbed into a single looser constant, so the bound stays at
			// 1e-13 where the cancellation is mild and only opens where it is not.
			let amplification: Double = x / orderT
			let inputError: Double = Double.ulpOfOne * x
			let amplified: Double = inputError * amplification
			let relativeBound: Double = Self.identityTolerance + amplified
			let bound: Double = abs(expected) * relativeBound
			#expect(error <= bound,
					"x = \(x), n = \(n): \(difference) vs \(expected)")
			checked += 1
		}
		#expect(checked == 5)
	}

	/// J₀(x)² + 2·Σ Jₖ(x)² = 1.
	///
	/// Independent of Miller's normalisation, which uses the plain sum over even
	/// orders rather than the sum of squares. A seed order chosen too low shows up
	/// here as a deficit, not as a scale factor.
	@Test("The squares of Jₙ sum to one", arguments: BesselFunctionsTests.boundaryArguments)
	func squaresOfJSumToOne(x: Double) {
		// Jₖ(x) stays O(1) for every k below x and only then starts decaying, so a
		// fixed upper limit would simply not have summed the series at x = 500.
		let beyondTurningPoint: Double = x + 150.0
		let upper: Int = Int(beyondTurningPoint)
		let j0: Double = besselJ(x: x, order: 0)
		var total: Double = j0 * j0
		for k in 1...upper {
			let jk: Double = besselJ(x: x, order: k)
			let squared: Double = jk * jk
			total += 2.0 * squared
		}
		let error: Double = abs(total - 1.0)
		#expect(error <= 1e-12, "x = \(x): sum of squares is \(total) over \(upper) orders")
	}

	// MARK: - Layer 2b: the convention Excel measurement settled

	/// Negative arguments follow the parity relation, not an absolute value.
	///
	/// Measured, not reasoned about. `=BESSELJ(-1.5,1)` returns `-0.557936508` and
	/// `=BESSELI(-1.5,1)` returns `-0.981666428`; the absolute-value reading predicts
	/// positive in both cases. The **sign** is the discriminating assertion — it is
	/// wrong by a whole sign under the other convention, not by a tolerance — and an
	/// even order cannot distinguish them, which is why order 1 is used here.
	@Test("Negative x follows (−1)ⁿ parity, as Excel does at odd order")
	func negativeArgumentUsesParity() {
		let jOdd: Double = besselJ(x: -1.5, order: 1)
		let iOdd: Double = besselI(x: -1.5, order: 1)
		#expect(jOdd < 0.0, "BESSELJ(-1.5, 1) must be negative; got \(jOdd)")
		#expect(iOdd < 0.0, "BESSELI(-1.5, 1) must be negative; got \(iOdd)")
		#expect(abs(jOdd + 0.557936508) <= Self.excelTolerance, "got \(jOdd)")
		#expect(abs(iOdd + 0.981666428) <= Self.excelTolerance, "got \(iOdd)")

		let jEven: Double = besselJ(x: -1.5, order: 2)
		let iEven: Double = besselI(x: -1.5, order: 2)
		#expect(jEven > 0.0, "BESSELJ(-1.5, 2) must be positive; got \(jEven)")
		#expect(iEven > 0.0, "BESSELI(-1.5, 2) must be positive; got \(iEven)")
	}

	/// The two identity cells section 3.2 proposes for measuring Excel's own error.
	/// Both are exact, so any residual here is entirely ours.
	@Test("The two Wronskian cells from section 3.2 hit their exact constants")
	func proposalWronskianCellsAreExact() {
		let j0: Double = besselJ(x: 1.5, order: 0)
		let j1: Double = besselJ(x: 1.5, order: 1)
		let y0: Double = besselY(x: 1.5, order: 0)
		let y1: Double = besselY(x: 1.5, order: 1)
		let ordinaryFirst: Double = j0 * y1
		let ordinarySecond: Double = j1 * y0
		let ordinary: Double = ordinaryFirst - ordinarySecond
		#expect(abs(ordinary + 0.4244131815783876) <= 1e-15, "got \(ordinary)")

		let i0: Double = besselI(x: 1.5, order: 0)
		let i1: Double = besselI(x: 1.5, order: 1)
		let k0: Double = besselK(x: 1.5, order: 0)
		let k1: Double = besselK(x: 1.5, order: 1)
		let modifiedFirst: Double = i0 * k1
		let modifiedSecond: Double = i1 * k0
		let modified: Double = modifiedFirst + modifiedSecond
		#expect(abs(modified - 0.6666666666666666) <= 1e-15, "got \(modified)")
	}

	// MARK: - Layer 3: boundaries and invalid input

	@Test("A negative order is refused by all four")
	func negativeOrderReturnsNaN() {
		#expect(besselJ(x: 1.5, order: -1).isNaN)
		#expect(besselY(x: 1.5, order: -1).isNaN)
		#expect(besselI(x: 1.5, order: -1).isNaN)
		#expect(besselK(x: 1.5, order: -1).isNaN)
	}

	@Test("A NaN or infinite argument is refused by all four")
	func nonFiniteArgumentReturnsNaN() {
		let nan = Double.nan
		let infinity = Double.infinity
		#expect(besselJ(x: nan, order: 0).isNaN)
		#expect(besselJ(x: infinity, order: 0).isNaN)
		#expect(besselJ(x: -infinity, order: 0).isNaN)
		#expect(besselY(x: nan, order: 0).isNaN)
		#expect(besselY(x: infinity, order: 0).isNaN)
		#expect(besselI(x: nan, order: 0).isNaN)
		#expect(besselI(x: infinity, order: 0).isNaN)
		#expect(besselK(x: nan, order: 0).isNaN)
		#expect(besselK(x: infinity, order: 0).isNaN)
	}

	/// Yₙ and Kₙ are singular at the origin and undefined below it. Unlike J and I
	/// there is no parity relation to fall back on, so the whole half-line is
	/// refused rather than reflected.
	@Test("Y and K refuse a non-positive argument")
	func secondKindRefusesNonPositiveArgument() {
		#expect(besselY(x: 0.0, order: 0).isNaN)
		#expect(besselY(x: -1.0, order: 0).isNaN)
		#expect(besselY(x: -1.5, order: 2).isNaN)
		#expect(besselK(x: 0.0, order: 0).isNaN)
		#expect(besselK(x: -1.0, order: 0).isNaN)
		#expect(besselK(x: -1.5, order: 2).isNaN)
	}

	/// Exact equality is deliberate here, not an oversight: these values are
	/// returned by a guard clause rather than computed, so there is no rounding for
	/// a tolerance to absorb. `isEqual(to:)` says so in the code.
	@Test("At the origin J and I are one at order zero and zero above it")
	func originIsExact() {
		let j0: Double = besselJ(x: 0.0, order: 0)
		let i0: Double = besselI(x: 0.0, order: 0)
		#expect(j0.isEqual(to: 1.0), "J0(0) = \(j0)")
		#expect(i0.isEqual(to: 1.0), "I0(0) = \(i0)")
		#expect(besselJ(x: 0.0, order: 1) == 0.0)
		#expect(besselJ(x: 0.0, order: 7) == 0.0)
		#expect(besselI(x: 0.0, order: 1) == 0.0)
		#expect(besselI(x: 0.0, order: 7) == 0.0)

		// Negative zero is not a negative argument, and must not take the parity path.
		let jNegativeZero: Double = besselJ(x: -0.0, order: 0)
		let iNegativeZero: Double = besselI(x: -0.0, order: 0)
		#expect(jNegativeZero.isEqual(to: 1.0), "J0(-0.0) = \(jNegativeZero)")
		#expect(iNegativeZero.isEqual(to: 1.0), "I0(-0.0) = \(iNegativeZero)")
	}

	/// Section 5.4: an out-of-range result is a limit, and is reported as one.
	/// `T.nan` would conflate it with invalid input, which is a different thing.
	@Test("Overflow and underflow report limits, not NaN")
	func rangeEndsReportLimits() {
		let iOverflow: Double = besselI(x: 800.0, order: 0)
		#expect(iOverflow.isEqual(to: Double.infinity), "I0(800) = \(iOverflow)")
		let kUnderflow: Double = besselK(x: 750.0, order: 0)
		#expect(kUnderflow == 0.0, "K0(750) = \(kUnderflow)")

		// Just inside the range, both are still ordinary numbers.
		let iLast: Double = besselI(x: 709.0, order: 0)
		#expect(abs(iLast - 1.231547706701654e+306) <= 1.3e+294, "I0(709) = \(iLast)")
	}

	/// The smallest and largest arguments the type can hold still answer.
	///
	/// The small end is where halving `x` before taking its logarithm flushes a
	/// subnormal to zero; the large end is where forming πx overflows before `x`
	/// does. Both produced NaN before the kernels were written to avoid them.
	@Test("The extreme ends of the argument range still answer")
	func extremeArgumentsAnswer() {
		let tiny = Double.leastNonzeroMagnitude
		// J₀ and I₀ both round to exactly one at an argument this small.
		let jTiny: Double = besselJ(x: tiny, order: 0)
		let iTiny: Double = besselI(x: tiny, order: 0)
		#expect(jTiny.isEqual(to: 1.0), "J0(leastNonzero) = \(jTiny)")
		#expect(iTiny.isEqual(to: 1.0), "I0(leastNonzero) = \(iTiny)")
		let yTiny: Double = besselY(x: tiny, order: 0)
		#expect(abs(yTiny + 473.99907342300423) <= 1e-12, "Y0(leastNonzero) = \(yTiny)")
		let kTiny: Double = besselK(x: tiny, order: 0)
		#expect(abs(kTiny - 744.5560034370393) <= 1e-12, "K0(leastNonzero) = \(kTiny)")

		let huge = Double.greatestFiniteMagnitude
		let jHuge: Double = besselJ(x: huge, order: 0)
		let yHuge: Double = besselY(x: huge, order: 0)
		#expect(jHuge.isFinite, "J0(greatestFinite) = \(jHuge)")
		#expect(yHuge.isFinite, "Y0(greatestFinite) = \(yHuge)")
		// Both must sit on the √(2/πx) envelope, which is about 5.9e-155 there.
		#expect(abs(jHuge) <= 6.0e-155, "J0(greatestFinite) = \(jHuge)")
		#expect(abs(yHuge) <= 6.0e-155, "Y0(greatestFinite) = \(yHuge)")
	}

	/// At a zero of J₀ no relative bound exists; the absolute one does, and it is
	/// the amplitude times the working tolerance.
	@Test("J₀ vanishes at its published zeros to absolute precision",
		  arguments: BesselFunctionsTests.firstZerosOfJ0)
	func j0VanishesAtItsZeros(zero: Double) {
		let value: Double = besselJ(x: zero, order: 0)
		let scale: Double = Self.oscillatoryScale(x: zero, expected: 0.0)
		let bound: Double = scale * Self.relativeTolerance
		#expect(abs(value) <= bound, "J0(\(zero)) = \(value)")
	}

	// MARK: - Layer 4: one regression per defect found writing this

	/// Miller's seed order must be sized from the *magnitude* of Jₙ(x), not from
	/// the bound (x/2)ⁿ/n!.
	///
	/// The crude bound overstates |Jₙ(x)| by a factor of e³¹² at x = n = 1000, which
	/// relaxes the seed order enough that J₁₀₀₀(1000) came back wrong by 1.7e-6 —
	/// a number of exactly the right size, in the right place, and wrong. The
	/// turning point n = x is the worst case and the only one that exposes it.
	@Test("Miller's seed order survives the turning point n = x")
	func millerSeedOrderSurvivesTurningPoint() {
		let at100: Double = besselJ(x: 100.0, order: 100)
		let at200: Double = besselJ(x: 200.0, order: 200)
		let at1000: Double = besselJ(x: 1000.0, order: 1000)
		#expect(abs(at100 - 0.09636667329586156) <= 1e-13, "J100(100) = \(at100)")
		#expect(abs(at200 - 0.07648760893095331) <= 1e-13, "J200(200) = \(at200)")
		#expect(abs(at1000 - 0.04473067294796404) <= 1e-13, "J1000(1000) = \(at1000)")
	}

	/// Yₙ leaving the type's range must report −infinity.
	///
	/// The recurrence subtracts the previous order from the current one. Once both
	/// are infinite that is (−∞) − (−∞), which is NaN — and a NaN here would be read
	/// as invalid input, which this is not. It is an overflow, and −infinity is the
	/// true limit.
	@Test("Y overflowing in order reports minus infinity rather than NaN")
	func overflowingYIsNegativeInfinity() {
		let negativeInfinity = -Double.infinity
		let deepOrder: Double = besselY(x: 1e-6, order: 50)
		#expect(deepOrder.isEqual(to: negativeInfinity), "Y50(1e-6) = \(deepOrder)")
		let alsoDeep: Double = besselY(x: 2.0, order: 200)
		#expect(alsoDeep.isEqual(to: negativeInfinity), "Y200(2) = \(alsoDeep)")
		// K overflows the same way and is positive.
		let kDeep: Double = besselK(x: 1e-6, order: 50)
		#expect(kDeep.isEqual(to: Double.infinity), "K50(1e-6) = \(kDeep)")
	}

	/// Kₙ(x) is representable again at high order well past the argument at which
	/// K₀ and K₁ have underflowed.
	///
	/// K₀(800) and K₁(800) are both zero in `Double`. An upward recurrence seeded
	/// with two zeroes returns zero forever — but K₁₂₀₀(800) is about 6.7e-6, an
	/// ordinary number. Carrying the recurrence on e^(+x)·K and exponentiating once
	/// at the end is what makes that reachable; this test is the reason that
	/// machinery exists.
	@Test("K answers at high order past the argument where K₀ has underflowed")
	func modifiedSecondKindRecoversAtHighOrder() {
		let k0: Double = besselK(x: 800.0, order: 0)
		#expect(k0 == 0.0, "K0(800) should have underflowed; got \(k0)")

		let k1000: Double = besselK(x: 800.0, order: 1000)
		let k1200: Double = besselK(x: 800.0, order: 1200)
		#expect(abs(k1000 - 2.1873066580240859e-103) <= 2.2e-115, "K1000(800) = \(k1000)")
		#expect(abs(k1200 - 6.683863362209216e-06) <= 6.7e-18, "K1200(800) = \(k1200)")
	}

	/// Miller's seed-order search must be bounded **relative to the order**.
	///
	/// It was briefly bounded by `besselIterationLimit`, the shared runaway-loop
	/// backstop of 1,000,000. At order 1,000,000 the search begins *past* that
	/// ceiling, so the loop never ran and the seed order came back as the turning
	/// point itself, with no margin: J₁₀₀₀₀₀₀(1000000) was `0.00035973` where
	/// `0.00447307` is right. The correct order of magnitude, in the correct place,
	/// and wrong by a factor of twelve — a backstop had quietly become a correctness
	/// bound.
	///
	/// Asserted through identities rather than against a stored value, per §6.1. The
	/// Wronskian reaches Yₙ, which at this argument comes from the Hankel asymptotic
	/// and an upward recurrence and so shares no code with Miller at all. Both
	/// assertions were confirmed to fail against the defect: the Wronskian came back
	/// off by 2.3 relative *with the wrong sign*, and the ratio below came back 0.080.
	@Test("Miller's seed order is bounded by the order, not by a shared constant")
	func millerSeedOrderScalesWithOrder() {
		let n = 1_000_000
		let x = 1_000_000.0
		let jn: Double = besselJ(x: x, order: n)
		let jNext: Double = besselJ(x: x, order: n + 1)
		let yn: Double = besselY(x: x, order: n)
		let yNext: Double = besselY(x: x, order: n + 1)

		let first: Double = jn * yNext
		let second: Double = jNext * yn
		let wronskian: Double = first - second
		let piX: Double = Double.pi * x
		let expected: Double = -2.0 / piX
		let error: Double = abs(wronskian - expected)
		// Looser than the 1e-13 the other identity tests use: this one walks a
		// million recurrence steps on each of the four values it combines.
		let bound: Double = abs(expected) * 1e-11
		#expect(error <= bound,
				"Wronskian at n = x = 1e6 is \(wronskian), expected \(expected)")

		// Jₙ(n) approaches 0.4473085…·n^(−1/3) at the turning point, from below. The
		// ratio measured 0.9999973583 here and 0.9999973578 at n = 300,000, so 1e-5
		// is loose against the approach and decisive against the defect.
		let cubeRoot: Double = Foundation.cbrt(x)
		let turningPointValue: Double = 0.4473085 / cubeRoot
		let ratio: Double = jn / turningPointValue
		#expect(abs(ratio - 1.0) <= 1e-5,
				"J(1e6, order 1e6) is \(jn); ratio to the turning-point value is \(ratio)")
	}

	/// Large argument, where SciPy is the one that is wrong.
	///
	/// `scipy.special.jv(200, 3000)` is out by 1.8e-12 relative; the value asserted
	/// here comes from mpmath at 40 digits and we match it to 1e-16. Recorded
	/// because the obvious next step for anyone extending this family — generate a
	/// fixture from SciPy like every other fixture in this repo — would fail a
	/// correct implementation here and nowhere else.
	@Test("Large argument matches the high-precision reference, not SciPy")
	func largeArgumentMatchesHighPrecisionReference() {
		let value: Double = besselJ(x: 3000.0, order: 200)
		#expect(abs(value + 0.01186524260848996) <= 1e-16, "J200(3000) = \(value)")
	}
}
