//
//  Skewness.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
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
/// - **Skewness = `nan`**: No answer — the sample is empty. Distinct from `0`, which is
///   the *claim* that the distribution is symmetric.
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
/// - ``skewP(_:)``
/// - ``Kurtosis``
/// - ``SortinoRatio``
public struct Skewness {

	/// Calculate skewness of a return distribution (delegates to canonical ``skewP(_:)``).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: Skewness value (positive = right-skewed, negative = left-skewed), or
	///   `nan` for a sample with no observations to be skewed.
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
		// This guard used to return `T(0)`, which is the same shape of mistake as the one
		// in `Kurtosis`: skewness of zero is not "no answer", it is the claim that the
		// return distribution is *perfectly symmetric* — no crash tail, no lottery tail.
		// A caller screening for left skew read "symmetric, nothing to see" from a sample
		// with nothing in it.
		//
		// Unlike `Kurtosis`, the guard is kept rather than deleted, because `skewP` has no
		// empty-sample guard of its own: it reaches `nan` only through `(1/n) * x` evaluating
		// as `infinity * 0`, which is the right answer arrived at by accident. Stating it
		// here means this type's contract does not depend on that arithmetic surviving.
		guard !values.isEmpty else { return T.nan }

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
