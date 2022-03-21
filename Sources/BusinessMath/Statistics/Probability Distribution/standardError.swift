//
//  standardError.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func standardError<T: Real>(_ stdDev: T, observations n: Int) -> T {
    return stdDev / T.sqrt(T(n))
}

public func standardError<T: Real>(_ x: [T]) -> T {
    return standardError(stdDev(x, .sample), observations: x.count)
}
