//
//  SharpeRatio.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
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
/// let returnsA = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// let returnsB = [0.06, 0.04, -0.05, -0.02, 0.09, 0.03]
/// let strategyA = SharpeRatio.calculate(values: returnsA, riskFreeRate: 0.02)  // 1.8
/// let strategyB = SharpeRatio.calculate(values: returnsB, riskFreeRate: 0.02)  // 1.2
///
/// // Strategy A has better risk-adjusted returns
/// ```
///
/// ## See Also
///
/// - ``SortinoRatio``
/// - ``MaxDrawdown``
public struct SharpeRatio {

	/// Calculate Sharpe ratio for a series of returns.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - riskFreeRate: Risk-free rate for excess return calculation (default: 0).
	/// - Returns: Sharpe ratio value, or `nan` when there are no returns to rate. A Sharpe
	///   of `0` is reserved for its real meaning — a return that exactly matched the
	///   risk-free rate — and is not used to stand in for "no data".
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
		// This returned `T(0)`, and on the scale a caller reads a Sharpe ratio on, `0` is a
		// statement: the strategy earned exactly the risk-free rate for the risk it took.
		// It sorts alongside real flat strategies and above every losing one, so an empty
		// return series ranked ahead of anything that actually lost money. `mean` and
		// `stdDev` both answer `nan` for an empty sample; this guard was the only thing
		// stopping that from reaching the caller.
		guard !values.isEmpty else { return T.nan }

		let meanReturn = mean(values)
		let standardDeviation = stdDev(values)

		return riskAdjustedRatio(excessReturn: meanReturn - riskFreeRate, risk: standardDeviation)
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
