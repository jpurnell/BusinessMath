//
//  requiredSampleSize.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the required sample size for a given z-value, standard deviation, sample mean, and population mean.
///
/// This function calculates the minimum sample size necessary for a particular study experiment to be valid.
///
/// - Parameters:
///     - z: The value of the z-score (a measure of how many standard deviations an element is from the mean).
///     - stdDev: The standard deviation of the population.
///     - sampleMean: The calculated mean (average) of the sample data.
///     - populationMean: The mean of the population.
///
/// - Returns: The required sample size as a `Real` number.
///
/// - Precondition: `stdDev` and `populationMean - sampleMean` must be a non-zero number.
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let z = 1.96  // z-score for 95% confidence level
///     let stdDev = 1.2
///     let sampleMean = 4.5
///     let populationMean = 5.0
///     let result = requiredSampleSize(z: z, stdDev: stdDev, sampleMean: sampleMean, populationMean: populationMean)
///     print(result)
///
/// Use this function when you need to calculate how many samples you need to take in order to achieve the desired level of accuracy in your research.
public func requiredSampleSize<T: Real>(z: T, stdDev: T, sampleMean: T, populationMean: T) -> T {
    return (T.pow(z, T(2)) * T.pow(stdDev, T(2)))/T.pow((sampleMean - populationMean), T(2))
}

/// Computes the required sample size for a given confidence interval, standard deviation, sample mean, and population mean.
///
/// This function is typically used during experiment planning to determine how many samples are needed to achieve a desired level of confidence in the results. The calculation first determines the Z-score for the desired confidence level, and then uses this Z-score in the sample size calculation.
///
/// - Parameters:
///     - ci: The desired confidence interval. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - stdDev: The standard deviation of the population.
///     - sampleMean: The mean of the sample.
///     - populationMean: The mean of the population.
///
/// - Returns: The required sample size.
///
/// - Precondition: `ci` must be a value between `0` and `1` (inclusive), and `stdDev` must be a non-negative number.
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let ci = 0.95
///     let stdDev = 1.2
///     let sampleMean = 2.0
///     let populationMean = 1.8
///     let result = requiredSampleSize(ci: ci, stdDev: stdDev, sampleMean: sampleMean, populationMean: populationMean)
///     print(result)
///
/// Use this function when you need to estimate the sample size required to achieve a desired confidence interval for your experiment or survey.
public func requiredSampleSize<T: Real>(ci: T, stdDev: T, sampleMean: T, populationMean: T) -> T where T: BinaryFloatingPoint {
    let z = zScore(ci: ci)
    return requiredSampleSize(z: z, stdDev: stdDev, sampleMean: sampleMean, populationMean: populationMean)
}

/// Computes the required sample size for a given confidence interval, probability and maximum error.
///
/// This function is typically used when planning an experiment or survey to determine how many samples are needed to achieve a desired level of confidence in the results, ensuring that the estimate will be within a certain range of the true population value.
///
/// - Parameters:
///     - ci: The desired confidence interval. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - prob: The assumed proportion in the population.
///     - maxError: The maximum acceptable error.
///     - populationSize: The total number of elements in the observation set
/// - Returns: The required sample size.
///
/// - Precondition: `ci` and `prob` must be a value between `0` and `1` (inclusive), and `maxError` must be a non-negative number.
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let ci = 0.95
///     let prob = 0.5
///     let maxError = 0.05
///     let result = requiredSampleSizeProb(ci: ci, prob: prob, maxError: maxError)
///     print(result)
///
/// Use this function when planning a survey or experiment where it's important to understand population trends.
public func requiredSampleSizeProb<T: Real>(ci: T, prob: T, maxError: T, _ populationSize: T?) -> T where T: BinaryFloatingPoint {
    let z = zScore(ci: ci)
    let sampleSize = (T.pow(z, T(2)) * prob * (T(1) - prob))/(T.pow(maxError, T(2)))
	guard let population = populationSize else { return sampleSize }
	let populationCorrectionNumerator = T(1) + (T.pow(z, T(2)) * prob * (T(1) - prob))
	let populationCorrectionDenominator = (T.pow(maxError, T(2)) * population)
	let finitePopulationCorrection = populationCorrectionNumerator / populationCorrectionDenominator
	return sampleSize / finitePopulationCorrection
}
