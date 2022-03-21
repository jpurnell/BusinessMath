//
//  correctedStandardError.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// Corrected with the finite population correction factor. To be used if the sample size is more than 5% of the population
public func correctedStdErr<T: Real>(_ x: [T], population: Int) -> T {
    let percentage = T(x.count / population)
    if percentage >= T(Int(5) / Int(100)) { return standardError(x) } else {
        let num = population - x.count
        let den = population - 1
        return standardError(x) * (T.sqrt(T(num/den)))
    }
}
