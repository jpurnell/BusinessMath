//
//  confidenceIntervalProbabilistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func confidenceIntervalProbabilistic<T: Real>(_ prob: T, observations n: Int, ci: T) -> (low: T, high: T) {
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    let standardError = standardErrorProbabilistic(prob, observations: n)
    let z = zScore(percentile: highProb)
    let lowerCI = prob - (z * standardError)
    let upperCI = prob + (z * standardError)
    return (low: lowerCI, high: upperCI)
}
