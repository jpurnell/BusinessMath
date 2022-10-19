//
//  spearmansRho.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func spearmansRho<T: Real>(_ independent: [T], vs variable: [T]) -> T {
    var sigmaD = T(0)
    let sigmaX = (T.pow(T(independent.count), T(3)) - T(independent.count)) / T(12) - independent.tauAdjustment()
    let sigmaY = (T.pow(T(variable.count), T(3)) - T(variable.count)) / T(12) - variable.tauAdjustment()
    
    let independentRank = independent.rank()
    let variableRank = variable.rank()
    
    for i in 0..<independent.count {
        sigmaD += ((independentRank[i] - variableRank[i]) * (independentRank[i] - variableRank[i]))
    }
    
    let rho = (sigmaX + sigmaY - sigmaD) / (T(2) * T.sqrt((sigmaX * sigmaY)))
    return rho
}
