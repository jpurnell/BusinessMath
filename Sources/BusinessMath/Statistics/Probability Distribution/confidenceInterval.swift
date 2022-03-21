//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func confidenceInterval<T: Real>(mean: T, stdDev: T, z: T, popSize: Int) -> (low: T, high: T) {
    return (low: mean - (z * stdDev/T.sqrt(T(popSize))), high: mean +  (z * stdDev/T.sqrt(T(popSize))))
}

public func confidenceInterval<T: Real>(ci: T, values: [T]) -> (low: T, high: T) {
    // Range in which we can expect the population mean to be found with x% confidence
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    
    let lowValue = inverseNormalCDF(p: lowProb, mean: mean(values), stdDev: stdDev(values))
    let highValue = inverseNormalCDF(p: highProb, mean: mean(values), stdDev: stdDev(values))
    
    return (lowValue, highValue)
}
