//
//  ValueAtRisk.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Value at Risk (VaR) calculator for return distributions.
///
/// VaR measures the maximum expected loss over a given time period at a specified
/// confidence level. For example, VaR₉₅ represents the 5th percentile of losses -
/// in the worst 5% of outcomes, losses will exceed this threshold.
///
/// ## Usage
///
/// ```swift
/// let returns = [-0.05, -0.02, 0.01, 0.03, 0.04, 0.02, -0.01, 0.05]
/// let periods = returns.enumerated().map { Period.month(year: 2025, month: $0.offset + 1) }
/// let timeSeries = TimeSeries(periods: periods, values: returns)
///
/// // Calculate VaR at 95% confidence level
/// let var95 = ValueAtRisk.calculate(returns: timeSeries, confidenceLevel: 0.95)
/// print("VaR₉₅: \(var95)") // e.g., -0.03 (3% loss)
///
/// // Calculate VaR at 99% confidence level
/// let var99 = ValueAtRisk.calculate(returns: timeSeries, confidenceLevel: 0.99)
/// print("VaR₉₉: \(var99)") // e.g., -0.05 (5% loss, more extreme)
/// ```
///
/// ## Interpretation
///
/// - **Negative values** indicate potential losses
/// - **VaR₉₅ = -3%**: In the worst 5% of outcomes, losses exceed 3%
/// - **VaR₉₉ = -5%**: In the worst 1% of outcomes, losses exceed 5%
/// - Higher confidence levels (99% vs 95%) produce more extreme VaR estimates
///
/// ## Limitations
///
/// - VaR says nothing about the magnitude of losses beyond the threshold
/// - Does not capture tail risk (use CVaR for tail-aware risk measurement)
/// - Assumes historical distribution represents future risk
///
/// ## See Also
///
/// - ``ConditionalValueAtRisk`` - Expected loss beyond VaR threshold
/// - ``TailRisk`` - Ratio of CVaR to VaR measuring tail severity
public struct ValueAtRisk {

	/// Calculate Value at Risk at a specified confidence level.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%, 0.99 for 99%).
	/// - Returns: VaR value (negative indicates loss threshold).
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [-0.05, -0.02, 0.01, 0.03, 0.04]
	/// let var95 = ValueAtRisk.calculate(values: returns, confidenceLevel: 0.95)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T],
		confidenceLevel: T
	) -> T {
		guard !values.isEmpty else { return T(0) }

		let sorted = values.sorted()
		let n = sorted.count

		// Calculate percentile index (lower tail)
		let alpha = T(1) - confidenceLevel
		let index = max(0, Int(Double(n) * Double(alpha)) - 1)

		return sorted[index]
	}

	/// Calculate VaR at 95% confidence level (common standard).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: VaR₉₅ value.
	///
	/// ## Example
	///
	/// ```swift
	/// let var95 = ValueAtRisk.var95(values: returns)
	/// ```
	public static func var95<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		return calculate(values: values, confidenceLevel: T(0.95))
	}

	/// Calculate VaR at 99% confidence level (conservative standard).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: VaR₉₉ value.
	///
	/// ## Example
	///
	/// ```swift
	/// let var99 = ValueAtRisk.var99(values: returns)
	/// ```
	public static func var99<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		return calculate(values: values, confidenceLevel: T(0.99))
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate Value at Risk from a time series (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%, 0.99 for 99%).
	/// - Returns: VaR value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>,
		confidenceLevel: T
	) -> T {
		return calculate(values: returns.valuesArray, confidenceLevel: confidenceLevel)
	}

	/// Calculate VaR₉₅ from a time series (convenience method).
	public static func var95<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return var95(values: returns.valuesArray)
	}

	/// Calculate VaR₉₉ from a time series (convenience method).
	public static func var99<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return var99(values: returns.valuesArray)
	}
}
