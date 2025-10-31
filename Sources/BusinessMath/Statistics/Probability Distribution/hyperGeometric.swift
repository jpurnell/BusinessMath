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

public func hypergeometric<T: Real>(total: Int, r: Int, n: Int, x: Int) -> T {
    // Validate inputs
    guard total >= 0, r >= 0, n >= 0, x >= 0 else { return 0 }
    guard r <= total else { return 0 }
    guard n <= total else { return 0 }
    guard x <= r else { return 0 }
    guard x <= n else { return 0 }
    guard (n - x) <= (total - r) else { return 0 }
    
    // Use log-space computation to avoid overflow
    let logNumerator = logCombination(r, c: x) + logCombination(total - r, c: n - x)
    let logDenominator = logCombination(total, c: n)
    
    let logResult = logNumerator - logDenominator
	return T(Int(exp(logResult)))
}

/// Computes the natural logarithm of the combination (n choose r).
///
/// This function uses logarithms to avoid integer overflow when computing large factorials.
///
/// - Parameters:
///   - n: The total number of elements
///   - r: The number of elements to choose
/// - Returns: The natural logarithm of C(n, r)

private func logCombination(_ n: Int, c r: Int) -> Double {
    guard n >= 0, r >= 0, r <= n else { return 0 }
    if r == 0 || r == n { return 0 } // ln(1) = 0
    
    return logFactorial(n) - logFactorial(r) - logFactorial(n - r)
}

/// Computes the natural logarithm of n!
///
/// - Parameter n: A non-negative integer
/// - Returns: The natural logarithm of n!

private func logFactorial(_ n: Int) -> Double {
    guard n >= 0 else { return 0 }
    if n <= 1 { return 0 } // ln(1) = 0
    
    // Use Stirling's approximation for large values
    if n > 20 {
        let nDouble = Double(n)
        return nDouble * log(nDouble) - nDouble + 0.5 * log(2.0 * .pi * nDouble)
    }
    
    // For smaller values, compute directly
    return (1...n).map { log(Double($0)) }.reduce(0, +)
}
