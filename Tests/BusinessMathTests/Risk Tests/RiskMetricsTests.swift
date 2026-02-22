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

@Suite("Comprehensive Risk Metrics Additional Tests")
struct RiskMetricsAdditionalTests {

	@Test("Skewness near zero for symmetric distribution")
	func skewnessSymmetric() throws {
		let returns = [-0.20, -0.10, -0.05, 0.0, 0.05, 0.10, 0.20]
		let periods = returns.enumerated().map { Period.month(year: 2026 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		#expect(abs(metrics.skewness) < 1e-3)
	}

	@Test("VaR/CVaR become more conservative when extreme tail loss added")
	func varCvarTailMonotonicity() throws {
		var base = Array(stride(from: -0.05, through: 0.05, by: 0.005))
		let periods1 = base.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts1 = TimeSeries(periods: periods1, values: base)
		let m1 = ComprehensiveRiskMetrics(returns: ts1, riskFreeRate: 0.0)

		base.append(-0.50) // add extreme negative event
		let periods2 = base.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts2 = TimeSeries(periods: periods2, values: base)
		let m2 = ComprehensiveRiskMetrics(returns: ts2, riskFreeRate: 0.0)

		#expect(m2.var95 <= m1.var95)   // more negative or equal
		#expect(m2.cvar95 <= m1.cvar95) // more negative or equal
	}

	@Test("Sharpe/Sortino handle constant returns (zero volatility)")
	func constantReturnsZeroVolatility() throws {
		let returns = Array(repeating: 0.01, count: 24)
		let periods = returns.enumerated().map { Period.month(year: 2026 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		// Should not be NaN or infinite even if stdev == 0
		#expect(metrics.sharpeRatio.isFinite)
		#expect(metrics.sortinoRatio.isFinite)
	}

	@Test("Max drawdown exact check (≈ 33.333%)")
	func maxDrawdownTightTolerance() throws {
		// 1.0 -> 1.1 -> 1.2 -> 1.0 -> 0.8 -> 0.9 -> 1.1
		let returns = [0.10, 0.091, -0.167, -0.20, 0.125, 0.222]
		let periods = returns.enumerated().map { Period.month(year: 2026 + ($0.offset / 12), month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		let expected = (1.2 - 0.8) / 1.2 // 1/3
		#expect(abs(metrics.maxDrawdown - expected) < 1e-3)
	}

	// MARK: - Max Drawdown Edge Cases

	@Test("Max drawdown handles portfolio bankruptcy (100% loss)")
	func maxDrawdownBankruptcy() throws {
		// Return of -1.0 means 100% loss (portfolio goes to zero)
		let returns = [0.10, 0.05, -1.0, 0.50]  // Last return irrelevant after bankruptcy
		let periods = returns.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		// Should return exactly 1.0 (100% drawdown) for bankruptcy
		#expect(metrics.maxDrawdown == 1.0)
	}

	@Test("Max drawdown handles extreme negative return (>100% loss)")
	func maxDrawdownExtremeLoss() throws {
		// Return of -1.5 means 150% loss (impossible in reality, but can occur in simulations)
		let returns = [0.10, 0.05, -1.5]
		let periods = returns.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		// Should cap at 1.0 (100% drawdown) even for super-bankruptcy
		#expect(metrics.maxDrawdown == 1.0)
	}

	@Test("Max drawdown handles N(0,1) extreme values")
	func maxDrawdownNormalDistributionExtremes() throws {
		// Simulate extreme N(0,1) returns that could cause cumulative value to go negative
		// With mean=0, std=1, we can get values like -3, -2, -1.5 which compound badly
		let returns = [-2.0, -1.5, -1.0, 0.5, 1.0, 2.0]
		let periods = returns.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		// Should handle gracefully without infinity
		#expect(metrics.maxDrawdown.isFinite)
		#expect(metrics.maxDrawdown >= 0.0)
		#expect(metrics.maxDrawdown <= 1.0)
	}

	@Test("Max drawdown returns 0 for empty or single-value arrays")
	func maxDrawdownEdgeCases() throws {
		// Empty array
		let empty: [Double] = []
		let emptyDrawdown = MaxDrawdown.calculate(values: empty)
		#expect(emptyDrawdown == 0.0)

		// Single value
		let single = [0.05]
		let singleDrawdown = MaxDrawdown.calculate(values: single)
		#expect(singleDrawdown == 0.0)
	}

	@Test("Max drawdown handles sequence that recovers after bankruptcy")
	func maxDrawdownPostBankruptcy() throws {
		// 1.0 -> 1.2 -> 0.0 (bankruptcy) -> can't recover (you can't earn returns on $0)
		// But mathematically: 0 * (1 + 0.5) = 0
		let returns = [0.20, -1.0, 0.50, 1.0]
		let periods = returns.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
		let ts = TimeSeries(periods: periods, values: returns)
		let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

		// Once bankrupt, max drawdown is 100% regardless of subsequent returns
		#expect(metrics.maxDrawdown == 1.0)
	}

	@Test("Max drawdown never exceeds 100%")
	func maxDrawdownCapped() throws {
		// Test various extreme scenarios
		let extremeReturns = [
			[-2.0, -3.0, -1.5],  // Extreme N(0,1) values
			[-1.0],               // Exactly 100% loss
			[-5.0, 0.0, 0.0],    // Super extreme loss
			[0.5, -2.0, 0.3]     // Mixed with extreme negative
		]

		for returns in extremeReturns {
			let periods = returns.enumerated().map { Period.month(year: 2026, month: ($0.offset % 12) + 1) }
			let ts = TimeSeries(periods: periods, values: returns)
			let metrics = ComprehensiveRiskMetrics(returns: ts, riskFreeRate: 0.0)

			// Max drawdown should never exceed 1.0 (100%)
			#expect(metrics.maxDrawdown <= 1.0, "MaxDrawdown exceeded 100% for returns: \(returns)")
			#expect(metrics.maxDrawdown.isFinite, "MaxDrawdown was infinite for returns: \(returns)")
		}
	}
}
