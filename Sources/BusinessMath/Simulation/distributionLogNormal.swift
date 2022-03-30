//
//  distributionLogNormal.swift
//  
//
//  Created by Justin Purnell on 3/28/22.
//

import Foundation
import Numerics

// https://en.wikipedia.org/wiki/Log-normal_distribution#Related_distributions

public func distributionLogNormal<T: Real>(mean: T = T(0), stdDev: T = T(1)) -> T {
    return T.exp(distributionNormal(mean: mean, stdDev: stdDev))
}

public func distributionLogNormal<T: Real>(mean: T = T(0), variance: T = T(1)) -> T {
    return T.exp(distributionNormal(mean: mean, variance: variance))
}
