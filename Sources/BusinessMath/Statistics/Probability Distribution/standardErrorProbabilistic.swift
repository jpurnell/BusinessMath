//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the standard error for a given probability and number of observations.
///
/// Standard error is used when an approximation of the standard deviation of a statistical population where the sample size is small. The formula utilized in this function is the square root of `(prob * (1 - prob) / n)`.
///
/// - Parameters:
///     - prob: The probability to compute the standard error for. It should adhere to the `Real` type.
///     - n: The number of observations.
///
/// - Returns: The standard error as a `Real` number.
///
/// - Precondition: `prob` must be a value between `0` and `1` (inclusive), and `n` must be a positive integer.
/// - Complexity: O(1), constant time complexity.
///
///     let prob = 0.5
///     let observations = 100
///     let result = standardErrorProbabilistic(prob, observations: observations)
///     print(result)
///
/// Use this function when you need to estimate the standard error of a proportion in a population based on a probability and the number of observations.
public func standardErrorProbabilistic<T: Real>(_ prob: T, observations n: Int) -> T {
    if prob > T(1) { return T(0) } else {
        return T.sqrt(prob * (1 - prob) / T(n))
    }
}

/// Computes the standard error for a given probability and observations.
///
/// The standard error is a statistical term that measures the accuracy with which a sample represents a population.
///
/// - Parameters:
///     - prob: The probability of the event. It should adhere to the `Real` protocol, a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers.
///     - obs: The number of observed events.
///     - total: The total number of observations.
///
/// - Returns: The standard error for the given parameters.
///
/// - Precondition: `prob` must be a value between `0` and `1` (inclusive). `obs` must be less than or equal to `total` and both should be positive integers.
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let prob = 0.5
///     let obs = 10
///     let total = 100
///     let result = standardErrorProbabilistic(prob, observation: obs, totalObservations: total)
///     print(result)
///
/// Use this function when you want to find out how accurately a sample represents a population based on a given probability and the number of observations.
public func standardErrorProbabilistic<T: Real>(_ prob: T, observation n: Int, totalObservations total: Int) -> T {
    if T(n/total) <= T(Int(5) / Int(100)) {
        return standardErrorProbabilistic(prob, observations: n)
    } else {
        return standardErrorProbabilistic(prob, observations: n) * (T.sqrt(T ((total - n)/(total - 1))))
    }
}

