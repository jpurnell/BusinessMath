//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func requiredSampleSize<T: Real>(z: T, stdDev: T, sampleMean: T, populationMean: T) -> T {
    return (T.pow(z, T(2)) * T.pow(stdDev, T(2)))/T.pow((sampleMean - populationMean), T(2))
}

public func requiredSampleSize<T: Real>(ci: T, stdDev: T, sampleMean: T, populationMean: T) -> T {
    let z = zScore(ci: ci)
    return requiredSampleSize(z: z, stdDev: stdDev, sampleMean: sampleMean, populationMean: populationMean)
}

public func requiredSampleSizeProb<T: Real>(ci: T, prob: T, maxError: T) -> T {
    let z = zScore(ci: ci)
    return (T.pow(z, T(2)) * prob * (T(1) - prob))/(T.pow(maxError, T(2)))
}
