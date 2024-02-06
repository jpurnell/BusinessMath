//
//  probabilityDistributionFunction.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Probability Density Function (PDF) for a normal distribution.
///
/// The normal (or Gaussian) distribution is a continuous probability distribution that has a bell-shaped probability density function, known as the Gaussian function, or informally, the bell curve.
///
/// - Parameters:
///     - x: The point at which to evaluate the function.
///     - mean: The average or central value of the distribution.
///     - stdDev: The standard deviation which measures the amount of variation or dispersion of the set of values.
///
/// - Returns: The probability density at the specified point `x`.
///
/// - Precondition: `stdDev` must be a positive number.
/// - Complexity: O(1), as it uses a constant number of operations.
///
///     let x = 1.0
///     let mean = 0.0
///     let stdDev = 1.0
///     let result = normalPDF(x: x, mean: mean, stdDev: stdDev)
///     print(result)
public func normalPDF<T: Real>(x: T, mean: T = 0, stdDev: T = 1) -> T {
    let sqrt2Pi = T.sqrt(2 * T.pi)
    let xMinusMeanSquared = (x - mean) * (x - mean)
    let stdDevSquaredTimesTwo = 2 * stdDev * stdDev
    let numerator = T.exp(-xMinusMeanSquared / stdDevSquaredTimesTwo)
    return numerator / (sqrt2Pi * stdDev)
}

