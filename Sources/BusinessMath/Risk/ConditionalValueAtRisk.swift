//
//  ConditionalValueAtRisk.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Conditional Value at Risk (CVaR) calculator, also known as Expected Shortfall.
///
/// CVaR measures the average loss in the worst-case scenarios beyond the VaR threshold.
/// While VaR tells you the threshold loss, CVaR tells you how bad losses are when they
/// exceed that threshold.
///
/// ## Usage
///
/// ```swift
/// let returns = [-0.10, -0.05, -0.02, 0.01, 0.03, 0.02, -0.01, 0.05]
///
/// // Calculate CVaR at 95% confidence level
/// let cvar95 = ConditionalValueAtRisk.calculate(values: returns, confidenceLevel: 0.95)
/// print("CVaR₉₅: \(cvar95)") // e.g., -0.06 (average loss in worst 5%)
/// ```
///
/// ## Interpretation
///
/// - **CVaR₉₅ = -6%**: In the worst 5% of outcomes, average loss is 6%
/// - **CVaR is always more extreme than VaR** (CVaR₉₅ <= VaR₉₅ for losses)
/// - CVaR captures tail risk that VaR misses
///
/// ## Example: Portfolio Risk
///
/// ```swift
/// let var95 = ValueAtRisk.var95(values: returns)    // -5%
/// let cvar95 = ConditionalValueAtRisk.cvar95(values: returns)  // -7%
///
/// // CVaR tells you: "When losses exceed 5% threshold (VaR),
/// //                  they average 7% (CVaR)"
/// ```
///
/// ## See Also
///
/// - ``ValueAtRisk`` - Loss threshold at given confidence level
/// - ``TailRisk`` - Ratio of CVaR to VaR measuring tail severity
public struct ConditionalValueAtRisk {

	/// Calculate Conditional Value at Risk at a specified confidence level.
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%, 0.99 for 99%).
	/// - Returns: CVaR value (negative indicates average loss in tail).
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [-0.10, -0.05, -0.02, 0.01, 0.03]
	/// let cvar95 = ConditionalValueAtRisk.calculate(values: returns, confidenceLevel: 0.95)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T],
		confidenceLevel: T
	) -> T {
		guard !values.isEmpty else { return T(0) }

		let sorted = values.sorted()
		let n = sorted.count

		// Calculate VaR index
		let alpha = T(1) - confidenceLevel
		let varIndex = max(0, Int(Double(n) * Double(alpha)) - 1)

		// Average of losses beyond VaR
		let tailLosses = sorted[0...varIndex]
		let sumTailLosses = tailLosses.reduce(T(0), +)

		return sumTailLosses / T(tailLosses.count)
	}

	/// Calculate CVaR at 95% confidence level (common standard).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: CVaR₉₅ value.
	///
	/// ## Example
	///
	/// ```swift
	/// let cvar95 = ConditionalValueAtRisk.cvar95(values: returns)
	/// ```
	public static func cvar95<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		return calculate(values: values, confidenceLevel: T(0.95))
	}

	/// Calculate CVaR at 99% confidence level (conservative standard).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: CVaR₉₉ value.
	///
	/// ## Example
	///
	/// ```swift
	/// let cvar99 = ConditionalValueAtRisk.cvar99(values: returns)
	/// ```
	public static func cvar99<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		return calculate(values: values, confidenceLevel: T(0.99))
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate CVaR from a time series (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%, 0.99 for 99%).
	/// - Returns: CVaR value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>,
		confidenceLevel: T
	) -> T {
		return calculate(values: returns.valuesArray, confidenceLevel: confidenceLevel)
	}

	/// Calculate CVaR₉₅ from a time series (convenience method).
	public static func cvar95<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return cvar95(values: returns.valuesArray)
	}

	/// Calculate CVaR₉₉ from a time series (convenience method).
	public static func cvar99<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return cvar99(values: returns.valuesArray)
	}
}
