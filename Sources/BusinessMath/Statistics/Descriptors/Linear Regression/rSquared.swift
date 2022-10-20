//
//  rSquared.swift
//  
//
//  Created by Justin Purnell on 10/20/22.
//

import Foundation
import Numerics

public func rSquared<T: Real>(_ x: [T], _ y: [T], _ population: Population = .sample) -> T {
    let correlation = correlationCoefficient(x, y, population)
    return correlation * correlation
}
