//
//  normInv.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

public func normInv<T: Real>(probability x: T, mean: T, stdev: T) -> T {
    return inverseNormalCDF(p: x, mean: mean, stdDev: stdev)
}

