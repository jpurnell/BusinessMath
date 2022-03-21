//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

public func covariancePopulation<T: Real>(x: [T], y: [T]) -> T {
    let xCount = T(x.count)
    let yCount = T(y.count)
    
    let xMean = average(x)
    let yMean = average(y)
  
    if xCount == 0 { return T(0) }
    if xCount != yCount { return T(0) }
    
        var sum: T = T(0)
        
        for (index, xElement) in x.enumerated() {
            let yElement = y[index]
            sum += ((xElement - xMean) * (yElement - yMean))
        }
        return sum / xCount
}
