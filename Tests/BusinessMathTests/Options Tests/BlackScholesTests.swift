import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Black-Scholes Option Pricing Tests")
struct BlackScholesTests {

	// MARK: - Call Option Tests

	@Test("At-the-money call option")
	func atmCall() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ATM call should have positive value
		#expect(price > 0.0)
		// Should be roughly 10% of spot price for these parameters
		#expect(price > 5.0)
		#expect(price < 20.0)
	}

	@Test("In-the-money call option")
	func itmCall() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 110.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ITM call should be worth at least intrinsic value
		#expect(price >= 10.0)
	}

	@Test("Out-of-the-money call option")
	func otmCall() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 90.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// OTM call should have small positive value (time value)
		#expect(price > 0.0)
		#expect(price < 10.0)
	}

	// MARK: - Put Option Tests

	@Test("At-the-money put option")
	func atmPut() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ATM put should have positive value
		#expect(price > 0.0)
		#expect(price > 5.0)
		#expect(price < 20.0)
	}

	@Test("In-the-money put option")
	func itmPut() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: 90.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ITM put should be worth at least intrinsic value
		#expect(price >= 10.0)
	}

	// MARK: - Put-Call Parity Tests

	@Test("Put-call parity holds")
	func putCallParity() throws {
		let S = 100.0
		let K = 100.0
		let T = 1.0
		let r = 0.05
		let sigma = 0.20

		let call = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma
		)

		let put = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma
		)

		// Put-call parity: C - P = S - K*e^(-rT)
		let lhs = call - put
		let rhs = S - K * exp(-r * T)

		#expect(abs(lhs - rhs) < 0.01)
	}

	// MARK: - Greeks Tests

	@Test("Call delta is between 0 and 1")
	func callDelta() throws {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		#expect(greeks.delta > 0.0)
		#expect(greeks.delta < 1.0)
	}

	@Test("Put delta is between -1 and 0")
	func putDelta() throws {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		#expect(greeks.delta < 0.0)
		#expect(greeks.delta > -1.0)
	}

	@Test("Gamma is positive for both calls and puts")
	func gammaPositive() throws {
		let callGreeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		let putGreeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		#expect(callGreeks.gamma > 0.0)
		#expect(putGreeks.gamma > 0.0)
	}

	@Test("Vega is positive for both calls and puts")
	func vegaPositive() throws {
		let callGreeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		let putGreeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		#expect(callGreeks.vega > 0.0)
		#expect(putGreeks.vega > 0.0)
	}

	@Test("Theta is negative for long options (time decay)")
	func thetaNegative() throws {
		let callGreeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		let putGreeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Both should experience time decay
		#expect(callGreeks.theta < 0.0)
		#expect(putGreeks.theta < 0.0)
	}

	@Test("Call rho is positive, put rho is negative")
	func rhoSign() throws {
		let callGreeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		let putGreeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Calls benefit from higher rates, puts suffer
		#expect(callGreeks.rho > 0.0)
		#expect(putGreeks.rho < 0.0)
	}

	// MARK: - Edge Cases

	@Test("Very short time to expiry")
	func shortExpiry() throws {
		// ITM call with 1 day to expiry
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 110.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0 / 365.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Should be close to intrinsic value
		#expect(abs(price - 10.0) < 1.0)
	}

	@Test("High volatility increases option value")
	func highVolatility() throws {
		let lowVolPrice = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.10
		)

		let highVolPrice = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.40
		)

		// Higher volatility = higher option value
		#expect(highVolPrice > lowVolPrice)
	}
}

@Suite("Black-Scholes Additional Tests")
struct BlackScholesAdditionalTests {

