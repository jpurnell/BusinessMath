//
//  RiskMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - ComprehensiveRiskMetrics

/// Comprehensive risk metrics for return distributions.
///
/// `ComprehensiveRiskMetrics` calculates a complete set of risk measures
/// from a time series of returns, including:
/// - Value at Risk (VaR) at 95% and 99% confidence levels
/// - Conditional VaR (CVaR / Expected Shortfall)
/// - Maximum drawdown
/// - Sharpe and Sortino ratios
/// - Tail risk, skewness, and kurtosis
///
/// ## Usage
///
/// ```swift
/// let returns = TimeSeries(periods: periods, values: returnValues)
/// let metrics = ComprehensiveRiskMetrics(
///     returns: returns,
///     riskFreeRate: 0.03
/// )
///
/// print(metrics.var95)
/// print(metrics.sharpeRatio)
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

	/// Initialize with a Real Number.
	///
	/// - Parameters:
	///   - valuesArray: Array of return values.
	///   - riskFreeRate: Risk-free rate for ratio calculations.
	public init(valuesArray: [T], riskFreeRate: T = T(0)) {
		let values = valuesArray.sorted()
		let n = values.count
		
		guard n > 0 else {
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

		// VaR calculation
		let var95Index = max(0, Int(Double(n) * 0.05) - 1)
		let var99Index = max(0, Int(Double(n) * 0.01) - 1)
		self.var95 = values[var95Index]
		self.var99 = values[var99Index]

		// CVaR (average of losses beyond VaR)
		let tailLosses = values[0...var95Index]
		let sumTailLosses = tailLosses.reduce(T(0), +)
		self.cvar95 = sumTailLosses / T(tailLosses.count)

		// Max drawdown
		self.maxDrawdown = Self.calculateMaxDrawdown(values)

		// Mean and variance
		let mean = mean(values)
		_ = variance(values)
		let stdDev = stdDev(values)

		// Sharpe ratio
		if stdDev > T(0) {
			self.sharpeRatio = (mean - riskFreeRate) / stdDev
		} else {
			self.sharpeRatio = T(0)
		}

		// Sortino ratio (downside deviation only)
		let downsideReturns = values.filter { $0 < riskFreeRate }
		if downsideReturns.count > 0 {
			let downsideDiffs = downsideReturns.map { ($0 - riskFreeRate) * ($0 - riskFreeRate) }
			let downsideDiffsSum = downsideDiffs.reduce(0, +)
			let downsideVariance = downsideDiffsSum / T(downsideReturns.count)
			let downsideDeviation = T.sqrt(downsideVariance)
			if downsideDeviation > T(0) {
				self.sortinoRatio = (mean - riskFreeRate) / downsideDeviation
			} else {
				self.sortinoRatio = T(0)
			}
		} else {
			// No downside risk
			self.sortinoRatio = T(0)
		}

		// Tail risk
		if var95 != T(0) {
			let ratio = cvar95 / var95
			self.tailRisk = ratio < T(0) ? -ratio : ratio
		} else {
			self.tailRisk = T(1)
		}

		// Skewness
		if stdDev > T(0) {
			let skewSum = values.map {
				let z = ($0 - mean) / stdDev
				return z * z * z  // z^3
			}.reduce(T(0), +)
			self.skewness = skewSum / T(n)
		} else {
			self.skewness = T(0)
		}

		// Kurtosis (excess kurtosis: normal = 0)
		if stdDev > T(0) {
			let kurtSum = values.map {
				let z = ($0 - mean) / stdDev
				let z2 = z * z
				return z2 * z2  // z^4
			}.reduce(T(0), +)
			self.kurtosis = (kurtSum / T(n)) - T(3)
		} else {
			self.kurtosis = T(0)
		}
	}
	
	/// Initialize with time series of returns.
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - riskFreeRate: Risk-free rate for ratio calculations.
	public init(returns: TimeSeries<T>, riskFreeRate: T = T(0)) {
		let values = returns.valuesArray.sorted()
		
		self.init(valuesArray: values, riskFreeRate: riskFreeRate)
	}

	// MARK: - Max Drawdown Calculation

	/// Calculate maximum drawdown from a series of values.
	private static func calculateMaxDrawdown(_ values: [T]) -> T {
		guard values.count > 1 else { return T(0) }

		var maxDrawdown: T = 0

		// Convert returns to cumulative prices
		var cumulativeValue: T = T(1)
		var cumulativePeak: T = T(1)

		for value in values {
			cumulativeValue = cumulativeValue * (T(1) + value)

			if cumulativeValue > cumulativePeak {
				cumulativePeak = cumulativeValue
			}

			let drawdown = (cumulativePeak - cumulativeValue) / cumulativePeak
			if drawdown > maxDrawdown {
				maxDrawdown = drawdown
			}
		}

		return maxDrawdown
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
