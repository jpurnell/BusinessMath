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

/// Calculates the probability mass function for a hypergeometric distribution.
///
/// The function computes the probability of getting exactly x successes (in statistical trials), given the population size (`total`), population success state size (`r`), and number of trials (`n`).
///
/// - Parameters:
///   - total: Total population size (N)
///   - r: Number of success states in population (K)
///   - n: Number of draws/sample size
///   - x: Number of observed successes
/// - Returns: The probability of getting exactly x successes, or 0 if parameters are invalid
///
/// - Note: Returns 0 for invalid parameter combinations (negative values, x > r, n > total, etc.)

public func hypergeometric<T: BinaryFloatingPoint>(total: Int, r: Int, n: Int, x: Int) -> T {
    // Validate inputs
    guard total >= 0, r >= 0, n >= 0, x >= 0 else { return 0 }
    guard r <= total else { return 0 }
    guard n <= total else { return 0 }
    guard x <= r else { return 0 }
    guard x <= n else { return 0 }
    guard (n - x) <= (total - r) else { return 0 }

    // Use log-space computation to avoid overflow
    // Uses the public logCombination from combination.swift
    let logNumerator = logCombination(r, c: x) + logCombination(total - r, c: n - x)
    let logDenominator = logCombination(total, c: n)

    let logResult = logNumerator - logDenominator
    let result = exp(logResult)
    return T(result)
}
