//
//  chi2pdf.swift
//  
//
//  Created by Justin Purnell on 6/11/22.
//

import Foundation
import Numerics

/// Computes the probability density function (PDF) for a chi-squared distribution.
///
/// A chi-squared distribution is a probability distribution most commonly used in hypothesis testing. The distribution has a parameter known as degrees of freedom. The probability density function for a random variable gives the probability that the variable is exactly equal to some value.
///
/// - Parameters:
///     - x: The value at which to evaluate the probability density function.
///     - dF: The degrees of freedom of the chi-squared distribution.
///
/// - Returns: The probability density function evaluated at `x` for a chi-squared distribution with `dF` degrees of freedom.
///
/// - Precondition: `x` must be a non-negative value, and `dF` must be a positive integer.
/// - Complexity: O(n), where n is the number of operations performed by the loop.
///
///     import Foundation
///     let x = 10.0
///     let dF = 3
///     let result = chi2pdf(x: x, dF: dF)
///     print(result)
///
/// Use this function when you need to find the probability of a random variable from a chi-squared distribution being exactly equal to `x`.
public func chi2pdf<T: Real>(x: T, dF: Int) -> T {
    var returnValue: T = 0
    guard x != 0 else {
        return T(0) }
    let limitHigh = ("\(x * T(1000))" as NSString).integerValue
    
    let limit = max(limitHigh, 1)
    if limit == 1 { return T(0) }
    for i in 1...limit {
        let x: T = T(i)/1000
        let dF = T(dF)

        let topLeft = T.pow(x, ((dF - 2) / 2))
        let topRight = 1 / T.exp(x / 2)
        let bottomLeft = T.pow(2, (dF / 2))
        let bottomRight = T.gamma(dF / 2)

        let top  = topLeft * topRight
        let bottom = bottomLeft * bottomRight

        returnValue += top / bottom
    }
        return returnValue / T(1000)
}
