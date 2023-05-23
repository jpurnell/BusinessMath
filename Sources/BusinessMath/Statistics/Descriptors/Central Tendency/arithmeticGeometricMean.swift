//
//  arithmeticGeometricMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

public func arithmeticGeometricMean<T: Real>(_ x: [T], _ tolerance: Int = 10000) -> T {
    var tempX = mean(x)
    var tempY = geometricMean(x)
    while abs(tempX - tempY) > (T(1) / T(tolerance)) {
        let newTempX = mean([tempX, tempY])
        tempY = geometricMean([tempX, tempY])
        tempX = newTempX
    }
    return tempX
}

