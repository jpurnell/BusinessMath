//
//  TailRisk.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
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
/// // Illustrative values, not the output of a call: given a VaR and a CVaR,
/// // the tail risk ratio is their quotient.
/// let var95 = -0.05    // VaR threshold, -5%
/// let cvar95 = -0.075  // Average loss beyond VaR, -7.5%
/// let tailRisk = cvar95 / var95   // 1.5
///
/// // When losses exceed VaR, they're 50% worse on average
/// ```
///
/// ## See Also
///
/// - ``ValueAtRisk``
/// - ``ConditionalValueAtRisk``
/// - ``Kurtosis``
public struct TailRisk {

	/// Calculate tail risk ratio (CVaR / VaR).
	///
	/// - Parameters:
	///   - values: Array of return values.
	///   - confidenceLevel: Confidence level (default: 0.95).
	/// - Returns: Tail risk ratio (>= 1.0); `infinity` when the value at risk is zero but
	///   the expected shortfall is not; `nan` when there is no ratio to take, because the
	///   sample is empty, contains `nan`, or has both a zero threshold and a zero shortfall.
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

		// This used to branch on `varValue != T(0)` and answer `T(1)` otherwise. `1` is the
		// floor of this ratio's documented range and means "the average loss in the tail is
		// no worse than the threshold itself" — the most benign shape a tail can have. It was
		// being reported for a zero value at risk, where the ratio does not exist at all, and
		// it was the answer an empty sample reached too, because `ValueAtRisk` used to answer
		// `0` for one.
		//
		// The branch is gone rather than rewritten because IEEE division already
		// distinguishes the three cases the branch flattened: a zero shortfall over a zero
		// threshold is `nan`, a real shortfall over a zero threshold is `-infinity` (whose
		// magnitude, below, is `infinity`), and a `nan` from either input propagates. The
		// comparison also fails for `nan`, so the magnitude step leaves it untouched.
		let ratio = cvarValue / varValue
		return ratio < T(0) ? -ratio : ratio
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
