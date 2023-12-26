//
//  meanBinomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the mean for a binomial distribution.
///
/// The mean (also known as expectation) of a binomial distribution is computed using the formula `n * p`, where `n` is the number of trials and `p` is the probability of success in a single trial.
///
/// - Parameters:
///     - n: Number of trials in the binomial experiment as an `Int`.
///     - prob: Probability of success in a single trial. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The mean for the binomial distribution as a `Real` number.
///
/// - Complexity: O(1) as the function uses a constant number of operations.
///
///     let n = 5
///     let prob = 0.5
///     let result = meanBinomial(n: n, prob: prob)
///     print(result)
public func meanBinomial<T: Real>(n: Int, prob: T) -> T {
    return T(n) * prob
}
