//
//  poissonDistribution.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Poisson Distribution: Measures the probability of a random event happening over some interval of some time or space. Assumes two things: 1) Probability of the occurence is constant for any two intervals of time or space. 2) The occurence of the even in any interval is independent of the occurence in any other interval
public func poisson<T: Real>(_ x: Int, µ: T) -> T {
    let numerator = T.pow(µ, T(x)) * T.exp(-1 * µ)
    let denominator = x.factorial()
    return numerator / T(denominator)
}
