//
//  varianceDiscrete.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

func varianceDiscrete<T: Real>(_ distribution: [(T, T)]) -> T {
    let mean = meanDiscrete(distribution)
    return distribution.map({ ($0.0 - mean) * ($0.0 - mean) * $0.1}).reduce(0, +)
}
