//
//  estMean.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func estMean<T: Real>(probabilities x: [T]) -> T {
    return x.reduce(T(0), +) / T(x.count)
}
