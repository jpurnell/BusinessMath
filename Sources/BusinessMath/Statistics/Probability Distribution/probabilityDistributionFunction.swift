//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// Probability Distribution public function
public func normalPDF<T: Real>(x: T, mean: T = 0, stdDev: T = 1) -> T {
    let sqrt2Pi = T.sqrt(2 * T.pi)
    let xMinusMeanSquared = (x - mean) * (x - mean)
    let stdDevSquaredTimesTwo = 2 * stdDev * stdDev
    let numerator = T.exp(-xMinusMeanSquared / stdDevSquaredTimesTwo)
    return numerator / (sqrt2Pi * stdDev)
}

