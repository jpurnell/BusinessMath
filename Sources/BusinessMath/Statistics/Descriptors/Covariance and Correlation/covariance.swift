//
//  covariance.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

public func covariance<T: Real>(_ x: [T], _ y:[T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return covarianceP(x, y)
        default:
            return covarianceS(x, y)
    }
}

public func covarianceS<T: Real>(_ x: [T], _ y:[T]) -> T {
    if (x.count == y.count) == false { return T(0) }
    var returnNum = T(0)
    let xMean = mean(x)
    let yMean = mean(y)
    for i in 0..<x.count {
        returnNum += ((x[i] - xMean) * (y[i] - yMean))
    }
    return returnNum / T(x.count - 1)
}

public func covarianceP<T: Real>(_ x: [T], _ y:[T]) -> T {
    if (x.count == y.count) == false { return T(0) }
    var returnNum = T(0)
    let xMean = mean(x)
    let yMean = mean(y)
    for i in 0..<x.count {
        returnNum += ((x[i] - xMean) * (y[i] - yMean))
    }
    return returnNum / T(x.count)
}
