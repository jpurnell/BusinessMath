//
//  ComprehensiveRiskMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//  Refactored by Claude on 2026-02-20.
//

import Foundation
import Numerics

// MARK: - ComprehensiveRiskMetrics

/// Comprehensive risk metrics for return distributions (convenience wrapper).
///
/// `ComprehensiveRiskMetrics` provides a convenient way to calculate all risk measures
/// at once. For individual metrics, use the focused types:
/// - ``ValueAtRisk`` - VaR at various confidence levels
/// - ``ConditionalValueAtRisk`` - CVaR / Expected Shortfall
/// - ``MaxDrawdown`` - Peak-to-trough decline
/// - ``SharpeRatio`` - Risk-adjusted returns
/// - ``SortinoRatio`` - Downside risk-adjusted returns
/// - ``TailRisk`` - Tail severity measure
/// - ``Skewness`` - Distribution asymmetry
/// - ``Kurtosis`` - Tail thickness
///
/// ## Usage
///
/// ```swift
/// let returns = [-0.05, -0.02, 0.01, 0.03, 0.04, 0.02, -0.01, 0.05]
/// let metrics = ComprehensiveRiskMetrics(
///     valuesArray: returns,
///     riskFreeRate: 0.03
/// )
///
/// print(metrics.var95)
/// print(metrics.sharpeRatio)
/// ```
///
/// ## Individual Metrics (Preferred for Focused Analysis)
///
/// ```swift
/// // Use individual types when you only need specific metrics
/// let var95 = ValueAtRisk.var95(values: returns)
/// let sharpe = SharpeRatio.calculate(values: returns, riskFreeRate: 0.03)
/// let maxDD = MaxDrawdown.calculate(values: returns)
/// ```
public struct ComprehensiveRiskMetrics<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// Value at Risk (95% confidence level).
	public let var95: T

	/// Value at Risk (99% confidence level).
	public let var99: T

	/// Conditional VaR / Expected Shortfall (95%).
	public let cvar95: T

	/// Maximum drawdown (peak-to-trough decline).
	public let maxDrawdown: T

	/// Sharpe ratio (excess return / total volatility).
	public let sharpeRatio: T

	/// Sortino ratio (excess return / downside volatility).
	public let sortinoRatio: T

	/// Tail risk measure (CVaR / VaR ratio).
	public let tailRisk: T

	/// Skewness (asymmetry of distribution).
	public let skewness: T

	/// Excess kurtosis (tail thickness).
	public let kurtosis: T

	/// Initialize with array of returns.
	///
	/// - Parameters:
	///   - valuesArray: Array of return values.
	///   - riskFreeRate: Risk-free rate for ratio calculations (default: 0).
	public init(valuesArray: [T], riskFreeRate: T = T(0)) {
		guard !valuesArray.isEmpty else {
			// Edge case: no data
			self.var95 = T(0)
			self.var99 = T(0)
			self.cvar95 = T(0)
			self.maxDrawdown = T(0)
			self.sharpeRatio = T(0)
			self.sortinoRatio = T(0)
			self.tailRisk = T(1)
			self.skewness = T(0)
			self.kurtosis = T(0)
			return
		}

		// Calculate all metrics using focused types
		self.var95 = ValueAtRisk.var95(values: valuesArray)
		self.var99 = ValueAtRisk.var99(values: valuesArray)
		self.cvar95 = ConditionalValueAtRisk.cvar95(values: valuesArray)
		self.maxDrawdown = MaxDrawdown.calculate(values: valuesArray)
		self.sharpeRatio = SharpeRatio.calculate(values: valuesArray, riskFreeRate: riskFreeRate)
		self.sortinoRatio = SortinoRatio.calculate(values: valuesArray, riskFreeRate: riskFreeRate)
		self.tailRisk = TailRisk.calculate(values: valuesArray, confidenceLevel: T(0.95))
		self.skewness = Skewness.calculate(values: valuesArray)
		self.kurtosis = Kurtosis.calculate(values: valuesArray)
	}

	/// Initialize with time series of returns (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - riskFreeRate: Risk-free rate for ratio calculations (default: 0).
	public init(returns: TimeSeries<T>, riskFreeRate: T = T(0)) {
		self.init(valuesArray: returns.valuesArray, riskFreeRate: riskFreeRate)
	}

	// MARK: - Description

	/// A localized human-readable description of the components of the struct.
	public var description: String {
		return """
		Comprehensive Risk Metrics:
		  VaR (95%): \(var95.percent())
		  VaR (99%): \(var99.percent())
		  CVaR (95%): \(cvar95.percent())
		  Max Drawdown: \(maxDrawdown.percent())
		  Sharpe Ratio: \(sharpeRatio.number())
		  Sortino Ratio: \(sortinoRatio.number())
		  Tail Risk: \(tailRisk.number())
		  Skewness: \(skewness.number())
		  Kurtosis: \(kurtosis.number())
		"""
	}
}
