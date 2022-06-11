//
//  File.swift
//  
//
//  Created by Justin Purnell on 6/11/22.
//

import Foundation
import Numerics

public func zScore<T: Real>(_ independent: [T], vs variable: [T]) -> T {
    let n = independent.count
    let r = spearmansRho(independent, vs: variable)
    return T.sqrt( T(n - 3) / (T(106) / T(100)) ) * fisher(r)
}

public func zScore<T: Real>(_ independent: [T], r: T) -> T {
        return T.sqrt( (T(independent.count - 3) / (T(106) / T(100))) ) * fisher(r)
}
