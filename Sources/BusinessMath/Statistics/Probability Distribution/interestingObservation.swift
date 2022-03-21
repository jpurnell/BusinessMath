//
//  interestingObservation.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics
// What we care about is when an observation is above or below our particular confidence interval for a given range
public func interestingObservation<T: Real>(observation x: T, values: [T], confidenceInterval ci: T) -> Bool {
    let ciRange = confidenceInterval(ci: ci, values: values)
    if x <= ciRange.low || x >= ciRange.high {
        return true
    }
    return false
}
