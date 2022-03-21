//
//  descriptives.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func descriptives<T: Real>(_ values: [T]) -> (mean: T, stdDev: T, skew: T, cVar: T) {
    let mu = mean(values)
    let stDev = stdDev(values)
    let skew = coefficientOfSkew(values)
    let coVar = coefficientOfVariation(stDev, mean: mu)
    return (mu, stDev, skew, coVar)
}

extension Array where Element: Real {
    public var descriptives: String { let desc = descriptives(self.map({$0 as! Double})); return "µ:\(desc.mean)\t∂:\(desc.stdDev)\tsk:\(desc.skew)\tCv:\(desc.cVar)"}
}
