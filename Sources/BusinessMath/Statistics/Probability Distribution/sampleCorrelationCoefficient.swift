//
//  sampleCorrelationCoefficient.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func sampleCorrelationCoefficient<T: Real>(_ independent: [T], vs variable: [T]) -> T {
    let numerator = covariancePopulation(x: independent, y: variable)
    let denominator = (stdDev(independent) * stdDev(variable))
    let r = numerator / denominator
    return r
}
