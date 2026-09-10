//
//  AB Test.swift
//
//
//  Created by Justin Purnell on 6/11/24.
//

import Foundation
import Numerics

/// Returns `normSDist(|z|)` for a two-proportion comparison — **not** a p-value.
///
/// - Warning: This function does not compute what its name says. It returns the standard
///   normal CDF of the absolute z statistic, which is `1 - oneSidedP`. Because the z
///   statistic is made absolute first, **the result is never below 0.5**, so the
///   `p < 0.05` test this documentation used to prescribe can never be true.
///
///   For the worked example below the function returns `0.950526`; the documentation
///   previously claimed `0.043`; and the true two-sided p-value is `0.098948`, which is
///   **not** significant at the 95% level. Three different numbers.
///
///   Use ``Experiment/analyze(_:alpha:)`` instead. It returns a genuine two-sided
///   p-value together with the confidence interval on the lift, which is the figure that
///   answers whether a result is worth acting on.
///
/// - Parameters:
///   - obsA: The number of observations (trials) for variant A.
///   - convA: The number of successful conversions for variant A.
///   - obsB: The number of observations (trials) for variant B.
///   - convB: The number of successful conversions for variant B.
///
/// - Returns: `normSDist(|z|)`, in `[0.5, 1)`. To recover the two-sided p-value from it,
///   compute `2 * (1 - result)`.
///
/// - Precondition: `convA` must be less than or equal to `obsA`, and `convB` must be less
///   than or equal to `obsB`. Neither is checked.
/// - Complexity: O(1), constant time complexity.
///
/// ## Usage Example
/// ```swift
/// let legacy: Double = pValue(obsA: 1000, convA: 120, obsB: 1000, convB: 145)
/// // legacy == 0.950526 — the complement of a one-sided p-value
///
/// let twoSided = 2.0 * (1.0 - legacy)
/// // twoSided == 0.098948 — the actual p-value, and not significant at 0.05
/// ```
///
/// - SeeAlso: ``Experiment/analyze(_:alpha:)``
@available(*, deprecated, message: "Use Experiment.analyze(_:alpha:) instead. This function returns normSDist(|z|) — the complement of a one-sided p-value — not a p-value. It is always >= 0.5, so a `p < 0.05` test can never be true. Recover the two-sided p-value with 2 * (1 - result).")
public func pValue<T: Real>(obsA: Int, convA: Int, obsB: Int, convB: Int) -> T {
	let conversionRateA: T = T(convA) / T(obsA)
	let conversionRateB: T = T(convB) / T(obsB)
	
	let standardErrorA = standardErrorProbabilistic(conversionRateA, observations: obsA)
	let standardErrorB = standardErrorProbabilistic(conversionRateB, observations: obsB)

	let zScoreNum = (conversionRateA - conversionRateB)
	let zScoreDen = T.sqrt(T.pow(standardErrorA, 2) + T.pow(standardErrorB, 2))
	
	let zScore = abs(zScoreNum / zScoreDen)
	let pValue = normSDist(zScore: zScore)
	return pValue
}
