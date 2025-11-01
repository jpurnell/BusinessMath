import Testing
import Foundation
@testable import BusinessMath

@Suite("Portfolio Theory Tests")
struct PortfolioTests {

	// MARK: - Helper Functions

	func makeSampleReturns() -> [TimeSeries<Double>] {
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }

		// Stock A: Higher return, higher volatility
		let returnsA = (0..<24).map { _ in 0.08 + Double.random(in: -0.15...0.15) }

		// Stock B: Medium return, medium volatility
		let returnsB = (0..<24).map { _ in 0.06 + Double.random(in: -0.10...0.10) }

		// Stock C: Lower return, lower volatility
		let returnsC = (0..<24).map { _ in 0.04 + Double.random(in: -0.05...0.05) }

		return [
			TimeSeries(periods: periods, values: returnsA),
			TimeSeries(periods: periods, values: returnsB),
			TimeSeries(periods: periods, values: returnsC)
		]
	}

	// MARK: - Portfolio Creation

	@Test("Create portfolio")
	func createPortfolio() throws {
		let assets = ["Stock A", "Stock B", "Stock C"]
		let returns = makeSampleReturns()

		let portfolio = Portfolio(
			assets: assets,
			returns: returns,
			riskFreeRate: 0.03
		)

		#expect(portfolio.assets.count == 3)
		#expect(portfolio.returns.count == 3)
		#expect(portfolio.riskFreeRate == 0.03)
	}

	// MARK: - Expected Returns

	@Test("Calculate expected returns")
	func expectedReturns() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: [
				TimeSeries(
					periods: [Period.month(year: 2024, month: 1)],
					values: [0.10, 0.12, 0.08]
				),
				TimeSeries(
					periods: [Period.month(year: 2024, month: 1)],
					values: [0.05, 0.06, 0.07]
				)
			],
			riskFreeRate: 0.03
		)

		let expectedReturns = portfolio.expectedReturns

		#expect(expectedReturns.count == 2)
		// First asset: (0.10 + 0.12 + 0.08) / 3 = 0.10
		#expect(abs(expectedReturns[0] - 0.10) < 0.01)
		// Second asset: (0.05 + 0.06 + 0.07) / 3 = 0.06
		#expect(abs(expectedReturns[1] - 0.06) < 0.01)
	}

	// MARK: - Covariance and Correlation

	@Test("Calculate covariance matrix")
	func covarianceMatrix() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: makeSampleReturns().prefix(2).map { $0 },
			riskFreeRate: 0.03
		)

		let covMatrix = portfolio.covarianceMatrix

		#expect(covMatrix.count == 2)
		#expect(covMatrix[0].count == 2)

		// Diagonal elements (variance) should be positive
		#expect(covMatrix[0][0] > 0)
		#expect(covMatrix[1][1] > 0)

		// Matrix should be symmetric
		#expect(abs(covMatrix[0][1] - covMatrix[1][0]) < 0.0001)
	}

	@Test("Calculate correlation matrix")
	func correlationMatrix() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: makeSampleReturns().prefix(2).map { $0 },
			riskFreeRate: 0.03
		)

		let corrMatrix = portfolio.correlationMatrix

		// Diagonal should be 1.0 (perfect correlation with itself)
		#expect(abs(corrMatrix[0][0] - 1.0) < 0.01)
		#expect(abs(corrMatrix[1][1] - 1.0) < 0.01)

		// Off-diagonal should be between -1 and 1
		#expect(corrMatrix[0][1] >= -1.0 && corrMatrix[0][1] <= 1.0)
	}

	// MARK: - Portfolio Metrics

	@Test("Calculate portfolio return")
	func portfolioReturn() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: [
				TimeSeries(periods: [Period.month(year: 2024, month: 1)], values: [0.10]),
				TimeSeries(periods: [Period.month(year: 2024, month: 1)], values: [0.06])
			],
			riskFreeRate: 0.03
		)

		let weights = [0.6, 0.4]
		let portfolioReturn = portfolio.portfolioReturn(weights: weights)

		// 0.6 * 0.10 + 0.4 * 0.06 = 0.084
		#expect(abs(portfolioReturn - 0.084) < 0.001)
	}

	@Test("Calculate portfolio risk")
	func portfolioRisk() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: makeSampleReturns().prefix(2).map { $0 },
			riskFreeRate: 0.03
		)

		let equalWeights = [0.5, 0.5]
		let risk = portfolio.portfolioRisk(weights: equalWeights)

		#expect(risk > 0)
		#expect(risk < 1.0)  // Reasonable risk level
	}

	@Test("Calculate Sharpe ratio")
	func sharpeRatio() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: makeSampleReturns().prefix(2).map { $0 },
			riskFreeRate: 0.03
		)

		let weights = [0.6, 0.4]
		let sharpe = portfolio.sharpeRatio(weights: weights)

		// Sharpe = (return - riskFree) / risk
		// Should be positive for profitable portfolio
		#expect(sharpe > 0)
	}

	// MARK: - Portfolio Optimization

	@Test("Optimize portfolio for maximum Sharpe")
	func optimizePortfolio() throws {
		let portfolio = Portfolio(
			assets: ["A", "B", "C"],
			returns: makeSampleReturns(),
			riskFreeRate: 0.03
		)

		let optimal = portfolio.optimizePortfolio()

		// Weights should sum to ~1
		let weightSum = optimal.weights.reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.1)

		// All weights should be non-negative
		#expect(optimal.weights.allSatisfy { $0 >= 0 })

		// Should have positive expected return
		#expect(optimal.expectedReturn > 0)
	}

	// MARK: - Efficient Frontier

	@Test("Generate efficient frontier")
	func efficientFrontier() throws {
		let portfolio = Portfolio(
			assets: ["A", "B"],
			returns: makeSampleReturns().prefix(2).map { $0 },
			riskFreeRate: 0.03
		)

		let frontier = portfolio.efficientFrontier(points: 10)

		#expect(frontier.count == 10)

		// Each point should have valid metrics
		for allocation in frontier {
			#expect(allocation.weights.reduce(0, +) > 0)
			#expect(allocation.risk >= 0)
		}

		// Risk should generally increase with return
		let risks = frontier.map { $0.risk }
		let returns = frontier.map { $0.expectedReturn }

		// Check that generally higher return = higher risk
		let avgRiskLowReturn = risks.prefix(5).reduce(0, +) / 5
		let avgRiskHighReturn = risks.suffix(5).reduce(0, +) / 5

		#expect(avgRiskHighReturn >= avgRiskLowReturn)
	}
}
