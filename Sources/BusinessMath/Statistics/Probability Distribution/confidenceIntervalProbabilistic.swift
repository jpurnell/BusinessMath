//
//  confidenceIntervalProbabilistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the confidence interval for given probability, number of observations, and confidence level.
///
/// The function calculates a probabilistic confidence interval. It uses the standard error, z-score, and given probability to find the range within which we can be confident the true population value lies.
///
/// - Parameters:
///     - prob: The given probability.
///     - n: The number of observations.
///     - ci: The confidence level.
///
/// - Returns: A tuple representing the lower (`low`) and upper (`high`) bounds of the confidence interval.
///
/// - Precondition: `prob` should be a value between `0` and `1` (inclusive), `n` should be a positive integer, and `ci` has to be a value between `0` and `1` (inclusive).
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let prob = 0.5
///     let n  = 100
///     let ci = 0.95
///     let result = confidenceIntervalProbabilistic(prob, observations: n, ci: ci)
///     print(result) // Prints "(low: x, high: y)"
///
/// Use this function when dealing with binary outcomes, such as success and failure, yes and no, or true and false, and you need to estimate a confidence interval for a certain probability within your sample data.
public func confidenceIntervalProbabilistic<T: Real>(_ prob: T, observations n: Int, ci: T) -> (low: T, high: T) {
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    let standardError = standardErrorProbabilistic(prob, observations: n)
    let z = zScore(percentile: highProb)
    let lowerCI = prob - (z * standardError)
    let upperCI = prob + (z * standardError)
    return (low: lowerCI, high: upperCI)
}
