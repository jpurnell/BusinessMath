//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

/// Returns the standardized value of a real number.
///
/// This function standardizes the `x` element by subtracting the mean and then dividing the result by the standard deviation.
/// Excel Compatibility: Equivalent of Excel's STANDARDIZE function
///
/// - Parameters:
///   - x: The element to standardize.
///   - mean: The mean or average of the distribution.
///   - stdev: The standard deviation of the distribution.
/// - Returns: The standardized value of `x`.
/// - Precondition: The `stdev` argument must be a non-zero valid real number.
///
///     let result = standardize(x: 7.8, mean: 5.6, stdev: 1.2)
///
public func standardize<T: Real>(x: T, mean: T, stdev: T) -> T {
    return zStatistic(x: x, mean: mean, stdDev: stdev)
}
