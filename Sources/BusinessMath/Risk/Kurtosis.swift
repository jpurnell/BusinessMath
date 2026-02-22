//
//  Kurtosis.swift
//  BusinessMath
//
//  Created by Claude on 2026-02-20.
//

import Foundation
import Numerics

/// Kurtosis calculator for distribution tail thickness (delegates to canonical implementation).
///
/// Kurtosis (excess kurtosis) measures how fat or thin the tails of a distribution are
/// compared to a normal distribution. It tells you about the probability of extreme events.
///
/// This type provides a risk-focused API that delegates to the canonical
/// ``kurtosisP(_:)`` implementation in `Statistics/Descriptors`.
///
/// ## Usage
///
/// ```swift
/// let returns = [-0.20, 0.00, 0.00, 0.00, 0.00, 0.20]  // Fat tails
/// let kurt = Kurtosis.calculate(values: returns)
/// print("Kurtosis: \(kurt)") // Positive value (leptokurtic)
/// ```
///
/// ## Interpretation
///
/// - **Kurtosis = 0**: Normal distribution (mesokurtic)
/// - **Kurtosis > 0**: Fat tails (leptokurtic) - more extreme events than normal
/// - **Kurtosis < 0**: Thin tails (platykurtic) - fewer extreme events than normal
///
/// ## Example: Tail Thickness
///
/// ```swift
/// // Fat tails: Sharp peak + extreme outliers (kurtosis > 0)
/// let crashRisk = [0.00, 0.00, 0.01, -0.25, 0.00, 0.00, 0.00, 0.30]
/// let kurt1 = Kurtosis.calculate(values: crashRisk)  // > 0
///
/// // Uniform distribution: Thin tails (kurtosis < 0)
/// let uniform = [-0.05, -0.04, -0.03, -0.02, -0.01, 0.00, 0.01, 0.02]
/// let kurt2 = Kurtosis.calculate(values: uniform)  // < 0
/// ```
///
/// ## Financial Implications
///
/// - **High kurtosis**: "Black swan" events more likely than normal distribution suggests
/// - **Low kurtosis**: Returns more uniform, less extreme variability
/// - Most financial assets have positive excess kurtosis (fat tails)
///
/// ## See Also
///
/// - ``kurtosisP(_:)`` - Canonical population kurtosis implementation
/// - ``Skewness`` - Measures distribution asymmetry
/// - ``TailRisk`` - Measures severity beyond VaR threshold
/// - ``ConditionalValueAtRisk`` - Average loss in extreme tail
public struct Kurtosis {

	/// Calculate excess kurtosis of a return distribution (delegates to canonical ``kurtosisP(_:)``).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: Excess kurtosis value (positive = fat tails, negative = thin tails).
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [-0.10, -0.02, 0.01, 0.03, 0.15]
	/// let kurt = Kurtosis.calculate(values: returns)
	/// ```
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		values: [T]
	) -> T {
		guard !values.isEmpty else { return T(0) }

		// Delegate to canonical population kurtosis implementation
		return kurtosisP(values)
	}

	// MARK: - TimeSeries Convenience Methods

	/// Calculate kurtosis from a time series (convenience method).
	///
	/// - Parameter returns: Time series of return values.
	/// - Returns: Excess kurtosis value.
	public static func calculate<T: Real & Sendable & BinaryFloatingPoint>(
		returns: TimeSeries<T>
	) -> T {
		return calculate(values: returns.valuesArray)
	}
}
