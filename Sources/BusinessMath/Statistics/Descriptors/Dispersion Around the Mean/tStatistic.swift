//
//  tStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func tStatistic<T: Real>(x: T, mean: T = T(0), stdErr: T = T(1)) -> T {
    return ((x - mean) / stdErr)
}
