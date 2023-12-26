//
//  zStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Returns the Z-Score of a real number.
///
/// This function calculates the Z-Score (also known as a standard score), which quantifies how many standard deviations an element `x` is from the mean. The result is used in statistics to compare the results of different surveys or experiments that have different means and standard deviations.
///
/// - Parameters:
///   - x: The element to compute the Z-Score of.
///   - mean: The mean or average of the distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the distribution. Defaults to `1`.
/// - Returns: The Z-Score of `x`.
/// - Precondition: The `stdDev` argument must be a non-zero valid real number.
///
///     let z = zStatistic(x: 7.8, mean: 5.6, stdDev: 1.2)
public func zStatistic<T: Real>(x: T, mean: T = T(0), stdDev: T = T(1)) -> T {
    return ((x - mean) / stdDev)
}

/// Returns the Z-Score of a real number.
///
/// This function calculates the Z-Score (also known as a standard score), which quantifies how many standard deviations an element `x` is from the mean. The result is used in statistics to compare the results of different surveys or experiments that have different means and standard deviations.
///
/// - Parameters:
///   - x: The element to compute the Z-Score of.
///   - mean: The mean or average of the distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the distribution. Defaults to `1`.
/// - Returns: The Z-Score of `x`.
/// - Precondition: The `stdDev` argument must be a non-zero valid real number.
///
///     let z = zScore(x: 7.8, mean: 5.6, stdDev: 1.2)
public func zScore<T: Real>(x: T, mean: T = T(0), stdDev: T = T(1)) -> T {
    return zStatistic(x: x, mean: mean, stdDev: stdDev)
}
