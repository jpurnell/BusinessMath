//
//  factorial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the factorial of a given number `n`.
///
/// The factorial of `n` is the product of all positive integers less than or equal to `n`.
/// By definition, the factorial of 0 is 1.
///
/// - Parameter n: The number for which to compute the factorial. Must be a non-negative integer.
/// - Returns: The factorial of `n`, denoted as \( n! \).
///
/// - Example:
///   ```swift
///   let result = factorial(5)
///   // result should be 120 since 5! = 5 * 4 * 3 * 2 * 1 = 120

public func factorial(_ n: Int) -> Int {
    var returnValue = 1
    if n == 0 { return returnValue }
    else {
        returnValue = (1...n).map({$0}).reduce(1, *)
    }
    return returnValue
}

extension Int {
    public func factorial() -> Int {
        if self >= 0 {
            return self == 0 ? 1 : self * (self - 1).factorial()
        } else {
            return 0
        }
    }
}
