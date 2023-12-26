//
//  normalCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// Normal Cumulative Distribution public function
/// Computes the Cumulative Distribution Function (CDF) for a normal distribution.
///
/// This function calculates the CDF, or the probability that a random variable X from the distribution is less than or equal to `x`, with a configurable mean and standard deviation.
///
/// - Parameters:
///   - x: The point at which the function value is evaluated.
///   - mean: The mean or average of the distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the distribution. Defaults to `1`.
/// - Returns: The CDF for the normal distribution at `x`.
/// - Precondition: The `stdDev` argument must be a non-zero valid real number.
///
///     let result = normalCDF(x: 7.8, mean: 5.6, stdDev: 1.2)
public func normalCDF<T: Real>(x: T, mean: T = 0, stdDev: T = 1) -> T {
    return (T(1) + T.erf((x - mean) / T.sqrt(2) / stdDev)) / T(2)
}
