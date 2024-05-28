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
/// - Example:
///   ```swift
///   let n: Int = 5
///   let r: Int = 3
///   let result = combination(n, c: r)
///   // result should be 10 since there are 10 ways to choose 3 elements from a set of 5 elements

public func combination(_ n: Int, c r: Int) -> Int {
    return (factorial(n) / (factorial(r) * factorial(n - r)))
}
