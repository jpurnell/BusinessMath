//
//  permutation.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation

/// Computes the number of permutations (n P r) for given `n` and `r`.
///
/// The permutation function calculates the number of ways to arrange `r` elements out of a set of `n` elements.
/// In permutations, the order of selection matters.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to arrange.
/// - Returns: The number of permutations, denoted as \( P(n, r) \), which is equal to
///   \[ P(n, r) = \frac{n!}{(n - r)!} \]
///
/// - Warning: For n > 20, this function may overflow. Use ``permutationChecked(_:p:)``
///   or ``permutationDouble(_:p:)`` for larger values.
///
/// ## Example
/// ```swift
/// let n: Int = 5
/// let r: Int = 3
/// let result = permutation(n, p: r)
/// print(result)  // Outputs: 60
/// // There are 60 ways to arrange 3 elements out of a set of 5 elements
/// ```
///
/// - SeeAlso: ``combination(_:c:)``
/// - SeeAlso: ``permutationChecked(_:p:)``
/// - SeeAlso: ``permutationDouble(_:p:)``
public func permutation(_ n: Int, p r: Int) -> Int {
    guard n >= 0, r >= 0, r <= n else { return 0 }
    if r == 0 { return 1 }

    // For small n, use factorial directly
    if n <= maxFactorialInt {
        return factorial(n) / factorial(n - r)
    }

    // For larger n, compute incrementally: P(n, r) = n * (n-1) * ... * (n-r+1)
    var result = 1
    for i in 0..<r {
        result *= (n - i)
    }
    return result
}

/// Computes the permutation with overflow checking.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to arrange.
/// - Returns: The number of permutations P(n, r).
/// - Throws: `BusinessMathError.overflow` if the result would overflow Int64.
///           `BusinessMathError.invalidInput` if n < 0, r < 0, or r > n.
///
/// ## Example
/// ```swift
/// let result = try permutationChecked(20, p: 10)  // 670,442,572,800
/// ```
public func permutationChecked(_ n: Int, p r: Int) throws -> Int {
    guard n >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "Permutation undefined for negative n",
            value: "n = \(n)",
            expectedRange: "n ≥ 0"
        )
    }
    guard r >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "Permutation undefined for negative r",
            value: "r = \(r)",
            expectedRange: "r ≥ 0"
        )
    }
    guard r <= n else {
        throw BusinessMathError.invalidInput(
            message: "Cannot arrange more elements than available",
            value: "r = \(r), n = \(n)",
            expectedRange: "r ≤ n"
        )
    }

    // Use Double-based computation and check if it fits in Int
    let result = permutationDouble(n, p: r)
    guard result <= Double(Int.max) else {
        throw BusinessMathError.overflow(
            operation: "permutation",
            value: "P(\(n), \(r))",
            limit: "Int.max = \(Int.max)"
        )
    }
    return Int(result)
}

/// Computes the permutation as a Double for larger values.
///
/// Uses log-space computation to avoid overflow for large n.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to arrange.
/// - Returns: The number of permutations as a Double.
///
/// ## Example
/// ```swift
/// let result = permutationDouble(100, p: 50)  // ~3.07e93
/// ```
public func permutationDouble(_ n: Int, p r: Int) -> Double {
    guard n >= 0, r >= 0, r <= n else { return 0 }
    if r == 0 { return 1 }

    // Use log-space: ln(P(n,r)) = ln(n!) - ln((n-r)!)
    let logResult = logFactorial(n) - logFactorial(n - r)
    return exp(logResult)
}

/// Computes the natural logarithm of the permutation P(n, r).
///
/// Useful for probability calculations where you need to multiply/divide
/// permutations without overflow.
///
/// - Parameters:
///   - n: The total number of elements.
///   - r: The number of elements to arrange.
/// - Returns: The natural logarithm of P(n, r).
public func logPermutation(_ n: Int, p r: Int) -> Double {
    guard n >= 0, r >= 0, r <= n else { return -.infinity }
    if r == 0 { return 0 } // ln(1) = 0

    return logFactorial(n) - logFactorial(n - r)
}
