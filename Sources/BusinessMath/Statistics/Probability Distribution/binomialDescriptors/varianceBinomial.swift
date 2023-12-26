//
//  varianceBinomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the variance for a binomial distribution.
///
/// This function calculates the variance, which is a measure of how spread out the distribution is. The variance is computed using the formula `n * p * (1 - p)`, where `n` is the number of trials and `p` is the probability of success in a single trial.
///
/// - Parameters:
///     - n: Number of trials in the binomial experiment as an `Int`.
///     - prob: Probability of success in a single trial. It adheres to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The variance for the binomial distribution as a `Real` number.
///
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let n = 5
///     let prob = 0.5
///     let result = varianceBinomial(n: n, prob: prob)
///     print(result)
public func varianceBinomial<T: Real>(n: Int, prob: T) -> T {
    return T(n) * prob * (1 - prob)
}