	@Test("ATM call price matches known value")
	func bsKnownPrice() {
		// S=100, K=100, T=1, r=5%, sigma=20%; Call ≈ 10.4506
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)
		#expect(abs(price - 10.4506) < 0.05)
	}

	@Test("Finite-difference Greeks roughly match closed-form")
	func finiteDifferenceGreeks() {
		let S = 100.0, K = 100.0, T = 1.0, r = 0.05, v = 0.20
		let hS = 0.01, hV = 0.0001

		let price = { (spot: Double, vol: Double, time: Double) in
			BlackScholesModel<Double>.price(optionType: .call, spotPrice: spot, strikePrice: K, timeToExpiry: time, riskFreeRate: r, volatility: vol)
		}

		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: S, strikePrice: K, timeToExpiry: T, riskFreeRate: r, volatility: v
		)

		// Central difference delta and gamma
		let cPlus = price(S + hS, v, T)
		let c0 = price(S, v, T)
		let cMinus = price(S - hS, v, T)

		let deltaFD = (cPlus - cMinus) / (2 * hS)
		let gammaFD = (cPlus - 2 * c0 + cMinus) / (hS * hS)

		// Vega by bumping vol
		let cVolPlus = price(S, v + hV, T)
		let cVolMinus = price(S, v - hV, T)
		let vegaFD = (cVolPlus - cVolMinus) / (2 * hV)

		#expect(abs(deltaFD - greeks.delta) < 1e-3)
		#expect(abs(gammaFD - greeks.gamma) < 5e-3)
		#expect(abs(vegaFD - greeks.vega) / greeks.vega < 0.02) // within 2%
	}
}

// MARK: - Normal CDF Accuracy

/// One priced option with its value computed independently at 120 decimal digits.
struct BlackScholesReferenceCase: Sendable, CustomStringConvertible {
	let name: String
	let spot: Double
	let strike: Double
	let expiry: Double
	let rate: Double
	let vol: Double
	let referenceCall: Double
	let referencePut: Double

	var description: String { name }
}

/// Pins Black-Scholes against an oracle that does not share its arithmetic.
///
/// `BlackScholesModel` used to carry a private `erf` — the Abramowitz & Stegun
/// 7.1.26 rational-times-Gaussian approximation, whose stated bound is 1.5e-7
/// absolute in `erf`, so roughly 7e-8 in the normal CDF. Every price and every
/// Greek in the model went through it. The reference values below were computed
/// with a 120-digit `Decimal` implementation of the Black-Scholes formula
/// (Taylor series for `erf`), so they are independent of both the old
/// approximation and of swift-numerics' `T.erf` that replaced it — a test that
/// re-derived the expected value from `normalCDF` would only be asserting that
/// the code equals itself.
///
/// The tolerance is `1e-12 * max(|reference|, 1)`: loose enough to absorb the
/// handful of ulps that double-precision arithmetic contributes on top of an
/// exact CDF, and roughly six orders of magnitude tighter than the error the
/// A&S polynomial produced. Under the old approximation the largest miss in
/// this table was 6.25e-04 absolute, on `indexScale`.
@Suite("Black-Scholes Normal CDF Accuracy")
struct BlackScholesNormalCDFAccuracyTests {

	static let cases: [BlackScholesReferenceCase] = [
		.init(name: "atmShortLowVol", spot: 100, strike: 100, expiry: 0.25, rate: 0.05, vol: 0.1,
			  referenceCall: 2.66483222163918532e+00, referencePut: 1.42261227102732790e+00),
		.init(name: "atmShortMidVol", spot: 100, strike: 100, expiry: 0.25, rate: 0.05, vol: 0.2,
			  referenceCall: 4.61499712960286601e+00, referencePut: 3.37277717899100837e+00),
		.init(name: "atmOneYear", spot: 100, strike: 100, expiry: 1.0, rate: 0.05, vol: 0.2,
			  referenceCall: 1.04505835721855682e+01, referencePut: 5.57352602225696803e+00),
		.init(name: "atmFiveYearHiVol", spot: 100, strike: 100, expiry: 5.0, rate: 0.05, vol: 0.6,
			  referenceCall: 5.59760916447862158e+01, referencePut: 3.38561699519267023e+01),
		.init(name: "itmOneYear", spot: 120, strike: 100, expiry: 1.0, rate: 0.05, vol: 0.2,
			  referenceCall: 2.61690439468473102e+01, referencePut: 1.29198639691871198e+00),
		.init(name: "otmOneYear", spot: 80, strike: 100, expiry: 1.0, rate: 0.05, vol: 0.2,
			  referenceCall: 1.85941957281218362e+00, referencePut: 1.69823620228835850e+01),
		.init(name: "deepItmShort", spot: 150, strike: 100, expiry: 0.25, rate: 0.05, vol: 0.15,
			  referenceCall: 5.12422199699733554e+01, referencePut: 1.93614990445625430e-08),
		.init(name: "shortDatedWeek", spot: 100, strike: 100, expiry: 0.0192, rate: 0.05, vol: 0.2,
			  referenceCall: 1.15365536121333578e+00, referencePut: 1.05770142647127408e+00),
		.init(name: "longDatedTenYear", spot: 100, strike: 100, expiry: 10.0, rate: 0.05, vol: 0.25,
			  referenceCall: 4.87843763879120118e+01, referencePut: 9.43744235917535335e+00),
		.init(name: "veryHighVol", spot: 100, strike: 100, expiry: 1.0, rate: 0.03, vol: 1.0,
			  referenceCall: 3.92199646797952539e+01, referencePut: 3.62645180346460734e+01),
		.init(name: "veryLowVol", spot: 100, strike: 95, expiry: 2.0, rate: 0.04, vol: 0.05,
			  referenceCall: 1.23857454165533039e+01, referencePut: 8.17983232837036639e-02),
		.init(name: "indexScale", spot: 4500, strike: 4600, expiry: 0.5, rate: 0.045, vol: 0.18,
			  referenceCall: 2.29457226321541896e+02, referencePut: 2.27112917410889168e+02),
		.init(name: "pennyStock", spot: 2.5, strike: 3, expiry: 0.75, rate: 0.05, vol: 0.8,
			  referenceCall: 5.50639881081281146e-01, referencePut: 9.40223134243746372e-01)
	]

