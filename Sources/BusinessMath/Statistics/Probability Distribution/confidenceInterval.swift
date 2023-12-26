//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the confidence interval for a population parameter.
///
/// The confidence interval is a range of values, derived from a given sample, that is likely to contain an unknown population parameter. The width of the confidence interval gives us some idea about how uncertain we are about the unknown parameter.
///
/// - Parameters:
///     - mean: The sample mean.
///     - stdDev: The standard deviation of the sample.
///     - z: The value of the Z statistic for the desired confidence level.
///     - popSize: The size of the population.
///
/// - Returns: A tuple representing the lower and upper bounds of the confidence interval.
///
/// - Precondition: `popSize` must be a positive integer and `stdDev` must be a non-negative number.
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let mean = 3.5
///     let stdDev = 1.2
///     let z = 1.96  // Z score for 95% confidence interval
///     let popSize = 100
///     let result = confidenceInterval(mean: mean, stdDev: stdDev, z: z, popSize: popSize)
///     print(result)  // Prints something like "(low: 2.509, high: 4.491)"
///
/// Use this function when you need to compute uncertainty of population parameter estimates.
public func confidenceInterval<T: Real>(mean: T, stdDev: T, z: T, popSize: Int) -> (low: T, high: T) {
    return (low: mean - (z * stdDev/T.sqrt(T(popSize))), high: mean +  (z * stdDev/T.sqrt(T(popSize))))
}

/// Computes the confidence interval for given values and confidence level.
///
/// The confidence interval is a range of values, derived from a given sample, that is likely to contain an unknown population parameter.
///
/// - Parameters:
///     - ci: The confidence level. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - values: An array of the sample data. Each element should adhere to the `Real` type.
///
/// - Returns: A tuple representing the lower (`low`) and upper (`high`) bounds of the confidence interval.
///
/// - Precondition: `ci` must be a value between `0` and `1` (inclusive), and `values` should not be empty.
/// - Complexity: O(n), where n is the number of elements in the `values` array.
///
///     let ci = 0.95  // represents 95% confidence level
///     let values = [1.0, 2.0, 3.0, 4.0, 5.0]
///     let result = confidenceInterval(ci: ci, values: values)
///     print(result)  // Prints "(low: x, high: y)"
///
/// Use this function when you need to estimate a population parameter based on your sample data.
public func confidenceInterval<T: Real>(ci: T, values: [T]) -> (low: T, high: T) {
    // Range in which we can expect the population mean to be found with x% confidence
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    
    let lowValue = inverseNormalCDF(p: lowProb, mean: mean(values), stdDev: stdDev(values))
    let highValue = inverseNormalCDF(p: highProb, mean: mean(values), stdDev: stdDev(values))
    
    return (lowValue, highValue)
}

//MARK: - Excel Compatibility – CONFIDENCE(alpha, stdev, sample size)
/// Computes the confidence interval for a population mean.
///
/// The function uses standard deviation, sample size, and significance level (`alpha`) to construct a confidence interval around the mean (average) value.
/// Excel Compatibility – CONFIDENCE(alpha, stdev, sample size)
///
/// - Parameters:
///     - alpha: The significance level, i.e., the probability of rejecting the null hypothesis if it is true.
///     - stdev: The standard deviation of the population. It should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - sampleSize: The size of the sample drawn from the population for which a confidence interval will be computed.
///
/// - Returns: A tuple where `low` represents the lower bound for the confidence interval and `high` - the upper bound.
///
/// - Precondition: `alpha` must between 0 and 1 (inclusive), `stdev` must be a non-negative number, and `sampleSize` must be a positive integer.
/// - Complexity: O(1) since it uses a constant number of operations.
///
///     let alpha = 0.05
///     let stdev = 1.2
///     let sampleSize = 100
///     let result = confidence(alpha: alpha, stdev: stdev, sampleSize: sampleSize)
///     print(result)  // Prints "(low: x, high: y)"
///
/// Use this function to estimate the bounds within which the population mean lies with a certain degree of confidence.
public func confidence<T: Real>(alpha: T, stdev: T, sampleSize: Int) -> (low: T, high: T) {
    let z = normSInv(probability: (T(1) - (alpha / T(2))))
    return confidenceInterval(mean: 0, stdDev: stdev, z: z, popSize: sampleSize)
}
