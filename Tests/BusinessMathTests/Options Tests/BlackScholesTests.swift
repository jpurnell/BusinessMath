import Testing
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
