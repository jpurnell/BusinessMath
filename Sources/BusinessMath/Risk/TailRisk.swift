//
//  TailRisk.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Tail risk calculator measuring severity of extreme losses.
///
/// Tail risk is the ratio of CVaR to VaR, measuring how much worse losses are
/// in the extreme tail compared to the VaR threshold.
///
/// Formula: |CVaR / VaR|
///
/// ## Usage
///
/// ```swift
/// let returns = [-0.15, -0.08, -0.05, -0.02, 0.01, 0.03, 0.05]
///
/// let tailRisk = TailRisk.calculate(values: returns, confidenceLevel: 0.95)
/// print("Tail Risk: \(tailRisk)") // e.g., 1.4
/// ```
///
/// ## Interpretation
///
/// - **Tail Risk = 1.0**: Uniform distribution in tail (CVaR ≈ VaR)
/// - **Tail Risk > 1.0**: Fat tails (losses in tail worse than VaR suggests)
/// - **Tail Risk = 1.5**: Average loss in worst 5% is 50% worse than VaR threshold
///
/// ## Example: Tail Severity
///
/// ```swift
/// let var95 = -5%    // VaR threshold
/// let cvar95 = -7.5% // Average loss beyond VaR
/// let tailRisk = 7.5 / 5.0 = 1.5
///
/// // When losses exceed VaR, they're 50% worse on average
/// ```
///
/// ## See Also
///
/// - ``ValueAtRisk`` - Loss threshold at confidence level
/// - ``ConditionalValueAtRisk`` - Average loss beyond VaR
/// - ``Kurtosis`` - Measures tail thickness of distribution
public struct TailRisk {

	/// Calculate tail risk ratio (CVaR / VaR).
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - confidenceLevel: Confidence level (default: 0.95).
	/// - Returns: Tail risk ratio (>=  1.0).
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [-0.10, -0.05, -0.02, 0.01, 0.03]
	/// let tailRisk = TailRisk.calculate(values: returns, confidenceLevel: 0.95)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T],
		confidenceLevel: T = T(0.95)
	) -> T {
		let varValue = ValueAtRisk.calculate(values: values, confidenceLevel: confidenceLevel)
		let cvarValue = ConditionalValueAtRisk.calculate(values: values, confidenceLevel: confidenceLevel)

		if varValue != T(0) {
			let ratio = cvarValue / varValue
			return ratio < T(0) ? -ratio : ratio
		} else {
			return T(1)
		}
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate tail risk from a time series (convenience method).
	///
	/// - Parameters:
	///   - returns: Time series of return values.
	///   - confidenceLevel: Confidence level (default: 0.95).
	/// - Returns: Tail risk ratio.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>,
		confidenceLevel: T = T(0.95)
	) -> T {
		return calculate(values: returns.valuesArray, confidenceLevel: confidenceLevel)
	}
}
