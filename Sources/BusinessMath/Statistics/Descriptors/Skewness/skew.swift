//
//  skew.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

public func skew<T: Real>(_ values:[T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return skewP(values)
        default:
            return skewS(values)
    }
}

// Sample Skewness – This is the Excel default.
public func skewS<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let mean = average(values)
    let s: T = stdDev(values)
    let x = values.map({T.pow((($0 - mean) / s), 3) }).reduce(0, +)
    return (n / ((n - T(1)) * (n - T(2)))) * x
}

// Excel does not have a formula for population Skew
public func skewP<T: Real>(_ values: [T]) -> T {
    let n = T(values.count)
    let µ = average(values)
    let s = stdDevP(values)
    let x = values.map({T.pow((($0 - µ) / s), 3)}).reduce(0, +)
    return (T(1) / n) * x
}
