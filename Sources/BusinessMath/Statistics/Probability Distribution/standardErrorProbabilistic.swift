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
