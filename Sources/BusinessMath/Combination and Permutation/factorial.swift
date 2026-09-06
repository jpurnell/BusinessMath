//
//  factorial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Maximum value of n for which n! fits in an Int (64-bit).
/// 20! = 2,432,902,008,176,640,000 fits in Int64
/// 21! = 51,090,942,171,709,440,000 overflows Int64
public let maxFactorialInt = 20

/// Computes the factorial of a given number `n`.
///
/// The factorial of `n` is the product of all positive integers less than or equal to `n`.
/// By definition, the factorial of 0 is 1.
///
/// - Parameter n: The number for which to compute the factorial. Must be a non-negative integer.
/// - Returns: The factorial of `n`, denoted as \( n! \).
///
/// - Warning: For n > 20, this function will overflow on 64-bit systems and return incorrect results.
///   Use ``factorialChecked(_:)`` or ``factorialDouble(_:)`` for larger values.
///
/// ## Example
/// ```swift
/// let result = factorial(5)
/// print(result)  // Outputs: 120
/// // 5! = 5 × 4 × 3 × 2 × 1 = 120
/// ```
///
/// - SeeAlso:
///   - ``factorialChecked(_:)``
///   - ``factorialDouble(_:)``
///   - ``combination(_:c:)``
///   - ``permutation(_:p:)``
public func factorial(_ n: Int) -> Int {
    guard n >= 0 else { return 0 }
    guard n <= 1 else {
        return (2...n).reduce(1, *)
    }
    return 1
}

/// Computes the factorial with overflow checking.
///
/// This is the safe version that throws an error if the result would overflow.
///
/// - Parameter n: The number for which to compute the factorial. Must be non-negative and ≤ 20.
/// - Returns: The factorial of `n`.
/// - Throws: `BusinessMathError.overflow` if n > 20 (would overflow Int64)
///           `BusinessMathError.invalidInput` if n < 0
///
/// ## Example
/// ```swift
/// let result = try factorialChecked(20)  // 2,432,902,008,176,640,000
/// let overflow = try factorialChecked(21)  // Throws overflow error
/// ```
public func factorialChecked(_ n: Int) throws -> Int {
    guard n >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "Factorial undefined for negative numbers",
            value: "\(n)",
            expectedRange: "n ≥ 0"
        )
    }
    guard n <= maxFactorialInt else {
        throw BusinessMathError.overflow(
            operation: "factorial",
            value: "\(n)!",
            limit: "\(maxFactorialInt)! is max for Int64"
        )
    }
    return factorial(n)
}

/// Computes the factorial as a Double for larger values.
///
/// Uses Stirling's approximation for n > 170 (where Double overflows).
/// For n ≤ 170, computes exactly.
///
/// - Parameter n: The number for which to compute the factorial.
/// - Returns: The factorial as a Double, or `.infinity` for very large n.
///
/// ## Example
/// ```swift
/// let result = factorialDouble(100)  // ~9.33e157
/// ```
public func factorialDouble(_ n: Int) -> Double {
    guard n >= 0 else { return 0 }
    guard n > 1 else { return 1 }

    // Double can represent up to about 170!
    if n <= 170 {
        return (2...n).reduce(1.0) { $0 * Double($1) }
    }

    // Use Stirling's approximation for very large n
    // n! ≈ √(2πn) * (n/e)^n
    let nDouble = Double(n)
    let logFactorial = nDouble * log(nDouble) - nDouble + 0.5 * log(2.0 * .pi * nDouble)
    return exp(logFactorial)
}

/// Computes the natural logarithm of n! for use in probability calculations.
///
/// This avoids overflow by working in log-space.
///
/// - Parameter n: The number for which to compute ln(n!).
/// - Returns: The natural logarithm of n!.
public func logFactorial(_ n: Int) -> Double {
    guard n >= 0 else { return 0 }
    guard n > 1 else { return 0 }  // ln(1) = 0

    // ln(n!) is ln Γ(n+1) exactly, and `logGamma` is correctly rounded.
    //
    // This used to switch to Stirling's approximation above n = 20 — but to its
    // *leading* terms only, `n ln n − n + ½ln(2πn)`, with the 1/(12n) correction and
    // everything after it dropped. The relative error in ln(n!) is then about 1/(12n),
    // which sounds small and is not: exponentiated, n! came out **0.4% wrong at n = 21**
    // and 0.17% wrong at n = 500. It was also discontinuous — n = 20 took the exact
    // path and was right, n = 21 took Stirling and was not.
    //
    // That propagated into `combination`, `permutation` and `hypergeometric`, and was
    // found by comparing the hypergeometric distribution to a spreadsheet for the first
    // time: 2.1e-4 relative on a population of thirty.
    return Double.logGamma(Double(n) + 1)
}

extension Int {
    /// Computes the factorial of this integer.
    ///
    /// Provides a convenient instance method alternative to the global ``factorial(_:)`` function.
    /// Returns 0 for negative integers as factorials are undefined for negative numbers.
    ///
    /// - Warning: For values > 20, this will overflow on 64-bit systems.
    ///   Use ``factorialChecked()`` for safe computation.
    ///
    /// - Returns: The factorial of this integer, or 0 if negative.
    ///
    /// ## Example
    /// ```swift
    /// let result = 5.factorial()
    /// print(result)  // Outputs: 120
    /// ```
    ///
    /// - SeeAlso: ``factorial(_:)``
    public func factorial() -> Int {
        return BusinessMath.factorial(self)
    }

    /// Computes the factorial with overflow checking.
    ///
    /// - Returns: The factorial of this integer.
    /// - Throws: `BusinessMathError.overflow` if self > 20
    ///           `BusinessMathError.invalidInput` if self < 0
    public func factorialChecked() throws -> Int {
        return try BusinessMath.factorialChecked(self)
    }
}
