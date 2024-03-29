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
    if x.count == 0 { return T(0) } else {
        if x.count % 2 == 0 {
            let l = (x.count / 2) - 1
            let u = l + 1
            let lower = x[l]
            let upper = x[u]
            let num = lower + upper
            return num  / T(2)

        } else {
            let medianIndex = (x.count + 1) / 2
            return x[medianIndex - 1]
        }
    }
}
