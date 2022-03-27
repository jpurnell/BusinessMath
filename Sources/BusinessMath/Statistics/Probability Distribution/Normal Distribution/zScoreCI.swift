//
//  zScoreCI.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func zScore<T: Real>(ci: T) -> T {
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    return zScore(percentile: highProb)
}
