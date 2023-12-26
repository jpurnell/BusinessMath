//
//  pValueStudent.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the p-value for a given t-value and degrees of freedom using the Student's t-distribution.
///
/// The p-value is a statistical metric that helps scientists determine whether or not their hypotheses are correct.
/// It represents the probability that the results of your test happened at random. If the p-value is low enough,
/// we reject the null hypothesis and accept the alternative hypothesis.
///
/// - Parameters:
///     - tValue: The calculated t-value for which to compute the p-value.
///               It should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a
///               common API for all types that can represent real numbers).
///     - dFr: The degrees of freedom for the statistical test.
///
/// - Returns: The p-value (a `Real` number) representing the statistical significance of the test.
///
/// - Precondition: `dFr` should be a positive number.
/// - Complexity: O(1), as it uses a constant number of operations.
///
///     let tValue = 1.932
///     let degreeOfFreedom = 27.0
///     let result = pValueStudent(tValue, dFr: degreeOfFreedom)
///     print(result)
///
/// Use this function when you need to compute the p-value using Student's t-distribution in order to determine the
/// significance of your results.

public func pValueStudent<T: Real>(_ tValue: T, dFr: T) -> T {
    let rhoTop = T.gamma((dFr + 1) / T(2))
    let rhoBot = T.sqrt(dFr * T.pi) * T.gamma(dFr / T(2))
    let left = rhoTop / rhoBot
    let center = (1 + ((tValue * tValue)/dFr))
    let centEx = -1 * ((dFr + 1) / 2)
    let right = T.pow(center, centEx)
    let pValueStudent = left * right
    return pValueStudent
}
