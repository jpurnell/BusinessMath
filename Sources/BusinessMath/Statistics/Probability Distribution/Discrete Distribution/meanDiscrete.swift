//
//  meanDiscrete.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func meanDiscrete<T: Real>(_ distribution: [(T, T)]) -> T {
    return distribution.map({$0.0 * $0.1}).reduce(T(0), +)
}

