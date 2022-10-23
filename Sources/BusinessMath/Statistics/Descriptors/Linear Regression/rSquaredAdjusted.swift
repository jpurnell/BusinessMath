//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/22/22.
//

import Foundation
import Numerics

public func rSquaredAdjusted<T: Real>(_ x: [T], _ y: [T], _ population: Population = .population, _ descriptors: T = T(1)) -> T {
    if (x.count == y.count) == false { return T(0) }
    let observations = T(x.count)
    let baseL = T(1) - rSquared(x, y, population)
    let baseC = observations - T(1)
    let baseR = observations - descriptors - T(1)
    let base = (baseL * baseC) / baseR
    return T(1) - base
}
