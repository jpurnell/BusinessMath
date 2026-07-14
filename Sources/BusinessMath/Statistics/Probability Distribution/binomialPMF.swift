//
//  binomialPMF.swift
//  BusinessMath
//
//  Binomial probability mass function
//

import Foundation
import Numerics

/// Calculates the binomial probability mass function (PMF).
///
/// The binomial PMF gives the probability of getting exactly k successes in n independent Bernoulli trials,
/// where each trial has success probability p.
///
/// - Parameters:
///   - n: The number of trials (must be non-negative).
///   - k: The number of successes (must be between 0 and n inclusive).
///   - p: The probability of success on each trial (must be between 0 and 1).
///
/// - Returns: The probability of getting exactly k successes in n trials.
///
/// - Note: The function follows the formula:
///   \[ P(X = k) = \binom{n}{k} p^k (1-p)^{n-k} \]
///   where \(\binom{n}{k}\) is the binomial coefficient "n choose k".
///
/// - Example:
///   ```swift
///   let prob = binomialPMF(n: 10, k: 3, p: 0.5)
///   // Probability of getting exactly 3 heads in 10 coin flips
///   ```
///
public func binomialPMF<T: Real>(n: Int, k: Int, p: T) -> T {
    guard k >= 0, k <= n else { return T(0) }
    guard p >= 0, p <= 1 else { return T(0) }

    let coef = T(combination(n, c: k))
    // Use the integer-exponent `pow` overload: with a real exponent, the boundary term
    // `pow(0, 0)` evaluates as `exp(0 · log 0) = NaN`, whereas the integer overload
    // correctly yields 1 (an empty product) — so p = 0 / p = 1 stay well-defined.
    let prob = coef * T.pow(p, k) * T.pow(T(1) - p, n - k)
    return prob
}
