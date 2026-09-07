//
//  ConditionalValueAtRisk.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-20.
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
/// print("CVaR₉₅: \(cvar95)") // -0.1 — the mean of the tail at or below VaR₉₅
/// ```
///
/// ## Interpretation
///
/// - **CVaR₉₅ = -10%** on the sample above: eight observations put the 5% quantile
///   at -8.25%, and only the -10% observation lies at or below it
/// - **CVaR is always more extreme than VaR** (CVaR₉₅ <= VaR₉₅ for losses)
/// - CVaR captures tail risk that VaR misses
///
/// ## Example: Portfolio Risk
///
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// let var95 = ValueAtRisk.var95(values: returns)               // -0.1375
/// let cvar95 = ConditionalValueAtRisk.cvar95(values: returns)  // -0.15
///
/// // CVaR tells you: "When losses exceed 5% threshold (VaR),
/// //                  they average 7% (CVaR)"
/// ```
///
/// ## See Also
///
/// - ``ValueAtRisk``
/// - ``TailRisk``
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
		let alpha: T = T(1) - confidenceLevel

		// The threshold is the value-at-risk itself, taken from the library's single
		// empirical quantile — type 7, the same one behind ``Percentiles`` and
		// ``SimulationResults/valueAtRisk(confidenceLevel:)``.
		//
		// This used to count observations instead: `max(0, Int(n·alpha) - 1)`, then
		// average `sorted[0...that]`. Two things were wrong with it. It formed no
		// quantile, so this type and `SimulationResults` returned *different* numbers
		// for the same sample and confidence — agreeing whenever `n·alpha` happened
		// to be an integer and diverging otherwise, which is worse than disagreeing
		// always. And the `max(0, …)` floor over-selects on a small sample: at
		// twenty observations and 99% it averaged the worst 5%, and at ten
		// observations and 95% the worst 10%, in both cases reporting a tail twice
		// the size asked for.
		let threshold: T = quantile(sorted: sorted, p: alpha)

		// Everything at or below the threshold. Inclusive, because the observation
		// sitting exactly on the value-at-risk is part of the loss being described,
		// not the boundary of it.
		let tail = sorted.filter { $0 <= threshold }
		guard !tail.isEmpty else { return threshold }

		let total = tail.reduce(T(0), +)
		return total / T(tail.count)
	}

	/// Calculate CVaR at 95% confidence level (common standard).
	///
	/// - Parameter values: Array of return values.
	/// - Returns: CVaR₉₅ value.
	///
	/// ## Example
	///
	/// ```swift
	/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
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
	/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
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
