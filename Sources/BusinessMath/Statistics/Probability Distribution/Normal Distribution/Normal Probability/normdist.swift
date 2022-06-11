//
//  normDist.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

public func normDist<T: Real>(x: T, mean: T, stdev: T) -> T {
    return normalCDF(x: x, mean: mean, stdDev: stdev)
}
