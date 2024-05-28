//
//  tStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the t-statistic for a given value, mean, and standard error.
///
/// The t-statistic is used in hypothesis testing to determine if a sample mean significantly differs from the population mean.
/// It represents the number of standard deviations that a sample mean is from the population mean.
///
/// - Parameters:
///   - x: The observed sample value.
///   - mean: The population mean. Defaults to `0`.
///   - stdErr: The standard error of the mean. Defaults to `1`.
/// - Returns: The t-statistic, defined as the standardized difference between the sample value and the population mean, scaled by the standard error.
///
/// - Note: The function follows the formula for the t-statistic:
///   \[ t = \frac{x - \mu}{\text{stdErr}} \]
///   where \( x \) is the observed sample value, \( \mu \) is the population mean, and `stdErr` is the standard error.
///
/// - Example:
///   ```swift
///   let observedValue: Double = 1.5
///   let populationMean: Double = 1.0
///   let standardError: Double = 0.5
///   let tStat = tStatistic(x: observedValue, mean: populationMean, stdErr: standardError)
///   // tStat should be the t-statistic for the given values

public func tStatistic<T: Real>(x: T, mean: T = T(0), stdErr: T = T(1)) -> T {
    return ((x - mean) / stdErr)
}
