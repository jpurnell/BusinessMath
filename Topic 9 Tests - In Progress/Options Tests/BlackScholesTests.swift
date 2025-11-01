import Testing
import Foundation
@testable import BusinessMath

@Suite("Black-Scholes Tests")
struct BlackScholesTests {

	// MARK: - Call Option Pricing

	@Test("Price call option - at the money")
	func callOptionATM() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,  // 1 year
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ATM call with 1 year to expiry should have positive value
		#expect(price > 0)
		#expect(price < 100)  // Less than spot price
	}

	@Test("Price call option - in the money")
	func callOptionITM() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 110.0,
			strikePrice: 100.0,  // ITM by 10
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ITM call should be worth at least intrinsic value (10)
		#expect(price >= 10.0)
	}

	@Test("Price call option - out of the money")
	func callOptionOTM() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 90.0,
			strikePrice: 100.0,  // OTM
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// OTM call should have time value
		#expect(price > 0)
		#expect(price < 10)  // Less than strike - spot
	}

	// MARK: - Put Option Pricing

	@Test("Price put option - at the money")
	func putOptionATM() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		#expect(price > 0)
		#expect(price < 100)
	}

	@Test("Price put option - in the money")
	func putOptionITM() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: 90.0,
			strikePrice: 100.0,  // ITM by 10
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// ITM put should be worth at least intrinsic value (10)
		#expect(price >= 10.0)
	}

	// MARK: - Put-Call Parity

	@Test("Put-call parity holds")
	func putCallParity() throws {
		let S = 100.0
		let K = 100.0
		let T = 1.0
		let r = 0.05
		let sigma = 0.20

		let callPrice = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma
		)

		let putPrice = BlackScholesModel<Double>.price(
			optionType: .put,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma
		)

		// Put-Call Parity: C - P = S - K*exp(-rT)
		let lhs = callPrice - putPrice
		let rhs = S - K * exp(-r * T)

		#expect(abs(lhs - rhs) < 0.01)
	}

	// MARK: - Greeks

	@Test("Calculate Greeks for call option")
	func greeksCall() throws {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Delta should be between 0 and 1 for call
		#expect(greeks.delta > 0 && greeks.delta < 1)

		// Gamma should be positive
		#expect(greeks.gamma > 0)

		// Vega should be positive
		#expect(greeks.vega > 0)

		// Theta should be negative (time decay)
		#expect(greeks.theta < 0)

		// Rho should be positive for call
		#expect(greeks.rho > 0)
	}

	@Test("Calculate Greeks for put option")
	func greeksPut() throws {
		let greeks = BlackScholesModel<Double>.greeks(
			optionType: .put,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Delta should be between -1 and 0 for put
		#expect(greeks.delta < 0 && greeks.delta > -1)

		// Gamma should be positive
		#expect(greeks.gamma > 0)

		// Vega should be positive
		#expect(greeks.vega > 0)

		// Theta should be negative
		#expect(greeks.theta < 0)

		// Rho should be negative for put
		#expect(greeks.rho < 0)
	}

	// MARK: - Parameter Sensitivity

	@Test("Volatility increases option value")
	func volatilityEffect() throws {
		let priceLowVol = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.10
		)

		let priceHighVol = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.30
		)

		// Higher volatility should increase option value
		#expect(priceHighVol > priceLowVol)
	}

	@Test("Time to expiry increases option value")
	func timeEffect() throws {
		let priceShortTime = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 0.5,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		let priceLongTime = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 2.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Longer time should increase option value
		#expect(priceLongTime > priceShortTime)
	}

	// MARK: - Edge Cases

	@Test("Zero volatility")
	func zeroVolatility() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 110.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.0  // No volatility
		)

		// With zero volatility, value approaches intrinsic value
		// discounted to present
		#expect(price > 0)
	}

	@Test("Very short time to expiry")
	func veryShortTime() throws {
		let price = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 105.0,
			strikePrice: 100.0,
			timeToExpiry: 0.001,  // ~9 hours
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Should approach intrinsic value (5)
		#expect(abs(price - 5.0) < 1.0)
	}
}
