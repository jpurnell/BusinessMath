//
//  correlationCoefficient.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

func correlationCoefficient<T: Real>(_ x:[T], _ y:[T]) -> T {
    if (x.count == y.count) == false { return T(0) }
    var numerator = T(0)
    var denominator = T(0)
    var xDenom = T(0)
    var yDenom = T(0)
    let xMean = mean(x)
    let yMean = mean(y)
    for i in 0..<x.count {
        let xSide = (x[i] - xMean)
        let ySide = (y[i] - yMean)
        numerator += xSide * ySide
        xDenom += T.pow(xSide, 2)
        yDenom += T.pow(ySide, 2)
        
    }
    return numerator / T.sqrt(xDenom * yDenom)
}
