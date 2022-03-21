//
//  percentileZScore.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func percentile<T: Real>(zScore z: T) -> T {
    return (1 + T.erf(z / T.sqrt(2))) / T(2)
}
