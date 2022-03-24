//
//  cVar.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func coefficientOfVariation<T: Real>(_ stdDev: T, mean: T) -> T {
    return (stdDev / mean) * T(100)
}
