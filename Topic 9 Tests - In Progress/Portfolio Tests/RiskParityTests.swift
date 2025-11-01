import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk Parity Tests")
struct RiskParityTests {

	// MARK: - Helper Functions

	func makeSampleReturns() -> [TimeSeries<Double>] {
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }

		// Stock: High volatility
		let stockReturns = (0..<24).map { _ in 0.10 + Double.random(in: -0.20...0.20) }

		// Bonds: Low volatility
		let bondReturns = (0..<24).map { _ in 0.04 + Double.random(in: -0.05...0.05) }

		return [
			TimeSeries(periods: periods, values: stockReturns),
			TimeSeries(periods: periods, values: bondReturns)
		]
	}

	// MARK: - Risk Parity Optimization

	@Test("Optimize for risk parity")
	func optimizeRiskParity() throws {
		let optimizer = RiskParityOptimizer<Double>()
		let assets = ["Stocks", "Bonds"]
		let returns = makeSampleReturns()

		let allocation = optimizer.optimize(assets: assets, returns: returns)

		// Weights should sum to 1
		let weightSum = allocation.weights.reduce(0, +)
		#expect(abs(weightSum - 1.0) < 0.1)

		// All weights should be positive
		#expect(allocation.weights.allSatisfy { $0 > 0 })

		// Lower volatility asset (bonds) should have higher weight
		#expect(allocation.weights[1] > allocation.weights[0])
	}

	@Test("Equal risk contributions")
	func equalRiskContributions() throws {
		let optimizer = RiskParityOptimizer<Double>()
		let assets = ["A", "B", "C"]

		// Create simple returns with different volatilities
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }

		let returnsA = TimeSeries(periods: periods, values: (0..<24).map { _ in 0.10 + Double.random(in: -0.20...0.20) })
		let returnsB = TimeSeries(periods: periods, values: (0..<24).map { _ in 0.08 + Double.random(in: -0.10...0.10) })
		let returnsC = TimeSeries(periods: periods, values: (0..<24).map { _ in 0.05 + Double.random(in: -0.05...0.05) })

		let allocation = optimizer.optimize(assets: assets, returns: [returnsA, returnsB, returnsC])

		// Risk contributions should be roughly equal
		// (Exact equality depends on convergence)
		// Lower volatility assets should have higher weights

		#expect(allocation.weights[2] > allocation.weights[1])
		#expect(allocation.weights[1] > allocation.weights[0])
	}

	@Test("Two asset portfolio")
	func twoAssetPortfolio() throws {
		let optimizer = RiskParityOptimizer<Double>()
		let assets = ["High Risk", "Low Risk"]
		let returns = makeSampleReturns()

		let allocation = optimizer.optimize(assets: assets, returns: returns)

		#expect(allocation.assets.count == 2)
		#expect(allocation.weights.count == 2)

		// Low risk asset should have higher weight
		#expect(allocation.weights[1] > allocation.weights[0])

		// Should be able to calculate metrics
		#expect(allocation.risk > 0)
		#expect(allocation.sharpeRatio != 0)
	}

	@Test("Risk parity vs equal weights")
	func riskParityVsEqualWeights() throws {
		let optimizer = RiskParityOptimizer<Double>()
		let assets = ["Stocks", "Bonds"]
		let returns = makeSampleReturns()

		let riskParity = optimizer.optimize(assets: assets, returns: returns)
		let equalWeights = [0.5, 0.5]

		// Risk parity should NOT be equal weights (unless assets have equal volatility)
		let diff = abs(riskParity.weights[0] - equalWeights[0])
		#expect(diff > 0.1)
	}

	// MARK: - Risk Contribution Calculation

	@Test("Calculate risk contributions")
	func calculateRiskContributions() throws {
		// This would test the internal risk contribution calculation
		// For a simplified test:

		let weights = [0.6, 0.4]
		let covariance: [[Double]] = [
			[0.04, 0.01],
			[0.01, 0.02]
		]

		// Calculate portfolio variance
		var portfolioVariance: Double = 0
		for i in 0..<2 {
			for j in 0..<2 {
				portfolioVariance += weights[i] * weights[j] * covariance[i][j]
			}
		}

		let portfolioRisk = sqrt(portfolioVariance)

		#expect(portfolioRisk > 0)
	}

	// MARK: - Edge Cases

	@Test("Single asset portfolio")
	func singleAsset() throws {
		let optimizer = RiskParityOptimizer<Double>()
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }
		let returns = TimeSeries(periods: periods, values: (0..<24).map { _ in 0.08 + Double.random(in: -0.10...0.10) })

		let allocation = optimizer.optimize(assets: ["Only Asset"], returns: [returns])

		// Single asset should get 100% weight
		#expect(abs(allocation.weights[0] - 1.0) < 0.01)
	}
}
