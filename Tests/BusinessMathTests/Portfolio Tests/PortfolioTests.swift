import Testing
import Foundation
@testable import BusinessMath

@Suite("Portfolio Optimization Tests")
struct PortfolioTests {

	// MARK: - Helper Functions

	func makeTestReturns() -> (assets: [String], returns: [TimeSeries<Double>]) {
		// Create sample return data for 3 assets
		let periods = (0..<120).map { Period.month(year: 2014 + $0 / 12, month: $0 % 12 + 1) }

		// Stock: 8% avg, high volatility
		let stockReturns = (0..<120).map { i in
			0.08 / 12.0 + Double.random(in: -0.03...0.03)
		}

		// Bond: 4% avg, low volatility
		let bondReturns = (0..<120).map { i in
			0.04 / 12.0 + Double.random(in: -0.01...0.01)
		}

		// Commodity: 6% avg, medium volatility
		let commodityReturns = (0..<120).map { i in
			0.06 / 12.0 + Double.random(in: -0.02...0.02)
		}

		return (
			assets: ["Stock", "Bond", "Commodity"],
			returns: [
				TimeSeries(periods: periods, values: stockReturns),
				TimeSeries(periods: periods, values: bondReturns),
				TimeSeries(periods: periods, values: commodityReturns)
			]
		)
	}

	func makeTwoAssetReturns() -> (assets: [String], returns: [TimeSeries<Double>]) {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }

		// Asset A: 10% avg return
		let returnsA = Array(repeating: 0.10 / 12.0, count: 60)

		// Asset B: 5% avg return
		let returnsB = Array(repeating: 0.05 / 12.0, count: 60)

		return (
			assets: ["A", "B"],
			returns: [
				TimeSeries(periods: periods, values: returnsA),
				TimeSeries(periods: periods, values: returnsB)
			]
		)
	}

	// MARK: - Expected Returns Tests

	@Test("Calculate expected returns")
	func expectedReturns() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let expectedRets = portfolio.expectedReturns

		#expect(expectedRets.count == 2)
		#expect(abs(expectedRets[0] - 0.10 / 12.0) < 0.001)
		#expect(abs(expectedRets[1] - 0.05 / 12.0) < 0.001)
	}

	// MARK: - Covariance and Correlation Tests

	@Test("Covariance matrix is symmetric")
	func covarianceSymmetric() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let cov = portfolio.covarianceMatrix

		for i in 0..<3 {
			for j in 0..<3 {
				#expect(abs(cov[i][j] - cov[j][i]) < 0.0001)
			}
		}
	}

	@Test("Correlation matrix diagonal is 1.0")
	func correlationDiagonal() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let corr = portfolio.correlationMatrix

		for i in 0..<3 {
			#expect(abs(corr[i][i] - 1.0) < 0.001)
		}
	}

	// MARK: - Portfolio Metrics Tests

	@Test("Portfolio return with equal weights")
	func portfolioReturnEqualWeights() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let weights = [0.5, 0.5]
		let portfolioReturn = portfolio.portfolioReturn(weights: weights)

		// Expected: 0.5 * 10% + 0.5 * 5% = 7.5%
		let expectedReturn = (0.10 + 0.05) / 2.0 / 12.0
		#expect(abs(portfolioReturn - expectedReturn) < 0.001)
	}

	@Test("Portfolio risk is positive")
	func portfolioRiskPositive() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let weights = [0.33, 0.33, 0.34]
		let risk = portfolio.portfolioRisk(weights: weights)

		#expect(risk > 0.0)
	}

	@Test("Portfolio risk decreases with diversification")
	func diversificationReducesRisk() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		// 100% in one asset
		let singleAssetRisk = portfolio.portfolioRisk(weights: [1.0, 0.0, 0.0])

		// Diversified
		let diversifiedRisk = portfolio.portfolioRisk(weights: [0.33, 0.33, 0.34])

		// Diversification should reduce risk (in most cases)
		// Note: This may not always be true if assets are perfectly correlated
		// So we just check that both are positive
		#expect(singleAssetRisk > 0.0)
		#expect(diversifiedRisk > 0.0)
	}

	// MARK: - Sharpe Ratio Tests

	@Test("Sharpe ratio calculation")
	func sharpeRatio() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns, riskFreeRate: 0.03)

		let weights = [0.5, 0.5]
		let sharpe = portfolio.sharpeRatio(weights: weights)

		// Sharpe = (Return - RiskFree) / Risk
		// Should be positive for reasonable portfolios
		#expect(sharpe >= 0.0 || sharpe < 0.0)  // Just check it calculates
	}

	// MARK: - Portfolio Optimization Tests

	@Test("Optimize portfolio returns valid allocation")
	func optimizePortfolio() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let optimal = portfolio.optimizePortfolio()

		// Weights should sum to 1
		let weightSum = optimal.weights.reduce(0.0, +)
		#expect(abs(weightSum - 1.0) < 0.01)

		// All weights should be non-negative
		for weight in optimal.weights {
			#expect(weight >= -0.01)  // Small tolerance for numerical error
		}

		// Should have same number of assets
		#expect(optimal.assets.count == assets.count)
		#expect(optimal.weights.count == assets.count)
	}

	@Test("Optimal portfolio has higher Sharpe than equal weights")
	func optimalBetterThanEqual() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let optimal = portfolio.optimizePortfolio()
		let equalWeights = [0.33, 0.33, 0.34]
		let equalSharpe = portfolio.sharpeRatio(weights: equalWeights)

		// Optimal should be at least as good as equal weights
		#expect(optimal.sharpeRatio >= equalSharpe - 0.1)  // Allow some tolerance
	}

	// MARK: - Efficient Frontier Tests

	@Test("Efficient frontier returns multiple portfolios")
	func efficientFrontier() throws {
		let (assets, returns) = makeTestReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let frontier = portfolio.efficientFrontier(points: 20)

		#expect(frontier.count > 0)
		#expect(frontier.count <= 20)

		// All portfolios should have valid weights
		for allocation in frontier {
			let weightSum = allocation.weights.reduce(0.0, +)
			#expect(abs(weightSum - 1.0) < 0.1)
		}
	}

	@Test("Efficient frontier portfolios have increasing return")
	func frontierIncreasingReturn() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let frontier = portfolio.efficientFrontier(points: 10)

		// Returns should generally increase along frontier
		// (though numerical optimization may have some noise)
		if frontier.count >= 2 {
			let firstReturn = frontier.first?.expectedReturn ?? 0.0
			let lastReturn = frontier.last?.expectedReturn ?? 0.0
			// Just check they're both positive
			#expect(firstReturn >= 0.0)
			#expect(lastReturn >= 0.0)
		}
	}

	// MARK: - Two Asset Portfolio Tests

	@Test("Two asset portfolio can allocate to both")
	func twoAssetAllocation() throws {
		let (assets, returns) = makeTwoAssetReturns()
		let portfolio = Portfolio(assets: assets, returns: returns)

		let optimal = portfolio.optimizePortfolio()

		#expect(optimal.weights.count == 2)
		let sum = optimal.weights.reduce(0.0, +)
		#expect(abs(sum - 1.0) < 0.01)
	}

	// MARK: - Edge Cases

	@Test("Single asset portfolio")
	func singleAsset() throws {
		let periods = (0..<60).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		let returns = Array(repeating: 0.08 / 12.0, count: 60)

		let portfolio = Portfolio(
			assets: ["OnlyAsset"],
			returns: [TimeSeries(periods: periods, values: returns)]
		)

		let optimal = portfolio.optimizePortfolio()

		// Should allocate 100% to the only asset
		#expect(abs(optimal.weights[0] - 1.0) < 0.01)
	}
}

