//
//  BlackScholesReferenceTests.swift
//  BusinessMath
//
//  Differential tests for Black-Scholes and the greeks against Hull's published
//  worked examples. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// `BlackScholesModel.price` and `.greeks` against the standard published
/// examples, and against the parity and symmetry identities.
///
/// ## Why this file exists now
///
/// The cumulative normal underneath these formulas was, until recently, an
/// Abramowitz & Stegun 7.1.26 polynomial accurate to about `1.5e-7` in `erf` —
/// roughly `7e-8` in the CDF, and `6.25e-4` of price error on an index-scale
/// option. It now calls the package's `normalCDF`, which uses swift-numerics'
/// `erf`. These tests pin that improvement: every assertion below is tighter than
/// the old polynomial could satisfy, so a regression to it fails here rather than
/// showing up in someone's hedge.
///
/// ## Where the reference values come from
///
/// - **Hull, *Options, Futures, and Other Derivatives*** — the standard text, and
///   the source of both worked examples used here.
///   - **Chapter 15 (BSM valuation):** `S = 42`, `K = 40`, `r = 10%`, `σ = 20%`,
///     `T = 0.5`. Hull prints `d₁ = 0.7693`, `d₂ = 0.6278`, call `$4.76`,
///     put `$0.81`.
///   - **Chapter 19 (the greeks):** `S = 49`, `K = 50`, `r = 5%`, `σ = 20%`,
///     `T = 20/52`. Hull prints call `$2.40`, `Δ = 0.522`, `Γ = 0.066`,
///     `vega = 12.1`, `Θ = -4.31` per year, `ρ = 8.91`.
/// - **Extended digits** come from an independent arbitrary-precision evaluation
///   of the same closed forms with an arbitrary-precision `erfc` (mpmath 1.4.1 at
///   40 decimal digits), whose leading digits reproduce Hull's printed figures.
/// - **Identities** — put-call parity, `Δ_call - Δ_put = 1`, gamma and vega
///   shared between call and put, and vega as the numerical derivative of price
///   in `σ` — need no source at all.
///
/// ## Where the tolerances come from
///
/// | tolerance | used for | justification |
/// |---|---|---|
/// | `5e-3` abs | Hull's printed prices and greeks | Hull prints two or three significant decimals; `4.76` carries ±5e-3 of its own. Asserting tighter against a rounded figure would be asserting against nothing. |
/// | `1e-13` abs | extended-precision prices and greeks | measured worst case across every case below is **3.9e-15**; 1e-13 leaves ~25× for `erf`/`exp`/`log` ulp differences between platform libms. The A&S 7.1.26 polynomial this replaced would miss by **6e-4** on the Chapter 15 call, seven orders outside. |
/// | `1e-12` rel | put-call parity | an identity between two computed prices, each carrying a few ulp on values of order 1-50. Measured: **3.4e-16 relative**. |
@Suite("Black-Scholes vs Hull's worked examples")
struct BlackScholesReferenceTests {

	// MARK: - Hull, Chapter 15

