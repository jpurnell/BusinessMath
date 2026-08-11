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
/// The standard error measures the statistical accuracy of an estimate of a mean. Sampling *without*
/// replacement from a finite population makes the naive standard error too large, and the finite
/// population correction `sqrt((N − n) / (N − 1))` removes the excess.
///
/// The correction is applied when the sample exceeds 5% of the population. Below that the factor is
/// within about 2.5% of 1 and is conventionally ignored, which is the rule of thumb this threshold
/// encodes; the same threshold and the same direction are used by
/// ``standardErrorProbabilistic(_:observation:totalObservations:)``.
///
/// - Parameters:
///     - x: The array of samples. Each samples should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - population: The size of the population.
///
/// - Returns: The standard error, corrected for the finite population when the sample is more than
///   5% of it.
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
    // Fixed: three integer divisions, each of which truncated to zero, and a comparison
    // that pointed the wrong way.
    //
    // `T(x.count / population)` was Int division, so `percentage` was 0 for every sample
    // smaller than its population — which the precondition requires. `T(Int(5) / Int(100))`
    // was likewise 0, so the test read `0 >= 0` and was always true: the finite-population
    // branch had never executed, and the function had only ever returned the uncorrected
    // standard error. `T(num/den)` was Int division too, so had that branch been reached it
    // would have returned `standardError(x) * sqrt(0)` — zero — for any sample of more than
    // one element.
    //
    // The comparison was also inverted: it skipped the correction at or above 5% and applied
    // it below, which is backwards. The correction matters precisely when the sample is a
    // large fraction of the population — at n/N = 0.5 it is 0.71 — and is negligible when the
    // fraction is small. Repairing the constants alone would have made a reachable branch out
    // of one that corrects only where correction does not matter.
    let percentage = T(x.count) / T(population)
    if percentage <= T(5) / T(100) { return standardError(x) } else {
        let num = population - x.count
        let den = population - 1
        return standardError(x) * (T.sqrt(T(num) / T(den)))
    }
}
