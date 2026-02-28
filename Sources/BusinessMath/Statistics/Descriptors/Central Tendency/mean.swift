//
//  mean.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Equivalent of Excel AVERAGE(xx:xx), provides the mean of a set of numbers.
///
/// Uses Kahan summation for numerical stability with large datasets.
///
/// - Returns: Provides the mean of a set of numbers.
/// - Parameter x: An array of values of a single type
public func mean<T: Real>(_ x: [T]) -> T {
    // Empty array returns NaN
    guard x.count > 0 else {
        return T.nan
    }

    // NaN propagates - if any value is NaN, result is NaN
    if x.contains(where: { $0.isNaN }) {
        return T.nan
    }

    // If array contains infinity, use simple sum (Kahan summation breaks with infinity)
    if x.contains(where: { $0.isInfinite }) {
        let simpleSum = x.reduce(T(0), +)
        return simpleSum / T(x.count)
    }

    // Use Kahan summation for numerical stability with large finite datasets
    return (kahanSum(x) / T(x.count))
}

/// Equivalent of Excel AVERAGE(xx:xx)
/// - Parameter x: An array of values of a single type.
/// - Returns: Provides the mean of a set of numbers.
public func average<T: Real>(_ x: [T]) -> T {
    return mean(x)
}
