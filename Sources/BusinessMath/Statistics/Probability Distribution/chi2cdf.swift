//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) for a chi-squared distribution.
///
/// The chi-squared distribution is a probability distribution most commonly used in hypothesis testing, and is related to standard normal distribution. The cumulative distribution function for a random variable is defined as the probability that the variable takes a value less than or equal to a certain value.
///
/// - Parameters:
///     - x: The value at which to evaluate the cumulative distribution function.
///     - dF: The degrees of freedom of the chi-squared distribution.
///
/// - Returns: The cumulative distribution function evaluated at `x` for a chi-squared distribution with `dF` degrees of freedom.
///
/// - Precondition: `x` must be a non-negative value, and `dF` must be a positive integer.
/// - Complexity: O(1) since it uses a constant number of operations.
///
///First import `Foundation`
///    import Foundation
///    let x = 10.0
///    let dF = 3
///    let result = chi2cdf(x: x, dF: dF)
///    print(result)
///
/// Use this function when you need to find the probability of a random variable from a chi-squared distribution being less than or equal to `x`.
public func chi2cdf<T: Real>(x: T, dF: Int) -> T {
    return 1 - chi2pdf(x: x, dF: dF)
}
