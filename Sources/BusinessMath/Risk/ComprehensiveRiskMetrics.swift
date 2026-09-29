//
//  ComprehensiveRiskMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - ComprehensiveRiskMetrics

/// Comprehensive risk metrics for return distributions (convenience wrapper).
///
/// `ComprehensiveRiskMetrics` provides a convenient way to calculate all risk measures
/// at once. For individual metrics, use the focused types:
/// - ``ValueAtRisk``
/// - ``ConditionalValueAtRisk``
/// - ``MaxDrawdown``
/// - ``SharpeRatio``
/// - ``SortinoRatio``
/// - ``TailRisk``
/// - ``Skewness``
/// - ``Kurtosis``
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
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
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
	///
	/// - Note: Given no returns, every field is `nan`. Each metric reaches that on its own
	///   terms; this initializer no longer substitutes a value for any of them.
	public init(valuesArray: [T], riskFreeRate: T = T(0)) {
		// An empty array used to be answered here, in full, by a block labelled only
		// "Edge case: no data" — VaR 0, VaR₉₉ 0, CVaR 0, drawdown 0, Sharpe 0, Sortino 0,
		// tail risk 1, skew 0, kurtosis 0. Read as a report, which is exactly what
		// `description` renders it as, that is a portfolio with no threshold loss, no
		// shortfall, no peak it ever fell below, no excess return, symmetric returns and
		// normal tails: the most reassuring risk profile expressible in these nine numbers,
		// assembled from no observations.
		//
		// It also bypassed all eight types below, so fixing their empty-sample contracts
		// individually would have changed nothing here — the aggregate was its own second
		// implementation. Deleting the block is the fix: each metric now answers `nan` for
		// an empty sample, and this type reports what they say.
		//
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