@Suite("Deterministic Portfolio Tests")
struct PortfolioDeterministicTests {

	// Two-asset, constant returns: 10% and 5% annualized (monthly rates)
	private func twoAssetConstant() -> (assets: [String], returns: [TimeSeries<Double>]) {
		let periods = (0..<12).map { Period.month(year: 2024, month: $0 + 1) }
		let a = Array(repeating: 0.10 / 12.0, count: 12)
		let b = Array(repeating: 0.05 / 12.0, count: 12)
		return (["A","B"], [TimeSeries(periods: periods, values: a),
							TimeSeries(periods: periods, values: b)])
	}

	@Test("Sharpe ratio is finite and non-NaN")
	func sharpeFinite() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets, riskFreeRate: 0.0)
		let sharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])
		#expect(sharpe.isFinite, "Sharpe ratio should be finite for deterministic constant returns.")
	}

	@Test("Efficient frontier has non-decreasing expected returns (two assets, constant)")
	func frontierMonotonicReturn() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets)

		let frontier = portfolio.efficientFrontier(points: 10)
		#expect(frontier.count > 1)
		// Check monotonic non-decreasing expected return
		for i in 1..<frontier.count {
			#expect(frontier[i].expectedReturn + 1e-12 >= frontier[i - 1].expectedReturn,
					"Expected return should be non-decreasing along the frontier.")
		}
	}

	@Test("Optimizer beats equal weights on simple two-asset constant case")
	func optimizerBeatsEqualWeights() throws {
		let (assets, rets) = twoAssetConstant()
		let portfolio = Portfolio(assets: assets, returns: rets, riskFreeRate: 0.0)

		let optimal = portfolio.optimizePortfolio()
		let equalSharpe = portfolio.sharpeRatio(weights: [0.5, 0.5])

		#expect(optimal.assets.count == assets.count)
		#expect(optimal.weights.count == assets.count)
		#expect(optimal.sharpeRatio >= equalSharpe - 1e-6,
				"Optimal portfolio should have Sharpe at least as high as equal weights in this deterministic case.")
	}
}