	@Test("Hull Chapter 15: the European call and put")
	func hullChapter15() {
		// S = 42, K = 40, r = 10%, σ = 20%, T = 0.5 years.
		let call = BlackScholesModel<Double>.price(
			optionType: .call, spotPrice: 42, strikePrice: 40,
			timeToExpiry: 0.5, riskFreeRate: 0.10, volatility: 0.20
		)
		let put = BlackScholesModel<Double>.price(
			optionType: .put, spotPrice: 42, strikePrice: 40,
			timeToExpiry: 0.5, riskFreeRate: 0.10, volatility: 0.20
		)

		// Hull's printed figures.
		#expect(approximatelyEqual(call, 4.76, tolerance: 5e-3), "call = \(call), Hull gives $4.76")
		#expect(approximatelyEqual(put, 0.81, tolerance: 5e-3), "put = \(put), Hull gives $0.81")

		// The same values at full precision.
		#expect(
			approximatelyEqual(call, 4.7594223928715334, tolerance: 1e-13),
			"call = \(call), reference 4.7594223928715334, differs by \(abs(call - 4.7594223928715334))"
		)
		#expect(
			approximatelyEqual(put, 0.80859937290009365, tolerance: 1e-13),
			"put = \(put), reference 0.80859937290009365, differs by \(abs(put - 0.80859937290009365))"
		)
	}

	@Test("Hull Chapter 15: d1 and d2 read back out of delta")
	func hullChapter15Arguments() {
		// Hull prints d₁ = 0.7693 and d₂ = 0.6278. `calculateD1` is private, so d₁
		// is recovered through the call delta, which is Φ(d₁) — the identity that
		// ties the greeks to the price.
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call, spotPrice: 42, strikePrice: 40,
			timeToExpiry: 0.5, riskFreeRate: 0.10, volatility: 0.20
		)
		let d1 = inverseNormalCDF(p: greeks.delta)
		#expect(approximatelyEqual(d1, 0.7693, tolerance: 5e-5), "recovered d₁ = \(d1), Hull gives 0.7693")
		#expect(
			approximatelyEqual(d1, 0.76926262810603137, tolerance: 1e-13),
			"recovered d₁ = \(d1), reference 0.76926262810603137"
		)
		// d₂ = d₁ - σ√T.
		let d2 = d1 - 0.20 * (0.5 as Double).squareRoot()
		#expect(approximatelyEqual(d2, 0.6278, tolerance: 5e-5), "d₂ = \(d2), Hull gives 0.6278")
	}

	// MARK: - Hull, Chapter 19

	/// Hull's Chapter 19 parameters: a 20-week call, slightly out of the money.
	static let greeksExample = (
		spot: 49.0, strike: 50.0, expiry: 20.0 / 52.0, rate: 0.05, volatility: 0.20
	)

	@Test("Hull Chapter 19: the call price")
	func hullChapter19Price() {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: Self.greeksExample.spot, strikePrice: Self.greeksExample.strike,
			timeToExpiry: Self.greeksExample.expiry, riskFreeRate: Self.greeksExample.rate,
			volatility: Self.greeksExample.volatility
		)
		#expect(approximatelyEqual(price, 2.40, tolerance: 5e-3), "call = \(price), Hull gives $2.40")
		#expect(
			approximatelyEqual(price, 2.4005273232717147, tolerance: 1e-13),
			"call = \(price), reference 2.4005273232717147"
		)
	}

	@Test("Hull Chapter 19: the call greeks")
	func hullChapter19CallGreeks() {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: Self.greeksExample.spot, strikePrice: Self.greeksExample.strike,
			timeToExpiry: Self.greeksExample.expiry, riskFreeRate: Self.greeksExample.rate,
			volatility: Self.greeksExample.volatility
		)

		// Hull's printed figures, to the precision he prints them.
		#expect(approximatelyEqual(greeks.delta, 0.522, tolerance: 5e-4), "Δ = \(greeks.delta), Hull gives 0.522")
		#expect(approximatelyEqual(greeks.gamma, 0.066, tolerance: 5e-4), "Γ = \(greeks.gamma), Hull gives 0.066")
		#expect(approximatelyEqual(greeks.vega, 12.1, tolerance: 5e-2), "vega = \(greeks.vega), Hull gives 12.1")
		#expect(approximatelyEqual(greeks.theta, -4.31, tolerance: 5e-3), "Θ = \(greeks.theta), Hull gives -4.31/year")
		#expect(approximatelyEqual(greeks.rho, 8.91, tolerance: 5e-3), "ρ = \(greeks.rho), Hull gives 8.91")

		// The same values at full precision.
		#expect(approximatelyEqual(greeks.delta, 0.52160466106639639, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.gamma, 0.065544039347844394, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.vega, 12.105479882628800, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.theta, -4.3053298229325736, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.rho, 8.9069619496083495, tolerance: 1e-13))
	}

	@Test("Hull Chapter 19: the put greeks")
	func hullChapter19PutGreeks() {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: Self.greeksExample.spot, strikePrice: Self.greeksExample.strike,
			timeToExpiry: Self.greeksExample.expiry, riskFreeRate: Self.greeksExample.rate,
			volatility: Self.greeksExample.volatility
		)
		#expect(approximatelyEqual(greeks.delta, -0.47839533893360361, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.gamma, 0.065544039347844394, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.vega, 12.105479882628800, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.theta, -1.8529474170320668, tolerance: 1e-13))
		#expect(approximatelyEqual(greeks.rho, -9.9575180957801640, tolerance: 1e-13))
	}

	// MARK: - Identities

	@Test("Put-call parity")
	func putCallParity() {
		// c - p = S - K·e^(-rT). Exact in the model, so this is a statement about
		// the code and not about the market. Tolerance 1e-12 relative; measured
		// worst case 3.4e-16.
		let cases: [(s: Double, k: Double, t: Double, r: Double, v: Double)] = [
			(42, 40, 0.5, 0.10, 0.20),
			(49, 50, 20.0 / 52.0, 0.05, 0.20),
			(100, 105, 0.25, 0.05, 0.20),
			(100, 100, 1.0, 0.03, 0.35),
			(5, 50, 2.0, 0.02, 0.60),
			(200, 100, 0.1, 0.08, 0.15)
		]
		for entry in cases {
			let call = BlackScholesModel<Double>.price(
				optionType: .call, spotPrice: entry.s, strikePrice: entry.k,
				timeToExpiry: entry.t, riskFreeRate: entry.r, volatility: entry.v
			)
			let put = BlackScholesModel<Double>.price(
				optionType: .put, spotPrice: entry.s, strikePrice: entry.k,
				timeToExpiry: entry.t, riskFreeRate: entry.r, volatility: entry.v
			)
			let parity = entry.s - entry.k * Double.exp(-entry.r * entry.t)
			#expect(
				abs((call - put) - parity) / Swift.max(abs(parity), 1) < 1e-12,
				"S = \(entry.s), K = \(entry.k): c - p = \(call - put) but S - Ke^(-rT) = \(parity)"
			)
		}
	}

	@Test("Delta_call - Delta_put == 1, and gamma and vega are shared")
	func greekRelations() {
		// Three identities that follow from parity by differentiation, and that a
		// transcription error in one branch of the `optionType` switch would break.
		let cases: [(s: Double, k: Double, t: Double, r: Double, v: Double)] = [
			(42, 40, 0.5, 0.10, 0.20),
			(100, 105, 0.25, 0.05, 0.20),
			(100, 100, 1.0, 0.03, 0.35)
		]
		for entry in cases {
			let call = BlackScholesModel<Double>.greeks(
				optionType: .call, spotPrice: entry.s, strikePrice: entry.k,
				timeToExpiry: entry.t, riskFreeRate: entry.r, volatility: entry.v
			)
			let put = BlackScholesModel<Double>.greeks(
				optionType: .put, spotPrice: entry.s, strikePrice: entry.k,
				timeToExpiry: entry.t, riskFreeRate: entry.r, volatility: entry.v
			)
			#expect(
				approximatelyEqual(call.delta - put.delta, 1.0, tolerance: 1e-14),
				"Δc - Δp = \(call.delta - put.delta)"
			)
			#expect(identical(call.gamma, put.gamma), "gamma differs between call and put")
			#expect(identical(call.vega, put.vega), "vega differs between call and put")
			// Θc - Θp = -rK·e^(-rT), also from parity.
			let expected = -entry.r * entry.k * Double.exp(-entry.r * entry.t)
			#expect(
				abs((call.theta - put.theta) - expected) / abs(expected) < 1e-12,
				"Θc - Θp = \(call.theta - put.theta), parity gives \(expected)"
			)
		}
	}

	@Test("The greeks are the derivatives of the price")
	func greeksAreDerivatives() {
		// Central differences against the price function. Step sizes are chosen so
		// the O(h²) truncation error dominates the O(ε/h) rounding error:
		//
		//   delta, h = 1e-4 on S = 49   → truncation ~ Γ‴h²/6 ≈ 1e-9
		//   vega,  h = 1e-6 on σ = 0.2  → truncation ~ 1e-12
		//
		// so 1e-6 absolute on delta and 1e-5 on vega (which is 12.1, so 1e-6
		// relative) are the honest bands for a finite difference, not for the
		// formulas themselves.
		let base = Self.greeksExample
		for optionType in [OptionType.call, OptionType.put] {
			let greeks = BlackScholesModel<Double>.greeks(
				optionType: optionType, spotPrice: base.spot, strikePrice: base.strike,
				timeToExpiry: base.expiry, riskFreeRate: base.rate, volatility: base.volatility
			)
			func price(spot: Double, volatility: Double, rate: Double) -> Double {
				BlackScholesModel<Double>.price(
					optionType: optionType, spotPrice: spot, strikePrice: base.strike,
					timeToExpiry: base.expiry, riskFreeRate: rate, volatility: volatility
				)
			}
			let hSpot = 1e-4
			let numericalDelta = (price(spot: base.spot + hSpot, volatility: base.volatility, rate: base.rate)
				- price(spot: base.spot - hSpot, volatility: base.volatility, rate: base.rate)) / (2 * hSpot)
			#expect(
				approximatelyEqual(numericalDelta, greeks.delta, tolerance: 1e-6),
				"\(optionType) numerical delta \(numericalDelta) against \(greeks.delta)"
			)

			let numericalGamma = (price(spot: base.spot + hSpot, volatility: base.volatility, rate: base.rate)
				- 2 * price(spot: base.spot, volatility: base.volatility, rate: base.rate)
				+ price(spot: base.spot - hSpot, volatility: base.volatility, rate: base.rate)) / (hSpot * hSpot)
			// A second difference at h = 1e-4 loses about 8 digits to cancellation,
			// so 1e-4 absolute on a gamma of 0.0655 is what this method can claim.
			#expect(
				approximatelyEqual(numericalGamma, greeks.gamma, tolerance: 1e-4),
				"\(optionType) numerical gamma \(numericalGamma) against \(greeks.gamma)"
			)

			let hVol = 1e-6
			let numericalVega = (price(spot: base.spot, volatility: base.volatility + hVol, rate: base.rate)
				- price(spot: base.spot, volatility: base.volatility - hVol, rate: base.rate)) / (2 * hVol)
			#expect(
				approximatelyEqual(numericalVega, greeks.vega, tolerance: 1e-5),
				"\(optionType) numerical vega \(numericalVega) against \(greeks.vega)"
			)

			let hRate = 1e-6
			let numericalRho = (price(spot: base.spot, volatility: base.volatility, rate: base.rate + hRate)
				- price(spot: base.spot, volatility: base.volatility, rate: base.rate - hRate)) / (2 * hRate)
			#expect(
				approximatelyEqual(numericalRho, greeks.rho, tolerance: 1e-5),
				"\(optionType) numerical rho \(numericalRho) against \(greeks.rho)"
			)
		}
	}

	@Test("Prices respect the no-arbitrage bounds")
	func noArbitrageBounds() {
		// max(S - Ke^(-rT), 0) <= c <= S, and the mirror for the put. These bound
		// the answer without needing a reference, and they are what a CDF returning
		// something outside [0, 1] would violate first.
		for spot in stride(from: 5.0, through: 200.0, by: 5.0) {
			for volatility in [0.05, 0.20, 0.60] {
				let call = BlackScholesModel<Double>.price(
					optionType: .call, spotPrice: spot, strikePrice: 50,
					timeToExpiry: 0.75, riskFreeRate: 0.04, volatility: volatility
				)
				let discountedStrike = 50 * Double.exp(-0.04 * 0.75)
				#expect(call >= Swift.max(spot - discountedStrike, 0) - 1e-12, "call \(call) below its intrinsic bound at S = \(spot)")
				#expect(call <= spot + 1e-12, "call \(call) above spot \(spot)")

				let put = BlackScholesModel<Double>.price(
					optionType: .put, spotPrice: spot, strikePrice: 50,
					timeToExpiry: 0.75, riskFreeRate: 0.04, volatility: volatility
				)
				#expect(put >= Swift.max(discountedStrike - spot, 0) - 1e-12, "put \(put) below its intrinsic bound at S = \(spot)")
				#expect(put <= discountedStrike + 1e-12, "put \(put) above the discounted strike")
			}
		}
	}

	@Test("Deep out of the money, the price is negative")
	func deepOutOfTheMoneyPricesGoNegative() {
		// `S·Φ(d₁) - K·e^(-rT)·Φ(d₂)` subtracts two quantities that are each about
		// 1e-14 when the option is far enough out of the money, and the difference
		// is dominated by their rounding. The result is a **negative option price**.
		//
		// Measured with K = 60, T = 0.5, r = 3%, σ = 25%:
		//
		//   S = 8 … 13   call = 0.0        (underflow — defensible)
		//   S = 14       call = -1.12e-15  (negative)
		//   S = 15       call = +1.93e-15
		//
		// and the mirror on the put side, with S far above the strike:
		//
		//   S = 225      put = +6.17e-14
		//   S = 250      put = -8.07e-15  (negative)
		//   S >= 275     put = 0.0
		//
		// The magnitude is a rounding error; the *sign* is not. A negative premium
		// is an arbitrage the model does not admit, and it is the kind of value that
		// stops being harmless the moment something downstream takes its logarithm —
		// an implied-volatility solver, or a log-return.
		//
		// The fix is a clamp at zero, or a formulation that does not difference two
		// near-equal near-zero terms. Either is a change to BlackScholes.swift.
		let call = BlackScholesModel<Double>.price(
			optionType: .call, spotPrice: 14, strikePrice: 60,
			timeToExpiry: 0.5, riskFreeRate: 0.03, volatility: 0.25
		)
		#expect(call < 0, "recorded behaviour: deep-OTM call price is \(call)")
		#expect(abs(call) < 1e-14, "the magnitude is rounding-scale: \(call)")
		withKnownIssue(
			"BlackScholesModel.price returns a negative call price (\(call)) deep out of the money, from cancellation between S·Φ(d₁) and K·e^(-rT)·Φ(d₂). Clamp at zero rather than widening any bound."
		) {
			#expect(call >= 0)
		}

		let put = BlackScholesModel<Double>.price(
			optionType: .put, spotPrice: 250, strikePrice: 60,
			timeToExpiry: 0.5, riskFreeRate: 0.03, volatility: 0.25
		)
		#expect(put < 0, "recorded behaviour: deep-OTM put price is \(put)")
		#expect(abs(put) < 1e-13, "the magnitude is rounding-scale: \(put)")
		withKnownIssue(
			"BlackScholesModel.price returns a negative put price (\(put)) deep out of the money, from the same cancellation."
		) {
			#expect(put >= 0)
		}
	}

	@Test("Price is monotone in spot and in volatility")
	func monotonicity() {
		// Call price rises with spot and with volatility; put price falls with spot
		// and rises with volatility. A CDF with a discontinuity — the defect this
		// whole exercise came from — shows up here as a step in the price curve.
		//
		// The sweep starts at S = 30 rather than at S = 10 because below about
		// S = 20 the call price is at or below 1e-10 and monotonicity there is
		// governed by rounding, not by the model. That region is not skipped — it
		// is asserted on directly in `deepOutOfTheMoneyPricesGoNegative`, where the
		// sign, not the ordering, is the thing worth pinning.
		var previousCall = -Double.infinity
		var previousPut = Double.infinity
		for step in 0...200 {
			let spot = 30.0 + 0.5 * Double(step)
			let call = BlackScholesModel<Double>.price(
				optionType: .call, spotPrice: spot, strikePrice: 60,
				timeToExpiry: 0.5, riskFreeRate: 0.03, volatility: 0.25
			)
			let put = BlackScholesModel<Double>.price(
				optionType: .put, spotPrice: spot, strikePrice: 60,
				timeToExpiry: 0.5, riskFreeRate: 0.03, volatility: 0.25
			)
			#expect(call > previousCall, "call price fell from \(previousCall) to \(call) at S = \(spot)")
			#expect(put < previousPut, "put price rose from \(previousPut) to \(put) at S = \(spot)")
			previousCall = call
			previousPut = put
		}

		var previousVega = -Double.infinity
		for step in 1...100 {
			let volatility = 0.01 * Double(step)
			let call = BlackScholesModel<Double>.price(
				optionType: .call, spotPrice: 50, strikePrice: 55,
				timeToExpiry: 1.0, riskFreeRate: 0.03, volatility: volatility
			)
			#expect(call > previousVega, "call price fell as volatility rose to \(volatility)")
			previousVega = call
		}
	}

	@Test("An at-the-forward option is priced by the closed form")
	func atTheForwardClosedForm() {
		// When K = S·e^(rT) the two d terms are ±σ√T/2, so
		//
		//   c = S(Φ(σ√T/2) - Φ(-σ√T/2)) = S·erf(σ√T/(2√2))
		//
		// a closed form with no reference table needed, and one that isolates the
		// CDF from the rest of the formula. Tolerance 1e-13 absolute on a price of
		// order 4; the A&S 7.1.26 polynomial would miss by about 1.5e-5 here.
		let spot = 100.0, rate = 0.05, expiry = 1.0, volatility = 0.20
		let strike = spot * Double.exp(rate * expiry)
		let call = BlackScholesModel<Double>.price(
			optionType: .call, spotPrice: spot, strikePrice: strike,
			timeToExpiry: expiry, riskFreeRate: rate, volatility: volatility
		)
		let closedForm = spot * Double.erf(volatility * expiry.squareRoot() / (2 * (2.0 as Double).squareRoot()))
		#expect(
			approximatelyEqual(call, closedForm, tolerance: 1e-13),
			"at-the-forward call = \(call), closed form S·erf(σ√T/(2√2)) = \(closedForm)"
		)
		// And such an option's delta is Φ(σ√T/2).
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call, spotPrice: spot, strikePrice: strike,
			timeToExpiry: expiry, riskFreeRate: rate, volatility: volatility
		)
		#expect(
			approximatelyEqual(greeks.delta, normalCDF(x: volatility * expiry.squareRoot() / 2), tolerance: 1e-15)
		)
	}
}
