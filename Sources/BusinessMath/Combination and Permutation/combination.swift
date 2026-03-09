//
//  combination.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation

/// Computes the number of combinations (n choose r) for given `n` and `r`.
///
/// The combination function calculates the number of ways to choose `r` elements from a set of `n` elements without regard to the order of selection.
/// This is also known as a binomial coefficient.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to choose.
/// - Returns: The number of combinations, denoted as \( C(n, r) \), which is equal to
///   \[ \binom{n}{r} = \frac{n!}{r!(n - r)!} \]
///
/// - Warning: For n > 20, this function may overflow. Use ``combinationChecked(_:c:)``
///   or ``combinationDouble(_:c:)`` for larger values.
///
/// ## Example
/// ```swift
/// let n: Int = 5
/// let r: Int = 3
/// let result = combination(n, c: r)
/// print(result)  // Outputs: 10
/// // There are 10 ways to choose 3 elements from a set of 5 elements
/// ```
///
/// - SeeAlso: ``permutation(_:p:)``
/// - SeeAlso: ``combinationChecked(_:c:)``
/// - SeeAlso: ``combinationDouble(_:c:)``
public func combination(_ n: Int, c r: Int) -> Int {
    guard n >= 0, r >= 0, r <= n else { return 0 }
    // Optimize: C(n, r) == C(n, n-r), use smaller r for efficiency
    let k = min(r, n - r)
    if k == 0 { return 1 }

    // For small n, use factorial directly
    if n <= maxFactorialInt {
        return factorial(n) / (factorial(k) * factorial(n - k))
    }

    // For larger n, compute incrementally to avoid overflow as long as possible
    // C(n, k) = (n * (n-1) * ... * (n-k+1)) / (k * (k-1) * ... * 1)
    var result = 1
    for i in 0..<k {
        result = result * (n - i) / (i + 1)
    }
    return result
}

/// Computes the combination with overflow checking.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to choose.
/// - Returns: The number of combinations C(n, r).
/// - Throws: `BusinessMathError.overflow` if the result would overflow Int64.
///           `BusinessMathError.invalidInput` if n < 0, r < 0, or r > n.
///
/// ## Example
/// ```swift
/// let result = try combinationChecked(20, c: 10)  // 184,756
/// ```
public func combinationChecked(_ n: Int, c r: Int) throws -> Int {
    guard n >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "Combination undefined for negative n",
            value: "n = \(n)",
            expectedRange: "n ≥ 0"
        )
    }
    guard r >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "Combination undefined for negative r",
            value: "r = \(r)",
            expectedRange: "r ≥ 0"
        )
    }
    guard r <= n else {
        throw BusinessMathError.invalidInput(
            message: "Cannot choose more elements than available",
            value: "r = \(r), n = \(n)",
            expectedRange: "r ≤ n"
        )
    }

    // Use Double-based computation and check if it fits in Int
    let result = combinationDouble(n, c: r)
    guard result <= Double(Int.max) else {
        throw BusinessMathError.overflow(
            operation: "combination",
            value: "C(\(n), \(r))",
            limit: "Int.max = \(Int.max)"
        )
    }
    return Int(result)
}

/// Computes the combination as a Double for larger values.
///
/// Uses log-space computation to avoid overflow for large n.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to choose.
/// - Returns: The number of combinations as a Double.
///
/// ## Example
/// ```swift
/// let result = combinationDouble(100, c: 50)  // ~1.0e29
/// ```
public func combinationDouble(_ n: Int, c r: Int) -> Double {
    guard n >= 0, r >= 0, r <= n else { return 0 }
    if r == 0 || r == n { return 1 }

    // Use log-space to avoid overflow
    let logResult = logFactorial(n) - logFactorial(r) - logFactorial(n - r)
    return exp(logResult)
}

/// Computes the natural logarithm of the combination (n choose r).
///
/// Useful for probability calculations where you need to multiply/divide
/// combinations without overflow.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to choose.
/// - Returns: The natural logarithm of C(n, r).
public func logCombination(_ n: Int, c r: Int) -> Double {
    guard n >= 0, r >= 0, r <= n else { return -.infinity }
    if r == 0 || r == n { return 0 } // ln(1) = 0

    return logFactorial(n) - logFactorial(r) - logFactorial(n - r)
}
