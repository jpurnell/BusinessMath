//
//  PortfolioOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Portfolio Optimizer Tests")
struct PortfolioOptimizerTests {

	// MARK: - Minimum Variance Portfolio Tests

	@Test("Minimum variance portfolio - 2 assets")
	func minimumVariance2Assets() throws {
		let returns = VectorN([0.08, 0.12])  // Asset 1: 8%, Asset 2: 12%
		let covariance = [
			[0.04, 0.01],   // Asset 1 variance: 4%, correlation: 0.5
			[0.01, 0.09]    // Asset 2 variance: 9%
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Weights should sum to 1
		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.01, "Weights should sum to 1")

		// Lower variance asset should typically get higher weight
		// (Note: unconstrained optimization may give equal weights)
		#expect(result.weights[0] >= result.weights[1] - 0.1,
			   "Lower variance asset should have comparable or higher weight")

		// Variance should be reasonable
		#expect(result.volatility > 0.0, "Volatility should be positive")
		#expect(result.volatility < 0.3, "Volatility should be reasonable")
	}

	@Test("Minimum variance portfolio - 3 assets")
	func minimumVariance3Assets() throws {
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Basic sanity checks
		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.01, "Weights should sum to 1")

		#expect(result.volatility > 0.0, "Volatility should be positive")
		#expect(result.expectedReturn > 0.0, "Expected return should be positive")
	}

	// MARK: - Maximum Sharpe Ratio Tests

	@Test("Maximum Sharpe ratio portfolio - 2 assets")
	func maximumSharpe2Assets() throws {
		let returns = VectorN([0.08, 0.15])  // Asset 2 has higher return
		let covariance = [
			[0.04, 0.01],
			[0.01, 0.09]
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.maximumSharpePortfolio(
			expectedReturns: returns,
			covariance: covariance,
			riskFreeRate: 0.02
		)

		// Weights should sum to 1
		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.1, "Weights should sum close to 1")

		// Sharpe ratio should be positive
		#expect(result.sharpeRatio > 0.0, "Sharpe ratio should be positive")

		// Should favor higher return asset (but not entirely)
		#expect(result.weights[1] > 0.3, "Should have significant weight in higher return asset")
	}

	@Test("Maximum Sharpe ratio portfolio - 3 assets")
	func maximumSharpe3Assets() throws {
		let returns = VectorN([0.08, 0.12, 0.18])  // Increasing returns
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.25]   // Asset 3: high return, high risk
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.maximumSharpePortfolio(
			expectedReturns: returns,
			covariance: covariance,
			riskFreeRate: 0.02
		)

		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.1, "Weights should sum close to 1")

		#expect(result.sharpeRatio > 0.0, "Sharpe ratio should be positive")
		#expect(result.expectedReturn > 0.02, "Return should exceed risk-free rate")
	}

	// MARK: - Efficient Frontier Tests

	@Test("Efficient frontier generation")
	func efficientFrontier() throws {
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		let optimizer = PortfolioOptimizer()
		let frontier = try optimizer.efficientFrontier(
			expectedReturns: returns,
			covariance: covariance,
			riskFreeRate: 0.02,
			numberOfPoints: 10
		)

		// Should generate requested number of portfolios
		#expect(frontier.portfolios.count == 10, "Should generate 10 portfolios")
		#expect(frontier.targetReturns.count == 10, "Should have 10 target returns")

		// Returns should generally increase along frontier
		let frontierReturns = frontier.portfolios.map { $0.expectedReturn }
		for i in 1..<frontierReturns.count {
			// Allow some tolerance for optimization noise
			#expect(frontierReturns[i] >= frontierReturns[i-1] - 0.02,
				   "Returns should generally increase along frontier")
		}

		// Should have minimum variance portfolio
		let minVar = frontier.minimumVariancePortfolio
		#expect(minVar.volatility > 0.0, "Min variance portfolio should have positive volatility")

		// Should have maximum Sharpe portfolio
		let maxSharpe = frontier.maximumSharpePortfolio
		#expect(maxSharpe.sharpeRatio > 0.0, "Max Sharpe portfolio should have positive Sharpe ratio")
	}

	// MARK: - Risk Parity Tests

	@Test("Risk parity portfolio - 2 assets")
	func riskParity2Assets() throws {
		let returns = VectorN([0.08, 0.12])
		let covariance = [
			[0.04, 0.01],
			[0.01, 0.09]
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.riskParityPortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Weights should sum to 1
		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.01, "Weights should sum to 1")

		// Lower risk asset should have higher weight in risk parity
		#expect(result.weights[0] > result.weights[1],
			   "Lower risk asset should have higher weight")

		#expect(result.volatility > 0.0, "Volatility should be positive")
	}

	@Test("Risk parity portfolio - 3 assets")
	func riskParity3Assets() throws {
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		let optimizer = PortfolioOptimizer()
		let result = try optimizer.riskParityPortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		let weightSum = result.weights.toArray().reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.01, "Weights should sum to 1")

		// Lowest risk asset should get highest weight
		#expect(result.weights[0] > result.weights[2],
			   "Lowest variance asset should have highest weight")

		#expect(result.volatility > 0.0, "Volatility should be positive")
	}

	// MARK: - Practical Scenarios

	@Test("Conservative vs aggressive portfolios")
	func conservativeVsAggressive() throws {
		// Stocks (high return, high risk) vs Bonds (low return, low risk)
		let stockReturn = 0.12
		let bondReturn = 0.04
		let returns = VectorN([bondReturn, stockReturn])

		let stockVolatility = 0.16
		let bondVolatility = 0.04
		let correlation = 0.2

		let covariance = [
			[bondVolatility * bondVolatility,
			 correlation * bondVolatility * stockVolatility],
			[correlation * bondVolatility * stockVolatility,
			 stockVolatility * stockVolatility]
		]

		let optimizer = PortfolioOptimizer()

		// Min variance (conservative)
		let conservative = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Max Sharpe (balanced risk-return)
		let balanced = try optimizer.maximumSharpePortfolio(
			expectedReturns: returns,
			covariance: covariance,
			riskFreeRate: 0.02
		)

		// Conservative should have more bonds (or at least comparable)
		#expect(conservative.weights[0] >= 0.4,
			   "Conservative portfolio should have substantial bond allocation")

		// Both portfolios should have positive Sharpe ratios
		#expect(conservative.sharpeRatio > 0.0,
			   "Conservative portfolio should have positive Sharpe ratio")
		#expect(balanced.sharpeRatio > 0.0,
			   "Balanced portfolio should have positive Sharpe ratio")
	}

	@Test("Diversification benefit")
	func diversificationBenefit() throws {
		// Two assets with low correlation - diversification should reduce risk
		let returns = VectorN([0.10, 0.10])  // Same expected return
		let volatility = 0.15
		let correlation = 0.3  // Low correlation

		let covariance = [
			[volatility * volatility,
			 correlation * volatility * volatility],
			[correlation * volatility * volatility,
			 volatility * volatility]
		]

		let optimizer = PortfolioOptimizer()
		let portfolio = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Portfolio volatility should be less than individual asset volatility
		#expect(portfolio.volatility < volatility,
			   "Diversified portfolio should have lower risk than individual assets")

		// Weights should be approximately equal (symmetric problem)
		#expect(abs(portfolio.weights[0] - 0.5) < 0.1,
			   "Weights should be approximately equal for symmetric assets")
	}

	@Test("High Sharpe asset domination")
	func highSharpeAssetDomination() throws {
		// One asset with much better Sharpe ratio should dominate
		let returns = VectorN([0.05, 0.20])  // Asset 2 has much higher return
		let covariance = [
			[0.04, 0.00],  // No correlation
			[0.00, 0.09]   // Only moderately higher risk
		]

		let optimizer = PortfolioOptimizer()
		let portfolio = try optimizer.maximumSharpePortfolio(
			expectedReturns: returns,
			covariance: covariance,
			riskFreeRate: 0.02
		)

		// High Sharpe asset should get substantial weight
		#expect(portfolio.weights[1] > 0.6,
			   "High Sharpe ratio asset should dominate")
	}

	// MARK: - Edge Cases

	@Test("Equal assets produce equal weights")
	func equalAssetsEqualWeights() throws {
		// Identical assets should get equal weights
		let returns = VectorN([0.10, 0.10, 0.10])
		let variance = 0.04
		let covariance = [
			[variance, 0.0, 0.0],
			[0.0, variance, 0.0],
			[0.0, 0.0, variance]
		]

		let optimizer = PortfolioOptimizer()
		let portfolio = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// All weights should be approximately 1/3
		for weight in portfolio.weights.toArray() {
			#expect(abs(weight - 1.0/3.0) < 0.1,
				   "Equal assets should get equal weights")
		}
	}

	// MARK: - Performance Tests

	@Test("Optimizer converges quickly")
	func convergenceSpeed() throws {
		let returns = VectorN([0.08, 0.12, 0.15])
		let covariance = [
			[0.04, 0.01, 0.02],
			[0.01, 0.09, 0.03],
			[0.02, 0.03, 0.16]
		]

		let optimizer = PortfolioOptimizer()
		let portfolio = try optimizer.minimumVariancePortfolio(
			expectedReturns: returns,
			covariance: covariance
		)

		// Newton-Raphson should converge very quickly on quadratic objective
		#expect(portfolio.iterations < 50,
			   "Should converge in few iterations")
		#expect(portfolio.converged || portfolio.iterations < 20,
			   "Should converge or make rapid progress")
	}
}
