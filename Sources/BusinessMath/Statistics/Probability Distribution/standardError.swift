//
//  standardError.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the standard error given the standard deviation and the number of observations.
///
/// The standard error (SE) is a statistical term that measures the accuracy for a sample mean. It indicates the standard deviation of the sampling distribution of a statistic, most commonly of the mean.
///
/// - Parameters:
///     - stdDev: The standard deviation of the sample. It adheres to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - n: The number of observations in the sample.
///
/// - Returns: The standard error as a `Real` number.
///
/// - Precondition: `n` must be a positive integer and `stdDev` must be a non-negative number.
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let stdDev = 1.5
///     let observations = 100
///     let result = standardError(stdDev, observations: observations)
///     print(result)
///
/// Use this function when you need to estimate the variability or spread of a sampling distribution.
public func standardError<T: Real>(_ stdDev: T, observations n: Int) -> T {
    return stdDev / T.sqrt(T(n))
}

/// Computes the standard error based on an array of samples.
///
/// The standard error (SE) is a statistical term that measures the accuracy for a sample mean. It indicates the standard deviation of the sampling distribution of a statistic, most commonly of the mean.
///
/// - Parameter x: An array of values representing the sample. Each element should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The standard error for the given sample as a `Real` number.
///
/// - Precondition: `x` should not be empty.
/// - Complexity: O(n), where n is the number of elements in the `x` array.
///
///     let x = [1.0, 2.0, 3.0, 4.0, 5.0]
///     let result = standardError(x)
///     print(result)
///
/// Use this function when you need to estimate the variability or spread of sampling distribution based on sample data.
public func standardError<T: Real>(_ x: [T]) -> T {
    return standardError(stdDev(x, .sample), observations: x.count)
}
