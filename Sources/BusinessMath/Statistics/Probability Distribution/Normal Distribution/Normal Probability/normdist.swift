//
//  normDist.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

/// Returns the normal distribution function value for a given `x`, mean, and standard deviation.
///
/// This function calculates the value of the normal distribution function, or the cumulative distribution function (CDF), for a given `x`, mean, and standard deviation.
///
/// - Parameters:
///   - x: The point at which the function value is evaluated.
///   - mean: The mean or average of the distribution.
///   - stdev: The standard deviation of the distribution.
/// - Returns: The value of the normal distribution function.
/// - Precondition: The `stdev` argument must be a non-zero valid real number.
///
///     let result = normDist(x: 7.8, mean: 5.6, stdev: 1.2)
public func normDist<T: Real>(x: T, mean: T, stdev: T) -> T {
    return normalCDF(x: x, mean: mean, stdDev: stdev)
}
