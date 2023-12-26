//
//  normInv.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

/// Computes the inverse of the normal cumulative distribution function (CDF) for a given probability, mean, and standard deviation.
///
/// This function uses the inverse of the normal cumulative distribution function (`inverseNormalCDF`) to determine the quantile or inverse cumulative distribution function for the normal distribution given a certain probability.
///
/// - Parameters:
///   - x: The probability for which to compute the inverse CDF.
///   - mean: The mean or average of the normal distribution.
///   - stdev: The standard deviation of the normal distribution.
/// - Returns: The value of the inverse CDF for the normal distribution at the given probability, mean, and standard deviation.
/// - Precondition: The `stdev` argument must be a non-zero valid real number, and `x` should be a valid real number between 0 and 1.
///
///     let result = normInv(probability: 0.95, mean: 0, stdev: 1)
public func normInv<T: Real>(probability x: T, mean: T, stdev: T) -> T {
    return inverseNormalCDF(p: x, mean: mean, stdDev: stdev)
}

