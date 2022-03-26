//
//  normalCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// Normal Cumulative Distribution public function
public func normalCDF<T: Real>(x: T, mean: T = 0, stdDev: T = 1) -> T {
    return (T(1) + T.erf((x - mean) / T.sqrt(2) / stdDev)) / T(2)
}
