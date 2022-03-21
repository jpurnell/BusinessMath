//
//  zScoreRho.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func zScore<T: Real>(rho: T, items: Int) -> T {
    return T.sqrt(T(items - 3)/T(Int(106) / 100)) * fisher(rho)
}

