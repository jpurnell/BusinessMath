//
//  uniformCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) for a uniform distribution in the range `[0, 1]`.
///
/// A uniform distribution, also called a rectangular distribution, is a type of probability distribution in which all outcomes are equally likely. The cumulative distribution function for a uniform distribution calculates the probability that a random variable is less than or equal to a given value.
///
/// - Parameter x: The value at which to evaluate the cumulative distribution function. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The cumulative distribution function evaluated at `x`. The return values range from `0` (representing a 0% chance) to `1` (representing a 100% chance).
///
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let x: Double = 0.6
///     let cdf = uniformCDF(x: x)
///     print(cdf)
///
/// Use this function when dealing with uniform distributions, such as for simple random selection processes.
public func uniformCDF<T: Real>(x: T) -> T {
    if x < T(0) {
        return T(0)
    }
    else if x < T(1) {
        return x
    }
    return T(1)
}
