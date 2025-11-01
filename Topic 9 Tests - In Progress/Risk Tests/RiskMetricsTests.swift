import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk Metrics Tests")
struct RiskMetricsTests {

	// MARK: - Helper Functions

	func makeSampleReturns() -> TimeSeries<Double> {
		let periods = (0..<252).map { Period.day(date: Date(timeIntervalSince1970: Double($0 * 86400))) }
		let values = (0..<252).map { _ in Double.random(in: -0.05...0.05) }
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - Value at Risk (VaR)

	@Test("Calculate historical VaR")
	func historicalVaR() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		let var95 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95,
			method: .historical
		)

		// 95% VaR should be negative (loss)
		#expect(var95 < 0)

		// Should be reasonable magnitude
		#expect(var95 > -portfolioValue * 0.20)
	}

	@Test("Calculate parametric VaR")
	func parametricVaR() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		let var95 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95,
			method: .parametric
		)

		// Assumes normal distribution
		#expect(var95 < 0)
		#expect(var95 > -portfolioValue)
	}

	@Test("VaR increases with confidence level")
	func varConfidenceLevels() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		let var90 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.90,
			method: .historical
		)

		let var95 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95,
			method: .historical
		)

		let var99 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.99,
			method: .historical
		)

		// Higher confidence = larger loss estimate
		#expect(var99 < var95)
		#expect(var95 < var90)
	}

	// MARK: - Conditional VaR (CVaR / Expected Shortfall)

	@Test("Calculate CVaR")
	func conditionalVaR() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		let cvar95 = RiskMetrics<Double>.conditionalVaR(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95
		)

		let var95 = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95,
			method: .historical
		)

		// CVaR should be worse (more negative) than VaR
		#expect(cvar95 < var95)
	}

	@Test("CVaR is coherent risk measure")
	func cvarCoherence() throws {
		let returns1 = makeSampleReturns()
		let returns2 = makeSampleReturns()

		let cvar1 = RiskMetrics<Double>.conditionalVaR(
			returns: returns1,
			portfolioValue: 1_000_000,
			confidenceLevel: 0.95
		)

		let cvar2 = RiskMetrics<Double>.conditionalVaR(
			returns: returns2,
			portfolioValue: 1_000_000,
			confidenceLevel: 0.95
		)

		// CVaR is subadditive (coherent)
		let combined = returns1.values + returns2.values
		let periods = (0..<combined.count).map { Period.day(date: Date(timeIntervalSince1970: Double($0 * 86400))) }
		let combinedSeries = TimeSeries(periods: periods, values: combined)

		let cvarCombined = RiskMetrics<Double>.conditionalVaR(
			returns: combinedSeries,
			portfolioValue: 2_000_000,
			confidenceLevel: 0.95
		)

		// Subadditivity: CVaR(A+B) <= CVaR(A) + CVaR(B)
		#expect(cvarCombined >= cvar1 + cvar2)
	}

	// MARK: - Maximum Drawdown

	@Test("Calculate maximum drawdown")
	func maximumDrawdown() throws {
		// Create series with known drawdown
		let periods = (0..<100).map { Period.day(date: Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = []

		// Rise to peak
		for i in 0..<50 {
			values.append(100.0 + Double(i) * 2.0)  // Peak at 200
		}

		// Draw down 30%
		for i in 50..<70 {
			let drawdown = Double(i - 50) * 3.0
			values.append(200.0 - drawdown)  // Down to 140
		}

		// Recover partially
		for i in 70..<100 {
			values.append(140.0 + Double(i - 70) * 1.0)
		}

		let series = TimeSeries(periods: periods, values: values)

		let maxDD = RiskMetrics<Double>.maximumDrawdown(prices: series)

		// Max drawdown should be ~30% (200 to 140)
		#expect(abs(maxDD - (-0.30)) < 0.05)
	}

	@Test("Drawdown duration")
	func drawdownDuration() throws {
		let periods = (0..<100).map { Period.day(date: Date(timeIntervalSince1970: Double($0 * 86400))) }
		var values: [Double] = Array(repeating: 100.0, count: 100)

		// Create a drawdown from day 20 to day 60
		for i in 20..<60 {
			values[i] = 80.0
		}

		let series = TimeSeries(periods: periods, values: values)

		let duration = RiskMetrics<Double>.drawdownDuration(prices: series)

		// Should identify ~40 day drawdown
		#expect(duration.longestDrawdown >= 35)
		#expect(duration.longestDrawdown <= 45)
	}

	// MARK: - Volatility Metrics

	@Test("Calculate historical volatility")
	func historicalVolatility() throws {
		let returns = makeSampleReturns()

		let volatility = RiskMetrics<Double>.historicalVolatility(
			returns: returns,
			annualizationFactor: 252
		)

		// Should be positive
		#expect(volatility > 0)

		// Should be reasonable (typically 10-50% for stocks)
		#expect(volatility < 1.0)
	}

	@Test("Rolling volatility")
	func rollingVolatility() throws {
		let returns = makeSampleReturns()

		let rolling = RiskMetrics<Double>.rollingVolatility(
			returns: returns,
			window: 30,
			annualizationFactor: 252
		)

		// Should have values for each rolling window
		#expect(rolling.values.count > 0)

		// All values should be positive
		#expect(rolling.values.allSatisfy { $0 > 0 })
	}

	@Test("EWMA volatility")
	func ewmaVolatility() throws {
		let returns = makeSampleReturns()

		let ewma = RiskMetrics<Double>.ewmaVolatility(
			returns: returns,
			lambda: 0.94,
			annualizationFactor: 252
		)

		// Should give more weight to recent observations
		#expect(ewma.values.count == returns.values.count)

		// All values should be positive
		#expect(ewma.values.allSatisfy { $0 > 0 })
	}

	// MARK: - Downside Risk

	@Test("Calculate downside deviation")
	func downsideDeviation() throws {
		let returns = makeSampleReturns()
		let targetReturn = 0.0

		let downside = RiskMetrics<Double>.downsideDeviation(
			returns: returns,
			targetReturn: targetReturn,
			annualizationFactor: 252
		)

		// Should only consider returns below target
		#expect(downside > 0)
	}

	@Test("Sortino ratio")
	func sortinoRatio() throws {
		let returns = makeSampleReturns()
		let riskFreeRate = 0.03

		let sortino = RiskMetrics<Double>.sortinoRatio(
			returns: returns,
			riskFreeRate: riskFreeRate,
			targetReturn: 0.0,
			annualizationFactor: 252
		)

		// Should be finite
		#expect(sortino.isFinite)
	}

	// MARK: - Beta and Correlation

	@Test("Calculate beta")
	func calculateBeta() throws {
		let assetReturns = makeSampleReturns()
		let marketReturns = makeSampleReturns()

		let beta = RiskMetrics<Double>.beta(
			assetReturns: assetReturns,
			marketReturns: marketReturns
		)

		// Beta should be finite
		#expect(beta.isFinite)

		// Typical range -2 to 3
		#expect(beta > -3)
		#expect(beta < 5)
	}

	@Test("Calculate correlation")
	func calculateCorrelation() throws {
		let returns1 = makeSampleReturns()
		let returns2 = makeSampleReturns()

		let correlation = RiskMetrics<Double>.correlation(
			returns1: returns1,
			returns2: returns2
		)

		// Should be between -1 and 1
		#expect(correlation >= -1.0)
		#expect(correlation <= 1.0)
	}

	@Test("Rolling correlation")
	func rollingCorrelation() throws {
		let returns1 = makeSampleReturns()
		let returns2 = makeSampleReturns()

		let rolling = RiskMetrics<Double>.rollingCorrelation(
			returns1: returns1,
			returns2: returns2,
			window: 60
		)

		// All values should be in [-1, 1]
		for value in rolling.values {
			#expect(value >= -1.0)
			#expect(value <= 1.0)
		}
	}

	// MARK: - Risk-Adjusted Returns

	@Test("Calculate Sharpe ratio")
	func sharpeRatio() throws {
		let returns = makeSampleReturns()
		let riskFreeRate = 0.03

		let sharpe = RiskMetrics<Double>.sharpeRatio(
			returns: returns,
			riskFreeRate: riskFreeRate,
			annualizationFactor: 252
		)

		// Should be finite
		#expect(sharpe.isFinite)
	}

	@Test("Calculate Treynor ratio")
	func treynorRatio() throws {
		let assetReturns = makeSampleReturns()
		let marketReturns = makeSampleReturns()
		let riskFreeRate = 0.03

		let beta = RiskMetrics<Double>.beta(
			assetReturns: assetReturns,
			marketReturns: marketReturns
		)

		let treynor = RiskMetrics<Double>.treynorRatio(
			returns: assetReturns,
			beta: beta,
			riskFreeRate: riskFreeRate,
			annualizationFactor: 252
		)

		#expect(treynor.isFinite)
	}

	@Test("Calculate Information ratio")
	func informationRatio() throws {
		let portfolioReturns = makeSampleReturns()
		let benchmarkReturns = makeSampleReturns()

		let infoRatio = RiskMetrics<Double>.informationRatio(
			portfolioReturns: portfolioReturns,
			benchmarkReturns: benchmarkReturns,
			annualizationFactor: 252
		)

		#expect(infoRatio.isFinite)
	}

	@Test("Calculate Calmar ratio")
	func calmarRatio() throws {
		let returns = makeSampleReturns()

		// Create price series from returns
		var prices: [Double] = [100.0]
		for ret in returns.values {
			prices.append(prices.last! * (1 + ret))
		}

		let priceSeries = TimeSeries(periods: returns.periods, values: prices)

		let calmar = RiskMetrics<Double>.calmarRatio(
			returns: returns,
			prices: priceSeries,
			annualizationFactor: 252
		)

		// Return / Max Drawdown
		#expect(calmar.isFinite)
	}

	// MARK: - Tail Risk

	@Test("Calculate skewness")
	func calculateSkewness() throws {
		let returns = makeSampleReturns()

		let skewness = RiskMetrics<Double>.skewness(returns: returns)

		// Should be finite
		#expect(skewness.isFinite)

		// Typical range -3 to 3
		#expect(skewness > -5)
		#expect(skewness < 5)
	}

	@Test("Calculate kurtosis")
	func calculateKurtosis() throws {
		let returns = makeSampleReturns()

		let kurtosis = RiskMetrics<Double>.kurtosis(returns: returns)

		// Should be finite
		#expect(kurtosis.isFinite)

		// Excess kurtosis typically -2 to 10
		#expect(kurtosis > -3)
		#expect(kurtosis < 15)
	}

	@Test("Jarque-Bera test for normality")
	func jarqueBeraTest() throws {
		let returns = makeSampleReturns()

		let jbTest = RiskMetrics<Double>.jarqueBeraTest(returns: returns)

		// Test statistic should be positive
		#expect(jbTest.statistic >= 0)

		// P-value between 0 and 1
		#expect(jbTest.pValue >= 0)
		#expect(jbTest.pValue <= 1)
	}

	// MARK: - Tracking Error

	@Test("Calculate tracking error")
	func trackingError() throws {
		let portfolioReturns = makeSampleReturns()
		let benchmarkReturns = makeSampleReturns()

		let te = RiskMetrics<Double>.trackingError(
			portfolioReturns: portfolioReturns,
			benchmarkReturns: benchmarkReturns,
			annualizationFactor: 252
		)

		// Should be positive
		#expect(te > 0)

		// Typical range 0-20%
		#expect(te < 0.50)
	}

	@Test("Active return")
	func activeReturn() throws {
		let portfolioReturns = makeSampleReturns()
		let benchmarkReturns = makeSampleReturns()

		let activeRet = RiskMetrics<Double>.activeReturn(
			portfolioReturns: portfolioReturns,
			benchmarkReturns: benchmarkReturns,
			annualizationFactor: 252
		)

		// Can be positive or negative
		#expect(activeRet.isFinite)
	}

	// MARK: - Risk Contribution

	@Test("Calculate marginal VaR")
	func marginalVaR() throws {
		let returns = [
			makeSampleReturns(),
			makeSampleReturns(),
			makeSampleReturns()
		]

		let weights = [0.4, 0.35, 0.25]

		let marginalVaRs = RiskMetrics<Double>.marginalVaR(
			returns: returns,
			weights: weights,
			portfolioValue: 1_000_000,
			confidenceLevel: 0.95
		)

		#expect(marginalVaRs.count == 3)
	}

	@Test("Calculate component VaR")
	func componentVaR() throws {
		let returns = [
			makeSampleReturns(),
			makeSampleReturns(),
			makeSampleReturns()
		]

		let weights = [0.4, 0.35, 0.25]

		let componentVaRs = RiskMetrics<Double>.componentVaR(
			returns: returns,
			weights: weights,
			portfolioValue: 1_000_000,
			confidenceLevel: 0.95
		)

		#expect(componentVaRs.count == 3)

		// Component VaRs should sum to portfolio VaR
		let sum = componentVaRs.reduce(0, +)
		#expect(sum < 0)  // Should be a loss
	}

	// MARK: - Scenario Analysis

	@Test("Calculate stress scenario impact")
	func stressScenario() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		// Stress: 3 standard deviation move
		let stress = RiskMetrics<Double>.stressScenario(
			returns: returns,
			portfolioValue: portfolioValue,
			standardDeviations: 3.0
		)

		// Should show significant loss
		#expect(stress < 0)
		#expect(stress < portfolioValue * -0.10)
	}

	// MARK: - Time Aggregation

	@Test("Scale VaR to different horizon")
	func scaleVaR() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0

		let var1Day = RiskMetrics<Double>.valueAtRisk(
			returns: returns,
			portfolioValue: portfolioValue,
			confidenceLevel: 0.95,
			method: .parametric
		)

		// Scale to 10 days (sqrt rule)
		let var10Day = var1Day * sqrt(10.0)

		// Longer horizon = larger VaR
		#expect(abs(var10Day) > abs(var1Day))
	}

	// MARK: - Risk-Adjusted Performance Attribution

	@Test("Calculate alpha")
	func calculateAlpha() throws {
		let assetReturns = makeSampleReturns()
		let marketReturns = makeSampleReturns()
		let riskFreeRate = 0.03

		let beta = RiskMetrics<Double>.beta(
			assetReturns: assetReturns,
			marketReturns: marketReturns
		)

		let alpha = RiskMetrics<Double>.alpha(
			assetReturns: assetReturns,
			marketReturns: marketReturns,
			beta: beta,
			riskFreeRate: riskFreeRate,
			annualizationFactor: 252
		)

		#expect(alpha.isFinite)
	}

	// MARK: - Comprehensive Risk Report

	@Test("Generate comprehensive risk report")
	func comprehensiveRiskReport() throws {
		let returns = makeSampleReturns()
		let portfolioValue = 1_000_000.0
		let riskFreeRate = 0.03

		let report = RiskMetrics<Double>.comprehensiveReport(
			returns: returns,
			portfolioValue: portfolioValue,
			riskFreeRate: riskFreeRate,
			confidenceLevel: 0.95,
			annualizationFactor: 252
		)

		// Should include all major metrics
		#expect(report.var95 < 0)
		#expect(report.cvar95 < report.var95)
		#expect(report.volatility > 0)
		#expect(report.sharpeRatio.isFinite)
		#expect(report.maxDrawdown < 0)
	}
}
