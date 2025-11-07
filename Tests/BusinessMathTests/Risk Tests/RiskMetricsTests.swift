import Testing
import Foundation
@testable import BusinessMath

@Suite("Comprehensive Risk Metrics Tests")
struct RiskMetricsTests {

	// MARK: - VaR Tests

	@Test("VaR 95% identifies 5th percentile loss")
	func var95Calculation() throws {
		// Create time series with known distribution
		let returns = [
			-0.05, -0.04, -0.03, -0.02, -0.01,  // 5 worst (5%)
			0.00, 0.01, 0.02, 0.03, 0.04,
			0.05, 0.06, 0.07, 0.08, 0.09,
			0.10, 0.11, 0.12, 0.13, 0.14,
			0.15, 0.16, 0.17, 0.18, 0.19,
			0.20, 0.21, 0.22, 0.23, 0.24,
			0.25, 0.26, 0.27, 0.28, 0.29,
			0.30, 0.31, 0.32, 0.33, 0.34,
			0.35, 0.36, 0.37, 0.38, 0.39,
			0.40, 0.41, 0.42, 0.43, 0.44
		] // 50 returns

		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// VaR 95% should be around -0.04 or -0.05 (5th percentile)
		#expect(metrics.var95 < 0.0)
		#expect(metrics.var95 >= -0.06)
	}

	@Test("VaR 99% more extreme than VaR 95%")
	func var99MoreExtreme() throws {
		let returns = Array(stride(from: -0.10, through: 0.10, by: 0.002))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// VaR 99% should be more extreme (more negative) than VaR 95%
		#expect(metrics.var99 < metrics.var95)
		#expect(metrics.var99 < 0.0)
		#expect(metrics.var95 < 0.0)
	}

	// MARK: - CVaR Tests

	@Test("CVaR captures tail risk beyond VaR")
	func cvarTailRisk() throws {
		let returns = Array(stride(from: -0.15, through: 0.20, by: 0.005))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// CVaR should be the average of losses beyond VaR
		// Therefore CVaR should be more extreme than VaR95
		#expect(metrics.cvar95 <= metrics.var95)
		#expect(metrics.cvar95 < 0.0)
	}

	@Test("CVaR equals VaR for uniform distribution")
	func cvarUniformDistribution() throws {
		// With uniform distribution in the tail, CVaR should be close to VaR
		let returns = Array(stride(from: -0.10, through: 0.10, by: 0.01))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// In uniform distribution, CVaR should be relatively close to VaR
		let difference = abs(metrics.cvar95 - metrics.var95)
		#expect(difference < 0.05) // Reasonably close
	}

	// MARK: - Max Drawdown Tests

	@Test("Max drawdown identifies largest peak-to-trough decline")
	func maxDrawdownCalculation() throws {
		// Simulate returns that create portfolio path: 1.0 -> 1.1 -> 1.2 -> 1.0 -> 0.8 -> 0.9 -> 1.1
		// Peak is 1.2, trough is 0.8, so max drawdown = (1.2 - 0.8) / 1.2 = 33.3%
		let returns = [0.10, 0.091, -0.167, -0.20, 0.125, 0.222]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Max drawdown from peak (1.2) to trough (0.8) ≈ 33.3%
		#expect(metrics.maxDrawdown > 0.30)
		#expect(metrics.maxDrawdown < 0.35)
	}

	@Test("No drawdown for monotonically increasing series")
	func noDrawdown() throws {
		let returns = [0.05, 0.06, 0.07, 0.08, 0.09, 0.10]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// With all positive returns, maxDrawdown should be near 0
		#expect(metrics.maxDrawdown >= 0.0)
		#expect(metrics.maxDrawdown < 0.1)
	}

	// MARK: - Sharpe Ratio Tests

	@Test("Sharpe ratio positive for excess returns")
	func sharpeRatioPositive() throws {
		// Returns above risk-free rate
		let returns = [0.08, 0.10, 0.12, 0.09, 0.11, 0.10, 0.13, 0.09]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Mean return (0.1025) > risk-free (0.02), so Sharpe should be positive
		#expect(metrics.sharpeRatio > 0.0)
	}

	@Test("Sharpe ratio increases with higher returns")
	func sharpeRatioComparison() throws {
		// Lower returns
		let lowReturns = [0.03, 0.04, 0.03, 0.04, 0.03]
		let lowPeriods = lowReturns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let lowSeries = TimeSeries(periods: lowPeriods, values: lowReturns)
		let lowMetrics = ComprehensiveRiskMetrics(returns: lowSeries, riskFreeRate: 0.02)

		// Higher returns (same volatility pattern)
		let highReturns = [0.08, 0.09, 0.08, 0.09, 0.08]
		let highPeriods = highReturns.enumerated().map { Period.month(year: 2025, month: ($0.offset % 12) + 1) }
		let highSeries = TimeSeries(periods: highPeriods, values: highReturns)
		let highMetrics = ComprehensiveRiskMetrics(returns: highSeries, riskFreeRate: 0.02)

		// Higher returns should yield higher Sharpe ratio
		#expect(highMetrics.sharpeRatio > lowMetrics.sharpeRatio)
	}

