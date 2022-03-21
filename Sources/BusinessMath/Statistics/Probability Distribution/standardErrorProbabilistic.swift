//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func standardErrorProbabilistic<T: Real>(_ prob: T, observations n: Int) -> T {
    if prob > T(1) { return T(0) } else {
        return T.sqrt(prob * (1 - prob) / T(n))
    }
}

public func standardErrorProbabilistic<T: Real>(_ prob: T, observation n: Int, totalObservations total: Int) -> T {
    if T(n/total) <= T(Int(5) / Int(100)) {
        return standardErrorProbabilistic(prob, observations: n)
    } else {
        return standardErrorProbabilistic(prob, observations: n) * (T.sqrt(T ((total - n)/(total - 1))))
    }
}
