//
//  distributionUniform.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func distributionUniform<T: Real>() -> T {
    let randomSeed = drand48()
    let value = T(Int(randomSeed * Double(1_000_000_000_000))) / T(1_000_000_000_000)
    return value
}

public func distributionUniform<T: Real>(min l: T, max h: T) -> T {
    let lower = T.minimum(l, h)
    let upper = T.maximum(l, h)
    return ((upper - lower) * distributionUniform()) + lower
}
