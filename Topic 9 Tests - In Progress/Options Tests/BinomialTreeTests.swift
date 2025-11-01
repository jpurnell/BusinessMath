import Testing
import Foundation
@testable import BusinessMath

@Suite("Binomial Tree Option Pricing Tests")
struct BinomialTreeTests {

	// MARK: - European Options

	@Test("Price European call option")
	func europeanCall() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// Should be close to Black-Scholes
		let bsPrice = BlackScholesModel<Double>.price(
			optionType: .call,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20
		)

		// Binomial converges to Black-Scholes
		#expect(abs(price - bsPrice) < 1.0)
	}

	@Test("Price European put option")
	func europeanPut() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		#expect(price > 0)
		#expect(price < 100)
	}

	@Test("European put-call parity")
	func europeanPutCallParity() throws {
		let S = 100.0
		let K = 100.0
		let T = 1.0
		let r = 0.05
		let sigma = 0.20
		let steps = 100

		let callPrice = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma,
			steps: steps
		)

		let putPrice = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .european,
			spotPrice: S,
			strikePrice: K,
			timeToExpiry: T,
			riskFreeRate: r,
			volatility: sigma,
			steps: steps
		)

		// Put-Call Parity: C - P = S - K*exp(-rT)
		let lhs = callPrice - putPrice
		let rhs = S - K * exp(-r * T)

		#expect(abs(lhs - rhs) < 0.5)
	}

	// MARK: - American Options

	@Test("Price American call option")
	func americanCall() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .american,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// American call without dividends should equal European call
		let europeanPrice = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		#expect(abs(price - europeanPrice) < 0.1)
	}

	@Test("Price American put option")
	func americanPut() throws {
		let americanPrice = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .american,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		let europeanPrice = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// American put should be worth at least as much as European
		#expect(americanPrice >= europeanPrice)
	}

	@Test("Deep ITM American put early exercise")
	func deepITMAmericanPut() throws {
		// Deep in-the-money put should have early exercise value
		let americanPrice = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .american,
			spotPrice: 50.0,  // Deep ITM
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		let europeanPrice = BinomialTreeModel<Double>.price(
			optionType: .put,
			style: .european,
			spotPrice: 50.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// American should be worth more due to early exercise
		#expect(americanPrice > europeanPrice)
	}

	// MARK: - Convergence

	@Test("Convergence with increasing steps")
	func convergence() throws {
		let price10 = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 10
		)

		let price50 = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 50
		)

		let price100 = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// Prices should converge with more steps
		let diff50_100 = abs(price50 - price100)
		let diff10_50 = abs(price10 - price50)

		#expect(diff50_100 < diff10_50)
	}

	// MARK: - Tree Construction

	@Test("Build price tree")
	func buildPriceTree() throws {
		let tree = BinomialTreeModel<Double>.buildTree(
			spotPrice: 100.0,
			volatility: 0.20,
			timeToExpiry: 1.0,
			steps: 3
		)

		// Tree should have correct dimensions
		#expect(tree.count == 4)  // 0, 1, 2, 3
		#expect(tree[0].count == 1)  // Single starting price
		#expect(tree[3].count == 4)  // Final layer

		// Starting price should be spot
		#expect(abs(tree[0][0] - 100.0) < 0.01)
	}

	@Test("Tree nodes are correct")
	func treeNodeValues() throws {
		let dt = 1.0 / 3.0
		let u = exp(0.20 * sqrt(dt))
		let d = 1.0 / u

		let tree = BinomialTreeModel<Double>.buildTree(
			spotPrice: 100.0,
			volatility: 0.20,
			timeToExpiry: 1.0,
			steps: 3
		)

		// Check up move
		#expect(abs(tree[1][1] - 100.0 * u) < 0.01)

		// Check down move
		#expect(abs(tree[1][0] - 100.0 * d) < 0.01)
	}

	// MARK: - Dividends

	@Test("Price with continuous dividend yield")
	func withDividendYield() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			dividendYield: 0.02,
			steps: 100
		)

		let priceNoDividend = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 100.0,
			strikePrice: 100.0,
			timeToExpiry: 1.0,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 100
		)

		// Dividend should reduce call value
		#expect(price < priceNoDividend)
	}

	// MARK: - Edge Cases

	@Test("Very short time to expiry")
	func veryShortTime() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 105.0,
			strikePrice: 100.0,
			timeToExpiry: 0.001,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 10
		)

		// Should approach intrinsic value (5)
		#expect(abs(price - 5.0) < 1.0)
	}

	@Test("At expiry")
	func atExpiry() throws {
		// At expiry, option value = intrinsic value
		let spotPrice = 110.0
		let strikePrice = 100.0

		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: spotPrice,
			strikePrice: strikePrice,
			timeToExpiry: 0.0001,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 1
		)

		let intrinsicValue = max(0, spotPrice - strikePrice)
		#expect(abs(price - intrinsicValue) < 0.5)
	}

	@Test("Deep out of the money")
	func deepOTM() throws {
		let price = BinomialTreeModel<Double>.price(
			optionType: .call,
			style: .european,
			spotPrice: 50.0,  // Deep OTM
			strikePrice: 100.0,
			timeToExpiry: 0.1,
			riskFreeRate: 0.05,
			volatility: 0.20,
			steps: 50
		)

		// Should be nearly worthless
		#expect(price < 1.0)
	}
}
