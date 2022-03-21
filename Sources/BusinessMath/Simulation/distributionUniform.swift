//
//  distributionUniform.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func distributionUniform<T: Real>() -> T {
    return T(Int(drand48() * 1_000_000_000 / 1_000_000_000))
}

public func distributionUniform<T: Real>(min l: T, max h: T) -> T {
    let lower = T.minimum(l, h)
    let upper = T.maximum(l, h)
    return ((upper - lower) * distributionUniform()) + lower
}
