//
//  median.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Equivalent of Excel MEDIAN(xx:xx)
/// - Parameter x: An array of values.
/// - Returns: Median calculates, for given sample, what number sits in between the upper 50% and the lower 50% of samples.
public func median<T: Real>(_ x: [T]) -> T {
    // Empty array returns NaN
    guard x.count > 0 else {
        return T.nan
    }

    // NaN propagates - if any value is NaN, result is NaN
    if x.contains(where: { $0.isNaN }) {
        return T.nan
    }

    // Sort the array to find the median
    let sorted = x.sorted()

    if sorted.count % 2 == 0 {
        let l = (sorted.count / 2) - 1
        let u = l + 1
        let lower = sorted[l]
        let upper = sorted[u]
        let num = lower + upper
        return num / T(2)
    } else {
        let medianIndex = (sorted.count + 1) / 2
        return sorted[medianIndex - 1]
    }
}
