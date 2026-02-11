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
public func permutation(_ n: Int, p r: Int) -> Int {
    return (factorial(n) / factorial(n - r))
}
