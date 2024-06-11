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
