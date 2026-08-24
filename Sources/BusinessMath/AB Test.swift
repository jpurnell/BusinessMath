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


/// Computes a single-sample survey size by Cochran's formula. **Not** an A/B test size.
///
/// - Warning: This function's parameters describe a survey — a confidence level, a
///   population size, and a margin of error — and its body is Cochran's finite-population
///   formula. It is missing everything a two-arm power calculation needs: there is no
///   power term, no second arm's variance, and `error` is a margin of error around one
///   proportion rather than a difference between two.
///
///   At 95% confidence, `p = 0.5` and `error = 0.05` it returns **384** per arm, where
///   detecting a 0.50 → 0.55 difference at 80% power needs **1,565** — understated by
///   **4.1x**. A test sized this way fails to reach significance and reads as
///   "no difference."
///
///   Use ``Experiment/sampleSizePerArm(power:alpha:tails:)``.
///
/// - Parameters:
/// 	- ci: The level of confidence of a sample is expressed as a percentage and describes the extent to which you can be sure it is representative of the target population; that is, how frequently the true percentage of the population who would select a response lies within the confidence interval. For example, if you have a confidence level of 90%, if you were to conduct the survey 100 times, the survey would yield the exact same results 90 times out of those 100 times.
/// 	- p: The accuracy of the research outputs also varies according to the percentage of the sample that chooses a given response. If 98% of the population select "Yes" and 2% select "No," there is a low chance of error. However, if 35% of the population select "Yes" and 65% select "No", there is a higher chance an error will be made, regardless of the sample size. When selecting the sample size required for a given level of accuracy, researchers should use the worst-case percentage; i.e., 50%.
/// 	- n: Population Size: The population size is the total number of people in the target population. For example, if you were performing research that was based on the people living in the UK, the full population would be approximately 66 million. Likewise, if you were conducting research on an organization, the total size of the population would be the number of employees who work for that organization.
/// 	e: Margin of Error: Margin of error is also measured in percentage terms. It indicates the extent to which the outputs of the sample population are reflective of the overall population. The lower the margin of error, the nearer the researcher is to having an accurate response at a given confidence level.
@available(*, deprecated, message: "Use Experiment.sampleSizePerArm(power:alpha:tails:) instead. This is Cochran's single-sample survey formula, not a two-arm power calculation: it has no power term, no second arm's variance, and no minimum detectable effect. It understates the sample size an A/B test needs by roughly 4.1x.")
public func sampleSize<T: Real>(ci: T, proportion p: T, n: T, error: T ) -> T where T: BinaryFloatingPoint {
	let z = zScore(ci: ci)
	let z2 = T.pow(z, 2)
	let error2 = T.pow(error, 2)
	let pq = p * (T(1) - p)
	let num = (z2 * pq) / error2
	let den = T(1) + (z2 * pq) / (error2 * n)
	return num / den
}
