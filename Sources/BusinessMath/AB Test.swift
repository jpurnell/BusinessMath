//
//  AB Test.swift
//
//
//  Created by Justin Purnell on 6/11/24.
//

import Foundation
import Numerics

/// Computes the p-value for an A/B test comparing conversion rates between two variants.
///
/// Use this function to determine if the difference in conversion rates between variant A and variant B
/// is statistically significant. The function performs a two-proportion z-test and returns the p-value.
///
/// - Parameters:
///   - obsA: The number of observations (trials) for variant A.
///   - convA: The number of successful conversions for variant A.
///   - obsB: The number of observations (trials) for variant B.
///   - convB: The number of successful conversions for variant B.
///
/// - Returns: The p-value as a value between 0 and 1. Lower values indicate stronger evidence
///   that the conversion rates are different:
///   - p < 0.05: Statistically significant difference (95% confidence)
///   - p < 0.01: Highly significant difference (99% confidence)
///   - p ≥ 0.05: No significant difference detected
///
/// - Precondition: `convA` must be less than or equal to `obsA`, and `convB` must be less than or equal to `obsB`.
/// - Complexity: O(1), constant time complexity.
///
/// ## Usage Example
/// ```swift
/// // Test two landing page variants
/// let observationsA = 1000
/// let conversionsA = 120  // 12% conversion rate
///
/// let observationsB = 1000
/// let conversionsB = 145  // 14.5% conversion rate
///
/// let p: Double = pValue(obsA: observationsA, convA: conversionsA,
///                        obsB: observationsB, convB: conversionsB)
/// print("p-value: \(p)")
/// // Output: p-value: 0.043 (statistically significant at 95% level)
/// ```
///
/// ## Statistical Background
/// The function calculates:
/// 1. Conversion rates for each variant: pₐ = convA/obsA, pᵦ = convB/obsB
/// 2. Standard errors for each proportion
/// 3. Z-score: z = (pₐ - pᵦ) / √(SE²ₐ + SE²ᵦ)
/// 4. P-value from the standard normal distribution
///
/// - SeeAlso: ``sampleSize(ci:proportion:n:error:)``
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


/// Computes the minimum number of observations for each variant of an A/B test to determine the significance of that test.
///
/// - Parameters:
/// 	- ci: The level of confidence of a sample is expressed as a percentage and describes the extent to which you can be sure it is representative of the target population; that is, how frequently the true percentage of the population who would select a response lies within the confidence interval. For example, if you have a confidence level of 90%, if you were to conduct the survey 100 times, the survey would yield the exact same results 90 times out of those 100 times.
/// 	- p: The accuracy of the research outputs also varies according to the percentage of the sample that chooses a given response. If 98% of the population select "Yes" and 2% select "No," there is a low chance of error. However, if 35% of the population select "Yes" and 65% select "No", there is a higher chance an error will be made, regardless of the sample size. When selecting the sample size required for a given level of accuracy, researchers should use the worst-case percentage; i.e., 50%.
/// 	- n: Population Size: The population size is the total number of people in the target population. For example, if you were performing research that was based on the people living in the UK, the full population would be approximately 66 million. Likewise, if you were conducting research on an organization, the total size of the population would be the number of employees who work for that organization.
/// 	e: Margin of Error: Margin of error is also measured in percentage terms. It indicates the extent to which the outputs of the sample population are reflective of the overall population. The lower the margin of error, the nearer the researcher is to having an accurate response at a given confidence level.
public func sampleSize<T: Real>(ci: T, proportion p: T, n: T, error: T ) -> T where T: BinaryFloatingPoint {
	let z = zScore(ci: ci)
	let z2 = T.pow(z, 2)
	let error2 = T.pow(error, 2)
	let pq = p * (T(1) - p)
	let num = (z2 * pq) / error2
	let den = T(1) + (z2 * pq) / (error2 * n)
	return num / den
}
