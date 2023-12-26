//
//  hyperGeometric.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Hypergeometric Distribution: If a sample is selected without replacement from a known finite population and contains a relatively large proportion of the population, such that the probability of a success is measurably altered from one selection to the next, the hypergeometric distribution should be used.
// Assume a stable has total = 10 horses, and r = 4 of them have a contagious disesase, what is the probability of selecting a sample of n = 3 in which there are x = 2 diseased horses?

/// Computes the Fisher transformation of a correlation coefficient.
///
/// This function returns the Fisher transformation of a correlation coefficient. The Fisher transformation is a statistical technique that transforms the distribution of the Pearson correlation coefficient to be more approximately normal.
///
/// - Parameter r: The correlation coefficient between two variables. It should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The Fisher transform of the input `r`.
///
/// - Complexity: O(1), as this function involves a constant number of operations.
///
///     let r = 0.5
///     let result = fisher(r)
///     print(result)  // Prints "0.549306"
///
/// Use this function to transform correlation coefficients for hypothesis testing or confidence interval construction.

/// Calculates the probability mass function for a hypergeometric distribution.
///
/// The function computes the probability of getting exactly x successes (in statistical trials), given the population size (`total`), population success state size (`r`), and number of trials (`n`).

public func hypergeometric<T: Real>(total: Int, r: Int, n: Int, x: Int) -> T {
    return T(combination(r, c: x) * combination(total - r, c: n - x)) / T(combination(total, c: n))
}
