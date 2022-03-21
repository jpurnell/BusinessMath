//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func mean<T: Real>(_ x: [T]) -> T {
    guard x.count > 0 else {
        return T(0)
    }
    return (x.reduce(T(0), +) / T(x.count))
}

public func average<T: Real>(_ x: [T]) -> T {
    return mean(x)
}
