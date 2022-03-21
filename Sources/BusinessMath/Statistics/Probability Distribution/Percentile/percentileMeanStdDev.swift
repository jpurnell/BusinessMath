//
//  percentileMeanStdDev.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func percentile<T: Real>(x: T, mean: T, stdDev: T) -> T {
    return percentile(zScore: zStatistic(x: x, mean: mean, stdDev: stdDev))
}
