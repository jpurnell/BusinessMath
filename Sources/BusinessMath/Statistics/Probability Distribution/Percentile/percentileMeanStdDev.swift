//
//  percentileMeanStdDev.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the percentile for a given `x` value in a normal distribution.
///
/// This function first calculate the z-score, or the standard score, representing the number of standard deviations an element is from the mean. It then computes and returns the percentile of the z-score in the standard normal distribution.
///
/// - Parameters:
///     - x: The given value for which to find the percentile and should conform to the `Real` protocol.
///     - mean: The average of all the points in the distribution.
///     - stdDev: The standard deviation of the distribution.
///
/// - Returns: The percentile of `x` in a normal distribution as a `Real` number.
///
/// - Precondition: `stdDev` must be positive.
///
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let x = 5.0
///     let mean = 3.0
///     let stdDev = 1.0
///     let result = percentile(x: x, mean: mean, stdDev: stdDev)
///     print(result)
public func percentile<T: Real>(x: T, mean: T, stdDev: T) -> T {
    return percentile(zScore: zStatistic(x: x, mean: mean, stdDev: stdDev))
}
