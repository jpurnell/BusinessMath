//
//  derivativeOf.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the derivative of a function at a given point.
///
/// The derivative of a function represents an infinitesimal change in the function with respect to one of its variables. This method calculates the derivative using the difference quotient, which estimates the slope of the tangent line to the function at a given point.
///
/// - Parameters:
///     - fn: The function of which to take the derivative. The function must take a single argument of type `T` and return a `T` type value.
///     - x: The point at which to compute the derivative of the function `fn`.
///
/// - Returns: The derivative of the given function `fn` at the point `x`.
///
/// - Complexity: O(1), as it uses a constant number of operations.
///
///     let fn: (Double) -> Double = { x in return x * x }
///     let x = 2.0
///     let result = derivativeOf(fn, at: x)
///     print(result)
///
/// Use this function to find the rate at which a function is changing at any given point.
public func derivativeOf<T: Real>(_ fn: (T) -> T, at x: T) -> T {
    let h: T = T(Int(1) / Int(1000000))
    return (fn(x + h) - fn(x) / h)
}
