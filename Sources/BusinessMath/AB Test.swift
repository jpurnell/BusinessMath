//
//  AB Test.swift
//
//
//  Created by Justin Purnell on 6/11/24.
//

import Foundation
import Numerics

	/// Computes the p-Value for an A/B Test. A value below 0.9 is unlikely to be statistically significant, a value between 0.9 and 0.95 is unlikely to be statistically significant, and a value over 0.95 is statistically significant.
	///
	/// - Parameters:
	///     - obsA: The number of tests of type A.
	///     - convA: The number of successful conversions from test A.
	///     - obsB: The number of tests of type B.
	///     - convB: The number of successful conversions from test B.
	///
	/// - Returns: The pValue as a `Double` number.
	///
	/// - Precondition: `convA` and `convB` must be a less than `obsA` and `obsB`.
	/// - Complexity: O(1), constant time complexity.
	///
	
func pValue<T: Real>(obsA: Int, convA: Int, obsB: Int, convB: Int) -> T {
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
func sampleSize<T: Real>(ci: T, proportion p: T, n: T, error: T ) -> T {
	let z = zScore(ci: ci)
	let num = ((T.pow(z, 2) * p * (T(1) - p)) / T.pow(error, 2))
	let den = (T(1) + (T.pow(z, 2) * p * (T(1) - p)) / (T.pow(error, 2) * n))
	return num / den
}
