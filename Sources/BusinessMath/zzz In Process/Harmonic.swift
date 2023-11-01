//
//  Harmonic.swift
//  
//
//  Created by Justin Purnell on 12/27/22.
//

import Foundation
import Numerics

//public func harmonic<T: Real>(_ n: Int) -> T {
//    return (1...n).map({1 / T($0)}).reduce(T(0), +)
//}

//TODO: - LABEL THIS AS PUBLIC WHEN CORRECT
func harmonic<T: Real>(_ n: Int, _ x: T = T(1)) -> T {
    return (1...n).map({(T(1) / T.pow(T($0), x) )}).reduce(T(0), +)
}
