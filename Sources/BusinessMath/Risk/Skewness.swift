//
//  Skewness.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Skewness calculator for distribution asymmetry (delegates to canonical implementation).
///
/// Skewness measures the asymmetry of a return distribution. It tells you whether
/// returns are symmetric (normal distribution) or skewed left (crash risk) or
/// right (lottery-like upside).
///
/// This type provides a risk-focused API that delegates to the canonical
/// ``skewP(_:)`` implementation in `Statistics/Descriptors`.
///
/// ## Usage
///
/// ```swift
/// let returns = [0.01, 0.02, 0.03, 0.05, 0.10, 0.15]  // Right-skewed
/// let skew = Skewness.calculate(values: returns)
/// print("Skewness: \(skew)") // Positive value
/// ```
///
/// ## Interpretation
///
/// - **Skewness = 0**: Symmetric distribution (normal)
/// - **Skewness > 0**: Right-skewed (long right tail, few large gains)
/// - **Skewness < 0**: Left-skewed (long left tail, few large losses/crash risk)
///
/// ## Example: Return Patterns
///
/// ```swift
/// // Positive skew: Small consistent losses, occasional big win (lottery)
/// let lotteryReturns = [-0.01, -0.01, -0.01, -0.01, 0.20]
/// let skew1 = Skewness.calculate(values: lotteryReturns)  // > 0
///
/// // Negative skew: Small consistent gains, occasional big loss (crash)
/// let crashRiskReturns = [0.01, 0.01, 0.01, 0.01, -0.20]
/// let skew2 = Skewness.calculate(values: crashRiskReturns)  // < 0
/// ```
///
/// ## See Also
///
/// - ``skewP(_:)`` - Canonical population skewness implementation
/// - ``Kurtosis`` - Measures tail thickness (fat tails vs thin tails)
/// - ``SortinoRatio`` - Prefers positive skew (limited downside)
public struct Skewness {

	/// Calculate skewness of a return distribution (delegates to canonical ``skewP(_:)``).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: Skewness value (positive = right-skewed, negative = left-skewed).
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [-0.05, -0.02, 0.01, 0.03, 0.08]
	/// let skew = Skewness.calculate(values: returns)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		guard !values.isEmpty else { return T(0) }

		// Delegate to canonical population skewness implementation
		return skewP(values)
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate skewness from a time series (convenience method).
	///
	/// - Parameter returns: Time series of return values.
	/// - Returns: Skewness value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return calculate(values: returns.valuesArray)
	}
}
