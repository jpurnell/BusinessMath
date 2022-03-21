//
//  tStatistic.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func tStatistic<T: Real>(_ rho: T, dFr: T) -> T {
    let tStatistic = rho * T.sqrt(dFr / (1 - (rho *  rho)))
    return tStatistic
}

public func tStatistic<T: Real>(_ independent: [T], _ variable: [T]) -> T {
    return tStatistic(spearmansRho(independent, vs: variable), dFr: T(independent.count - 2))
}
