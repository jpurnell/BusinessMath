//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the correlation breakpoint for given items and probability.
///
/// A correlation breakpoint represents a threshold that divides a dataset into two segments with different correlation properties. This method allows you to calculate the correlation breakpoint using Fisher r-to-z transformation.
///
/// - Parameters:
///     - items: The number of elements (items) in the dataset.
///     - probability: The given probability for the inverse normal cumulative distribution function (CDF).
///
/// - Returns: The correlation breakpoint as a `Real` type.
///
/// - Precondition: `items` must be a positive integer and `probability` has to be a value between `0` and `1`.
/// - Complexity: O(1), as it uses a constant number of operations.
///
///     let items = 100
///     let probability = 0.95 // 95% is a commonly used threshold
///     let result = correlationBreakpoint(items, probability: probability)
///     print(result)
///
/// Use this function when you need to find a threshold splitting a dataset into two segments with different correlation properties.
public func correlationBreakpoint<T: Real>(_ items: Int, probability: T) -> T {
    let zComponents = T.sqrt(T(items - 3)/T(Int(106) / Int(100)))
    let fisherR = inverseNormalCDF(p: probability) / zComponents
    return rho(from: fisherR)
}
