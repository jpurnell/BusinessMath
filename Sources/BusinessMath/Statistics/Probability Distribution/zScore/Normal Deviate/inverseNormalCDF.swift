//
//  inverseNormalCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func inverseNormalCDF<T: Real>(p: T, mean: T = 0, stdDev: T = 1, tolerance: T = T(1)/T(10000)) -> T {
    if mean != 0 || stdDev != 1 {
        return mean + stdDev * inverseNormalCDF(p: p)
    }
    
    var lowZ = T(-10)
    var midZ = T(0)
    var midP = T(0)
    var hiZ = T(10)
    
    while hiZ - lowZ > tolerance {
        midZ = (lowZ + hiZ) / T(2)
        midP = normalCDF(x: midZ)
        
        if midP < p {
            lowZ = midZ
        }
        else if midP > p {
            hiZ = midZ
        }
        else {
            break
        }
    }
    return midZ
}
