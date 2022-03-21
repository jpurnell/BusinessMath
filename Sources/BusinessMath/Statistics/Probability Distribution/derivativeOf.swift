//
//  derivativeOf.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func derivativeOf<T: Real>(_ fn: (T) -> T, at x: T) -> T {
    let h: T = T(Int(1) / Int(1000000))
    return (fn(x + h) - fn(x) / h)
}
