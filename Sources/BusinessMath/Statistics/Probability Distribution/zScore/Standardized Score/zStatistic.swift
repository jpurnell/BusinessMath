//
//  zStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func zStatistic<T: Real>(x: T, mean: T = T(0), stdDev: T = T(1)) -> T {
    return ((x - mean) / stdDev)
}

public func zScore<T: Real>(x: T, mean: T = T(0), stdDev: T = T(1)) -> T {
    return zStatistic(x: x, mean: mean, stdDev: stdDev)
}
