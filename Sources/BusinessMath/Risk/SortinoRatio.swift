//
//  SortinoRatio.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
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
/// - ``SharpeRatio`` - Penalizes all volatility (upside and downside)
/// - ``Skewness`` - Measures distribution asymmetry
public struct SortinoRatio {

	/// Calculate Sortino ratio for a series of returns.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - riskFreeRate: Minimum acceptable return (default: 0).
	/// - Returns: Sortino ratio value.
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
		guard !values.isEmpty else { return T(0) }

		let meanReturn = mean(values)

		// Calculate downside deviation (only returns below risk-free rate)
		let downsideReturns = values.filter { $0 < riskFreeRate }

		if downsideReturns.count > 0 {
			let downsideDiffs = downsideReturns.map { ($0 - riskFreeRate) * ($0 - riskFreeRate) }
			let downsideDiffsSum = downsideDiffs.reduce(T(0), +)
			let downsideVariance = downsideDiffsSum / T(downsideReturns.count)
			let downsideDeviation = T.sqrt(downsideVariance)

			if downsideDeviation > T(0) {
				return (meanReturn - riskFreeRate) / downsideDeviation
			} else {
				return T(0)
			}
		} else {
			// No downside risk
			return T(0)
		}
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
