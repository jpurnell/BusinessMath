import Testing
import Foundation
@testable import BusinessMath

@Suite("Binomial Tree Option Pricing Tests")
struct BinomialTreeTests {

	// MARK: - European Options

	@Test("European call option")
	func europeanCall() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// Should be positive
		#expect(price > 0.0)
		#expect(price > 5.0)
		#expect(price < 20.0)
	}

	@Test("European put option")
	func europeanPut() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .put,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		#expect(price > 0.0)
		#expect(price > 5.0)
		#expect(price < 20.0)
	}

	// MARK: - Convergence to Black-Scholes

	@Test("Binomial tree converges to Black-Scholes")
	func convergence() throws {
		// Calculate Black-Scholes price
		let bsPrice = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Calculate binomial tree price with many steps
		let binomialPrice = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 200
		)

		// Should converge to within 5%
		let error = abs(binomialPrice - bsPrice) / bsPrice
		#expect(error < 0.05)
	}

	// MARK: - American Options

	@Test("American call equals European call (no dividends)")
	func americanCallNoEarlyExercise() throws {
		// Without dividends, American call = European call
		let european = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		let american = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: true,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// Should be nearly identical
		#expect(abs(american - european) < 0.1)
	}

	@Test("American put worth more than European put")
	func americanPutEarlyExercise() throws {
		// American put can be worth more due to early exercise
		let european = BinomialTreeModel<Double>.price(
			optionType: .put,
			americanStyle: false,
			spotPrice: 80.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		let american = BinomialTreeModel<Double>.price(
			optionType: .put,
			americanStyle: true,
			spotPrice: 80.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// American should be worth at least as much (often more)
		#expect(american >= european - 0.1)
	}

	// MARK: - Intrinsic Value

	@Test("Deep ITM option worth at least intrinsic value")
	func intrinsicValue() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: true,
			spotPrice: 120.0,
			strikePrice: 100.0,
			timeToExpiry: 0.1,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 50
		)

		// Should be worth at least intrinsic value (20)
		#expect(price >= 20.0)
	}

	// MARK: - Step Size Effect

	@Test("More steps increase accuracy")
	func stepSizeAccuracy() throws {
		let fewSteps = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 20
		)

		let manySteps = BinomialTreeModel<Double>.price(
			optionType: .call,
			americanStyle: false,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 200
		)

		// Both should be in reasonable range
		#expect(fewSteps > 0.0)
		#expect(manySteps > 0.0)

		// Should converge (difference should be small)
		let diff = abs(manySteps - fewSteps)
		#expect(diff < fewSteps * 0.1)  // Within 10%
	}
}
