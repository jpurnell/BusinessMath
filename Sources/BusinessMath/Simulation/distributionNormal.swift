//
//  distributionNormal.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// The Box-Muller Method generates a normally distributed variable from a uniform distribution
// https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

func boxMullerSeed<T: Real>(_ u1: T = distributionUniform(), _ u2: T = distributionUniform()) -> (z1: T, z2: T) {
    let z1 = T.sqrt(T(-2) * T.log(u1)) * T.sin(2 * T.pi * u2)
    let z2 = T.sqrt(T(-2) * T.log(u1)) * T.cos(2 * T.pi) * u2
    return (z1, z2)
}

func boxMuller<T: Real>(mean: T = T(0), stdDev: T = T(1)) -> T {
    return (stdDev * boxMullerSeed().z1) + mean
}

func boxMuller<T: Real>(mean: T, variance: T) -> T {
    return boxMuller(mean: mean, stdDev: T.sqrt(variance))
}

public func distributionNormal<T: Real>(mean: T = T(0), stdDev: T = T(1)) -> T {
    return boxMuller(mean: mean, stdDev: stdDev)
}

public func distributionNormal<T: Real>(mean: T = T(0), variance: T = T(1)) -> T {
    return boxMuller(mean: mean, variance: variance)
}
