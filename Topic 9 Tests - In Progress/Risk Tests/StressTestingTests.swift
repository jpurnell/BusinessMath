import Testing
import Foundation
@testable import BusinessMath

@Suite("Stress Testing Tests")
struct StressTestingTests {

	// MARK: - Helper Functions

	func makeSamplePortfolio() -> Portfolio<Double> {
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }

		let stockReturns = TimeSeries(
			periods: periods,
			values: (0..<24).map { _ in 0.08 + Double.random(in: -0.15...0.15) }
		)

		let bondReturns = TimeSeries(
			periods: periods,
			values: (0..<24).map { _ in 0.04 + Double.random(in: -0.05...0.05) }
		)

		return Portfolio(
			assets: ["Stocks", "Bonds"],
			returns: [stockReturns, bondReturns],
			riskFreeRate: 0.03
		)
	}

	// MARK: - Historical Stress Scenarios

	@Test("2008 financial crisis scenario")
	func financialCrisis2008() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenario = HistoricalStressScenario.financialCrisis2008()
		let result = scenario.apply(to: portfolio, weights: weights)

		// 2008 crisis: stocks down ~37%, bonds up ~5%
		#expect(result.portfolioReturn < 0)
		#expect(result.stocksReturn < -0.30)
		#expect(result.bondsReturn > 0)

		// Portfolio loss should be significant but less than 100% stocks
		#expect(result.portfolioReturn > -0.25)
	}

	@Test("COVID-19 2020 scenario")
	func covid2020() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenario = HistoricalStressScenario.covid2020()
		let result = scenario.apply(to: portfolio, weights: weights)

		// COVID crash: stocks down ~34% in March 2020
		#expect(result.portfolioReturn < 0)
		#expect(result.stocksReturn < -0.25)
	}

	@Test("Dot-com bubble 2000 scenario")
	func dotComBubble() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.7, 0.3]  // Tech-heavy

		let scenario = HistoricalStressScenario.dotComBubble()
		let result = scenario.apply(to: portfolio, weights: weights)

		// Tech crash: NASDAQ down ~78% from peak
		#expect(result.portfolioReturn < -0.30)
	}

	// MARK: - Hypothetical Stress Scenarios

	@Test("Interest rate shock scenario")
	func interestRateShock() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.4, 0.6]  // Bond-heavy

		// +300 bps interest rate shock
		let scenario = HypotheticalStressScenario(
			name: "Rate Shock",
			equityShock: -0.10,  // Stocks down 10%
			bondShock: -0.15,    // Bonds down 15% (duration impact)
			currencyShock: 0.0
		)

		let result = scenario.apply(to: portfolio, weights: weights)

		// Bond-heavy portfolio should be hit harder
		#expect(result.portfolioReturn < 0)
		#expect(result.bondsReturn < -0.10)
	}

	@Test("Inflation shock scenario")
	func inflationShock() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.5, 0.5]

		let scenario = HypotheticalStressScenario(
			name: "Inflation Shock",
			equityShock: -0.12,
			bondShock: -0.20,
			commodityShock: 0.30
		)

		let result = scenario.apply(to: portfolio, weights: weights)

		// Both stocks and bonds should suffer
		#expect(result.portfolioReturn < 0)
	}

	@Test("Market crash scenario")
	func marketCrash() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.8, 0.2]  // Aggressive allocation

		let scenario = HypotheticalStressScenario(
			name: "Market Crash",
			equityShock: -0.40,
			bondShock: 0.05,  // Flight to quality
			volatilityMultiplier: 3.0
		)

		let result = scenario.apply(to: portfolio, weights: weights)

		// Aggressive portfolio should see large loss
		#expect(result.portfolioReturn < -0.30)

		// Volatility should spike
		#expect(result.newVolatility > result.baseVolatility * 2.0)
	}

	// MARK: - Multi-Factor Stress Tests

	@Test("Simultaneous shocks")
	func simultaneousShocks() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenario = MultiFactorStressScenario(
			name: "Perfect Storm",
			shocks: [
				.equity: -0.30,
				.bonds: -0.10,
				.credit: -0.20,
				.currency: -0.15
			]
		)

		let result = scenario.apply(to: portfolio, weights: weights)

		// Multiple negative shocks
		#expect(result.portfolioReturn < -0.15)
	}

	@Test("Correlation breakdown")
	func correlationBreakdown() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.5, 0.5]

		// Normal: stocks and bonds negatively correlated
		// Stress: correlations go to 1.0 (all move together)
		let scenario = CorrelationStressScenario(
			name: "Correlation Breakdown",
			stressCorrelation: 1.0,
			marketShock: -0.25
		)

		let result = scenario.apply(to: portfolio, weights: weights)

		// Diversification fails when correlations go to 1
		#expect(result.portfolioReturn < -0.20)
		#expect(result.diversificationBenefit < 0.01)
	}

	// MARK: - Reverse Stress Testing

	@Test("Find breaking point scenario")
	func reverseStressTesting() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		// What shock would cause -30% portfolio loss?
		let targetLoss = -0.30

		let breakingPoint = ReverseStressTest.findBreakingPoint(
			portfolio: portfolio,
			weights: weights,
			targetLoss: targetLoss
		)

		#expect(breakingPoint.equityShock < -0.40)

		// Verify the scenario actually produces the target loss
		let result = breakingPoint.apply(to: portfolio, weights: weights)
		#expect(abs(result.portfolioReturn - targetLoss) < 0.05)
	}

	// MARK: - Stress Test Reporting

	@Test("Generate stress test report")
	func stressTestReport() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenarios = [
			HistoricalStressScenario.financialCrisis2008(),
			HistoricalStressScenario.covid2020(),
			HypotheticalStressScenario(name: "Rate Shock", equityShock: -0.10, bondShock: -0.15)
		]

		let report = StressTestReport.generate(
			portfolio: portfolio,
			weights: weights,
			scenarios: scenarios
		)

		#expect(report.scenarios.count == 3)

		// Report should identify worst scenario
		let worstScenario = report.worstScenario
		#expect(worstScenario.portfolioReturn == report.scenarios.map { $0.portfolioReturn }.min()!)
	}

	@Test("Stress test summary statistics")
	func summaryStatistics() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenarios = [
			HistoricalStressScenario.financialCrisis2008(),
			HistoricalStressScenario.covid2020(),
			HypotheticalStressScenario(name: "Mild", equityShock: -0.05, bondShock: -0.02)
		]

		let report = StressTestReport.generate(
			portfolio: portfolio,
			weights: weights,
			scenarios: scenarios
		)

		let stats = report.summaryStatistics

		// Should have min, max, average losses
		#expect(stats.minLoss < 0)
		#expect(stats.maxLoss < stats.minLoss)  // Max loss is more negative
		#expect(stats.averageLoss < 0)
		#expect(stats.averageLoss > stats.maxLoss)
	}

	// MARK: - Time Horizon Stress Tests

	@Test("Short-term stress test")
	func shortTermStress() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let scenario = HistoricalStressScenario.covid2020()

		// 1-month stress
		let shortTerm = scenario.apply(
			to: portfolio,
			weights: weights,
			horizon: .months(1)
		)

		// 1-year stress
		let longTerm = scenario.apply(
			to: portfolio,
			weights: weights,
			horizon: .years(1)
		)

		// Longer horizon may allow recovery
		#expect(shortTerm.portfolioReturn != longTerm.portfolioReturn)
	}

	// MARK: - Sensitivity Analysis

	@Test("Sensitivity to equity shock")
	func sensitivityEquityShock() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		let shocks = [-0.10, -0.20, -0.30, -0.40, -0.50]
		var results: [Double] = []

		for shock in shocks {
			let scenario = HypotheticalStressScenario(
				name: "Equity Shock",
				equityShock: shock,
				bondShock: 0.0
			)
			let result = scenario.apply(to: portfolio, weights: weights)
			results.append(result.portfolioReturn)
		}

		// Results should be monotonically decreasing
		for i in 1..<results.count {
			#expect(results[i] < results[i-1])
		}
	}

	// MARK: - Regulatory Stress Tests

	@Test("CCAR severely adverse scenario")
	func ccarSeverelyAdverse() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.5, 0.5]

		// CCAR severely adverse: unemployment up, GDP down, etc.
		let scenario = RegulatoryStressScenario.ccarSeverelyAdverse(year: 2024)
		let result = scenario.apply(to: portfolio, weights: weights)

		// Should show significant losses
		#expect(result.portfolioReturn < -0.15)
	}

	@Test("European stress test")
	func europeanStressTest() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		// EBA adverse scenario
		let scenario = RegulatoryStressScenario.ebaAdverse(year: 2024)
		let result = scenario.apply(to: portfolio, weights: weights)

		#expect(result.portfolioReturn < 0)
	}

	// MARK: - Custom Stress Scenarios

	@Test("Build custom scenario")
	func customScenario() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.7, 0.3]

		let scenario = CustomStressScenario.builder()
			.name("Recession")
			.equityShock(-0.25)
			.bondShock(-0.05)
			.volatilityMultiplier(2.0)
			.duration(.quarters(4))
			.build()

		let result = scenario.apply(to: portfolio, weights: weights)

		#expect(result.portfolioReturn < -0.15)
	}

	// MARK: - Comparison to VaR

	@Test("Stress losses exceed VaR")
	func stressVsVaR() throws {
		let portfolio = makeSamplePortfolio()
		let weights = [0.6, 0.4]

		// Calculate 99% VaR
		let var99 = portfolio.valueAtRisk(
			weights: weights,
			confidenceLevel: 0.99,
			horizon: 1
		)

		// Apply severe stress scenario
		let scenario = HistoricalStressScenario.financialCrisis2008()
		let stressLoss = scenario.apply(to: portfolio, weights: weights).portfolioReturn

		// Stress loss should exceed VaR (tail event)
		#expect(stressLoss < var99)
	}
}