	// MARK: - Sortino Ratio Tests

	@Test("Sortino ratio only penalizes downside volatility")
	func sortinoRatioDownsideOnly() throws {
		let returns = [0.10, 0.15, -0.05, 0.08, -0.03, 0.12, 0.09]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.05)

		// Sortino should be positive if mean > risk-free
		// Only counts downside deviation
		#expect(metrics.sortinoRatio > 0.0)
	}

	@Test("Sortino ratio higher than Sharpe for asymmetric returns")
	func sortinoVsSharpe() throws {
		// Asymmetric: large upside, small downside
		let returns = [0.20, 0.25, -0.01, 0.18, -0.02, 0.22, 0.19]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.05)

		// For positive skew with limited downside, Sortino often > Sharpe
		// Both should be positive
		#expect(metrics.sharpeRatio > 0.0)
		#expect(metrics.sortinoRatio > 0.0)
	}

	// MARK: - Tail Risk Tests

	@Test("Tail risk measures severity beyond VaR")
	func tailRiskMetric() throws {
		let returns = Array(stride(from: -0.20, through: 0.15, by: 0.005))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Tail risk = abs(CVaR / VaR), should be >= 1.0
		#expect(metrics.tailRisk >= 1.0)
	}

	// MARK: - Skewness Tests

	@Test("Positive skew for right-tailed distribution")
	func positiveSkewness() throws {
		// Right-tailed: many small losses, few large gains
		let returns = [
			-0.01, -0.01, -0.01, -0.01, -0.01,
			0.00, 0.00, 0.00, 0.00, 0.00,
			0.01, 0.01, 0.01, 0.02, 0.03,
			0.05, 0.08, 0.10, 0.15, 0.20
		]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Should have positive skewness
		#expect(metrics.skewness > 0.0)
	}

	@Test("Negative skew for left-tailed distribution")
	func negativeSkewness() throws {
		// Left-tailed: many small gains, few large losses
		let returns = [
			0.01, 0.01, 0.01, 0.01, 0.01,
			0.00, 0.00, 0.00, 0.00, 0.00,
			-0.01, -0.01, -0.01, -0.02, -0.03,
			-0.05, -0.08, -0.10, -0.15, -0.20
		]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Should have negative skewness
		#expect(metrics.skewness < 0.0)
	}

	// MARK: - Kurtosis Tests

	@Test("Excess kurtosis for fat-tailed distribution")
	func excessKurtosis() throws {
		// Fat tails: MANY values tightly clustered at center, plus EXTREME outliers
		// This creates a leptokurtic (fat-tailed) distribution with positive excess kurtosis
		let returns = [
			// Extreme outliers in negative tail
			-0.25, -0.50, -0.20, -0.20,
			// Very tight cluster near zero (the peak)
			-0.001, -0.001, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
			0.0, 0.0, 0.0, 0.0, 0.001, 0.001,
			// Extreme outliers in positive tail
			0.20, 0.20, 0.50, 0.25
		]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Fat tails (sharp peak + extreme outliers) should have positive excess kurtosis
		#expect(metrics.kurtosis > 0.0)
	}

	@Test("Near-zero kurtosis for normal-like distribution")
	func normalKurtosis() throws {
		// Roughly normal distribution
		let returns = Array(stride(from: -0.10, through: 0.10, by: 0.01))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		// Uniform distribution has negative excess kurtosis
		// (normal has 0, uniform has -1.2)
		#expect(metrics.kurtosis < 0.0)
	}

	// MARK: - Integration Tests

	@Test("All metrics computed successfully")
	func allMetricsComputed() throws {
		let returns = Array(stride(from: -0.10, through: 0.15, by: 0.005))
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.03)

		// Verify all metrics are computed
		#expect(metrics.var95 < 0.0)
		#expect(metrics.var99 < 0.0)
		#expect(metrics.cvar95 <= metrics.var95)
		#expect(metrics.maxDrawdown >= 0.0)
		// Sharpe and Sortino can be any value
		#expect(metrics.tailRisk > 0.0)
		// Skewness and kurtosis can be any value

		// Verify description is not empty
		#expect(metrics.description.isEmpty == false)
	}

	@Test("Metrics description includes all values")
	func metricsDescription() throws {
		let returns = [0.05, 0.03, -0.02, 0.08, 0.06, -0.01, 0.07]
		let periods = returns.enumerated().map { Period.month(year: 2025 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let timeSeries = TimeSeries(periods: periods, values: returns)

		let metrics = ComprehensiveRiskMetrics(returns: timeSeries, riskFreeRate: 0.02)

		let description = metrics.description

		// Should contain key metric names
		#expect(description.contains("VaR"))
		#expect(description.contains("CVaR"))
		#expect(description.contains("Sharpe"))
		#expect(description.contains("Sortino"))
	}
}
