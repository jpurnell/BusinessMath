//
//  zScorePercentile.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func zScore<T: Real>(percentile: T) -> T {
    return T.sqrt(2) * erfInv(y: ((T(2) * percentile) - T(1)))
}
