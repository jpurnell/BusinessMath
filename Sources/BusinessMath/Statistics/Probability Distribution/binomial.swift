//
//  binomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Simulates a binomial experiment and returns the number of successes.
///
/// A binomial experiment is a statistical experiment that has several characteristics:
/// 1. The experiment consists of `n` repeated trials.
/// 2. Each trial can result in just two possible outcomes. We call one of these outcomes a success and the other, a failure.
/// 3. The probability of success, denoted by `p`, is the same on every trial.
///
/// - Parameters:
///     - n: Number of trials to be performed.
///     - p: The probability of success on each trial. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The total number of successes from the binomial experiment.
///
/// - Precondition: `n` must be a positive integer and `p` must be a value between `0` and `1` (inclusive).
/// - Complexity: O(n), where n is the number of trials.
///
///    let n = 10
///    let p = 0.5
///    let successes = binomial(n: n, p: p)
///    print(successes)
///
/// Use this function when you need to model the outcome of binary experiments.
public func binomial<T: Real>(n: Int, p: T) -> Int {
    var sum = 0
    for _ in 0..<n {
        sum += bernoulliTrial(p: p)
    }
    return sum
}
