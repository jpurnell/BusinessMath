//
//  stdDevBinomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the standard deviation for a binomial distribution.
///
/// The standard deviation is a measure of the amount of variation or dispersion in a set of values. In the context of a binomial distribution, it's computed by taking the square root of the variance. For a binomial distribution, variance is calculated with the formula `n * p * (1 - p)`, where `n` is the number of trials and `p` is the probability of success in a single trial.
///
/// - Parameters:
///     - n: Number of trials in the binomial experiment as an `Int`.
///     - prob: Probability of success in a single trial. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The standard deviation for the binomial distribution as a `Real` number.
///
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let n = 5
///     let prob = 0.5
///     print(result)
public func stdDevBinomial<T: Real>(n: Int, prob: T) -> T {
    return T.sqrt(varianceBinomial(n: n, prob: prob))
}
