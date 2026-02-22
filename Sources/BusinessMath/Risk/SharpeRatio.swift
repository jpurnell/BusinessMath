//
//  SharpeRatio.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Sharpe ratio calculator for risk-adjusted returns.
///
/// The Sharpe ratio measures excess return per unit of total volatility. It answers:
/// "How much return am I getting for each unit of risk I'm taking?"
///
/// Formula: (Mean Return - Risk-Free Rate) / Standard Deviation
///
/// ## Usage
///
/// ```swift
/// let returns = [0.08, 0.10, 0.05, 0.12, 0.07]
/// let sharpe = SharpeRatio.calculate(values: returns, riskFreeRate: 0.03)
/// print("Sharpe Ratio: \(sharpe)") // e.g., 1.5 (good risk-adjusted performance)
/// ```
///
/// ## Interpretation
///
/// - **Sharpe > 1.0**: Good risk-adjusted returns
/// - **Sharpe > 2.0**: Excellent risk-adjusted returns
/// - **Sharpe > 3.0**: Outstanding (rare for most strategies)
/// - **Sharpe < 1.0**: Questionable risk/reward tradeoff
///
/// ## Example: Comparing Strategies
///
/// ```swift
/// let strategyA = SharpeRatio.calculate(values: returnsA, riskFreeRate: 0.02)  // 1.8
/// let strategyB = SharpeRatio.calculate(values: returnsB, riskFreeRate: 0.02)  // 1.2
///
/// // Strategy A has better risk-adjusted returns
/// ```
///
/// ## See Also
///
/// - ``SortinoRatio`` - Only penalizes downside volatility
/// - ``MaxDrawdown`` - Maximum peak-to-trough decline
public struct SharpeRatio {

	/// Calculate Sharpe ratio for a series of returns.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - riskFreeRate: Risk-free rate for excess return calculation (default: 0).
	/// - Returns: Sharpe ratio value.
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [0.08, 0.10, 0.05, 0.12]
	/// let sharpe = SharpeRatio.calculate(values: returns, riskFreeRate: 0.03)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T],
		riskFreeRate: T = T(0)
	) -> T {
		guard !values.isEmpty else { return T(0) }

		let meanReturn = mean(values)
		let standardDeviation = stdDev(values)

		if standardDeviation > T(0) {
			return (meanReturn - riskFreeRate) / standardDeviation
		} else {
			return T(0)
		}
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate Sharpe ratio from a time series (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - riskFreeRate: Risk-free rate (default: 0).
	/// - Returns: Sharpe ratio value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>,
		riskFreeRate: T = T(0)
	) -> T {
		return calculate(values: returns.valuesArray, riskFreeRate: riskFreeRate)
	}
}
