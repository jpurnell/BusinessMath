//
//  MaxDrawdown.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
//

import Foundation
import Numerics

/// Maximum drawdown calculator for return series.
///
/// Maximum drawdown measures the largest peak-to-trough decline in portfolio value.
/// It represents the worst loss an investor would have experienced from a historical
/// peak to a subsequent low.
///
/// ## Usage
///
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// let maxDD = MaxDrawdown.calculate(values: returns)
/// print("Max Drawdown: \(maxDD)") // e.g., 0.25 (25% decline from peak)
/// ```
///
/// ## Interpretation
///
/// - **Max Drawdown = 25%**: Portfolio declined 25% from its highest point
/// - **Lower is better**: Smaller drawdowns indicate less severe declines
/// - Measured as positive percentage (0.25 = 25% drawdown)
///
/// ## Example: Peak-to-Trough
///
/// ```swift
/// // Portfolio path: $100 → $110 → $120 → $90 → $100
/// // Returns: [10%, 9.09%, -25%, 11.11%]
/// // Max drawdown from $120 peak to $90 trough = 25%
/// ```
///
/// ## See Also
///
/// - ``SharpeRatio``
/// - ``SortinoRatio``
public struct MaxDrawdown {

	/// Calculate maximum drawdown from a series of returns.
	///
	/// - Parameter values: Array of return values.
	/// - Returns: Maximum drawdown as positive decimal (0.25 = 25% drawdown), or `nan` for
	///   an empty array. `0` is reserved for its real meaning — an equity curve that never
	///   closed below a previous peak.
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [0.05, 0.03, -0.08, 0.02]
	/// let maxDD = MaxDrawdown.calculate(values: returns)
	/// ```
	///
	/// ## Edge Cases
	///
	/// - Returns 1.0 (100% drawdown) if cumulative value reaches zero or negative
	/// - Returns `nan` for an empty array — there is no equity curve to draw down
	/// - A single return is a valid one-period equity curve: `[-0.08]` is an 8% drawdown
	///   and `[0.05]` is 0%
	/// - Handles extreme return values that cause portfolio bankruptcy
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		// This was `guard values.count > 1 else { return T(0) }`, and it was wrong twice over.
		//
		// On an empty array it answered `0`, which on a drawdown scale is the best possible
		// number: this portfolio never once closed below a previous peak. A position with no
		// history screened as safer than every position with one.
		//
		// On a *single* return it answered `0` as well, and that was not a sentinel at all —
		// it was arithmetic this function can do and declined to. One return is one period of
		// an equity curve that starts at 1: `[-0.08]` ends at 0.92, a peak-to-trough decline
		// of 8%. The old guard reported that loss as no loss. Only the empty case is
		// genuinely unanswerable, so only the empty case is refused; the loop below already
		// handles `count == 1` correctly.
		guard !values.isEmpty else { return T.nan }

		var maxDrawdown: T = 0

		// Convert returns to cumulative prices
		var cumulativeValue: T = T(1)
		var cumulativePeak: T = T(1)

		for value in values {
			cumulativeValue = cumulativeValue * (T(1) + value)

			// Handle portfolio bankruptcy (cumulative value <= 0)
			// This represents a 100% or greater loss
			if cumulativeValue <= T(0) {
				return T(1)  // 100% drawdown (total loss)
			}

			if cumulativeValue > cumulativePeak {
				cumulativePeak = cumulativeValue
			}

			// Safe to divide since we've checked cumulativePeak > 0
			// (cumulativePeak starts at 1 and only increases or stays same)
			let drawdown = (cumulativePeak - cumulativeValue) / cumulativePeak
			if drawdown > maxDrawdown {
				maxDrawdown = drawdown
			}
		}

		return maxDrawdown
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate maximum drawdown from a time series (convenience method).
	///
	/// - Parameter returns: Time series of return values.
	/// - Returns: Maximum drawdown value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return calculate(values: returns.valuesArray)
	}
}
