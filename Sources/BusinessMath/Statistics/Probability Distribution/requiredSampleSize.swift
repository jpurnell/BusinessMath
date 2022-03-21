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