	@Test("Prices match a 120-digit reference", arguments: cases)
	func priceMatchesHighPrecisionReference(_ c: BlackScholesReferenceCase) {
		let call = BlackScholesModel<Double>.price(
			optionType: .call, spotPrice: c.spot, strikePrice: c.strike,
			timeToExpiry: c.expiry, riskFreeRate: c.rate, volatility: c.vol)
		let put = BlackScholesModel<Double>.price(
			optionType: .put, spotPrice: c.spot, strikePrice: c.strike,
			timeToExpiry: c.expiry, riskFreeRate: c.rate, volatility: c.vol)

		let callTolerance = 1e-12 * Swift.max(abs(c.referenceCall), 1.0)
		let putTolerance = 1e-12 * Swift.max(abs(c.referencePut), 1.0)

		#expect(abs(call - c.referenceCall) <= callTolerance,
				"\(c.name) call: got \(call), reference \(c.referenceCall), miss \(abs(call - c.referenceCall))")
		#expect(abs(put - c.referencePut) <= putTolerance,
				"\(c.name) put: got \(put), reference \(c.referencePut), miss \(abs(put - c.referencePut))")
	}

	@Test("Normal CDF is exactly one half at zero")
	func cdfIsExactlyOneHalfAtZero() {
		// The A&S polynomial returned 0.500000000500 here — erf(0) came out as
		// 1e-9 rather than 0. An option struck exactly at its forward therefore
		// had a delta that was not 0.5 and a call/put pair that was not
		// symmetric, at a point where both are exact by symmetry.
		//
		// Bit-for-bit, because "exactly one half" is the claim. The defect this replaced
		// was 5e-10 off — inside any tolerance anyone would reach for here, and still
		// enough to break put-call parity at the forward. Stating it as a bit pattern is
		// the only phrasing that fails when the property fails.
		#expect(identical(normalCDF(x: 0.0), 0.5))
	}

	@Test("Deep-tail CDF stays monotone and bounded")
	func deepTailIsMonotone() {
		// A&S 7.1.26 is a fit on [0, ∞) with no tail guarantee; past |x| ≈ 5 its
		// 1.5e-7 absolute error dwarfs the true probability, which is where an
		// approximation stops being merely imprecise and starts being wrong in
		// sign of the derivative.
		var previous = 0.0
		for step in 0...800 {
			let x = -8.0 + Double(step) / 100.0
			let value = normalCDF(x: x)
			#expect(value >= previous, "normalCDF decreased at x = \(x)")
			#expect(value >= 0.0 && value <= 1.0, "normalCDF out of [0,1] at x = \(x)")
			previous = value
		}
	}
}
