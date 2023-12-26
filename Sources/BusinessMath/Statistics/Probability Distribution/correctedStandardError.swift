//
//  correctedStandardError.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the corrected standard error for given samples and population size.
///
/// The standard error is responsible to measure the statistical accuracy of an estimate or a mean. If the sample count is at least 5% of the population, the function returns the standard error, otherwise, it corrects the standard error based on the population size.
///
/// - Parameters:
///     - x: The array of samples. Each samples should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - population: The size of the population.
///
/// - Returns: The corrected standard error.
///
/// - Precondition: `population` must be a positive integer is greater than the count of `x`, and `x` should not be empty.
/// - Complexity: O(n), where n is the count of `x`.
///
///     let x = [1.0, 2.0, 3.0, 4.0, 5.0]
///     let population = 100
///     let result = correctedStdErr(x, population: population)
///     print(result)
///
/// Use this function when you need to estimate the standard error of your sample mean, correcting for cases where your sample size might be a significant fraction of the total population.
public func correctedStdErr<T: Real>(_ x: [T], population: Int) -> T {
    let percentage = T(x.count / population)
    if percentage >= T(Int(5) / Int(100)) { return standardError(x) } else {
        let num = population - x.count
        let den = population - 1
        return standardError(x) * (T.sqrt(T(num/den)))
    }
}
