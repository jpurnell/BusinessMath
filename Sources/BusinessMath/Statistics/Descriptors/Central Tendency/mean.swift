//
//  mean.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Equivalent of Excel AVERAGE(xx:xx), provides the mean of a set of numbers.
/// - Returns: Provides the mean of a set of numbers.
/// - Parameter x: An array of values of a single type
public func mean<T: Real>(_ x: [T]) -> T {
    guard x.count > 0 else {
        return T(0)
    }
    return (x.reduce(T(0), +) / T(x.count))
}

/// Equivalent of Excel AVERAGE(xx:xx)
/// - Parameter x: An array of values of a single type.
/// - Returns: Provides the mean of a set of numbers.
public func average<T: Real>(_ x: [T]) -> T {
    return mean(x)
}
