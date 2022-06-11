//
//  Monte Carlo Integration.swift
//  
//
//  Created by Justin Purnell on 3/27/22.
//

import Foundation
import Numerics

//MARK: - Adapted from https://www.cantorsparadise.com/demystifying-monto-carlo-integration-7c9bd0e37689

public func integrate<T: Real>(_ f: (T) -> T, iterations n: Int) -> T {
    let randomSeed = drand48()
    var m = T(Int(randomSeed * Double(1_000_000_000_000))) / T(1_000_000_000_000)
    for i in 0..<n {
        m += ((f(distributionUniform()) - m)) / T((i + 1))
    }
    return m
}
