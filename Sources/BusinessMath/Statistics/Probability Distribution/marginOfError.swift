//
//  marginOfError.swift
//
//
//  Created by Justin Purnell on 6/11/24.
//

import Foundation
import Numerics

/// Computes the Margin of Error for a sample of a larger population for a given confidence level. The majority of surveys that are conducted for research purposes are based on information that is collected from a sample population as opposed to the full population (a census). As the sample is only representative of the full population, it is likely that some error will occur, not in terms of the calculation, but in terms of the sampling. That is, a sampling error will emerge because the researchers did not include everyone that exists within a given population. The MOE measures the maximum amount by which the sample results may differ from the full population. As most responses to survey questions can be presented in terms of percentages, it makes sense that the MOE is also presented as a percentage.
///
/// - Parameters:
///     - prob: The level of confidence required.
///     - sampleProportion: proportion of the sample
///     - sampleSize: The number of observations made
///     - totalPopulation: The total population size
///
/// - Returns: The standard error as a `Real` number.

public func marginOfError<T: Real>(_ prob: T, sampleProportion p: T, sampleSize n: Int, totalPopulation N: Int) -> T {
	let z = zScore(ci: prob)
	let num = z * T.sqrt(p * (T(1) - p))
	let x = ((T(N) - T(1)) * T(n)) / (T(N) - T(n))
	let den = T.sqrt(x)
	return num / den
}

