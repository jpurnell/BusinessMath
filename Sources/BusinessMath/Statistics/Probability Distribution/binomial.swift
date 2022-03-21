//
//  binomial.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func binomial<T: Real>(n: Int, p: T) -> Int {
    var sum = 0
    for _ in 0..<n {
        sum += bernoulliTrial(p: p)
    }
    return sum
}
