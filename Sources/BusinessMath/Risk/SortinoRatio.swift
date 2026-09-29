//
//  SortinoRatio.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
//

import Foundation
import Numerics

/// Sortino ratio calculator for downside risk-adjusted returns.
///
/// The Sortino ratio is similar to the Sharpe ratio but only penalizes downside volatility.
/// It answers: "How much return am I getting per unit of *downside* risk?"
///
/// Formula: (Mean Return - Risk-Free Rate) / Downside Deviation
///
/// ## Usage
///
/// ```swift
/// let returns = [0.10, 0.15, -0.02, 0.12, -0.01, 0.08]
/// let sortino = SortinoRatio.calculate(values: returns, riskFreeRate: 0.03)
/// print("Sortino Ratio: \(sortino)") // e.g., 2.1
/// ```
///
/// ## Interpretation
///
/// - **Sortino > Sharpe**: Strategy has positive skew (limited downside, larger upside)
/// - **Sortino ≈ Sharpe**: Roughly symmetric return distribution
/// - **Sortino > 2.0**: Excellent downside risk-adjusted returns
///
/// ## Example: vs Sharpe Ratio
///
/// ```swift
/// // Strategy with limited downside, large upside
/// let returns = [0.20, 0.25, -0.01, 0.18, -0.02, 0.22]
///
/// let sharpe = SharpeRatio.calculate(values: returns, riskFreeRate: 0.03)
/// let sortino = SortinoRatio.calculate(values: returns, riskFreeRate: 0.03)
///
/// // Sortino will be higher because it ignores upside volatility
/// ```
///
/// ## See Also
///
/// - ``SharpeRatio``
/// - ``Skewness``
public struct SortinoRatio {

	/// Calculate Sortino ratio for a series of returns.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - riskFreeRate: Minimum acceptable return (default: 0).
	/// - Returns: Sortino ratio value, or `nan` when there are no returns to rate. As with
	///   ``SharpeRatio``, `0` keeps its real meaning — a return that exactly matched the
	///   minimum acceptable return — and is not used to stand in for "no data".
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [0.10, 0.15, -0.02, 0.08]
	/// let sortino = SortinoRatio.calculate(values: returns, riskFreeRate: 0.03)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T],
		riskFreeRate: T = T(0)
	) -> T {
		// See `SharpeRatio.calculate`: this returned `T(0)`, which on a Sortino scale reads
		// as "earned exactly the minimum acceptable return" — a real, middling outcome that
		// sorts above every strategy with genuine downside. Note that it also collided with
		// the case reasoned about below: a series with *no downside periods at all* is the
		// best outcome Sortino can describe and answers `±infinity`, so before this change
		// "no data" and "no losses" were the two ends of the scale and only one of them was
		// being told the truth.
		guard !values.isEmpty else { return T.nan }

		let meanReturn = mean(values)

		// Calculate downside deviation (only returns below risk-free rate)
		let downsideReturns = values.filter { $0 < riskFreeRate }

		// No downside periods at all is the best outcome Sortino can describe, not a
		// mediocre one: the denominator is zero, so the ratio is unbounded rather than `0`.
		// It is the same zero-risk case as a downside deviation that works out to zero, so
		// both fall through to the shared guard.
		var downsideDeviation = T(0)
		if downsideReturns.count > 0 {
			let downsideDiffs = downsideReturns.map { ($0 - riskFreeRate) * ($0 - riskFreeRate) }
			let downsideDiffsSum = downsideDiffs.reduce(T(0), +)
			let downsideVariance = downsideDiffsSum / T(downsideReturns.count)
			downsideDeviation = T.sqrt(downsideVariance)
		}
		return riskAdjustedRatio(excessReturn: meanReturn - riskFreeRate, risk: downsideDeviation)
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate Sortino ratio from a time series (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - riskFreeRate: Minimum acceptable return (default: 0).
	/// - Returns: Sortino ratio value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>,
		riskFreeRate: T = T(0)
	) -> T {
		return calculate(values: returns.valuesArray, riskFreeRate: riskFreeRate)
	}
}
