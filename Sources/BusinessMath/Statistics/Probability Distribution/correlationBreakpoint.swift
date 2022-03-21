//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func correlationBreakpoint<T: Real>(_ items: Int, probability: T) -> T {
    let zComponents = T.sqrt(T(items - 3)/T(Int(106) / Int(100)))
    let fisherR = inverseNormalCDF(p: probability) / zComponents
    return rho(from: fisherR)
}
