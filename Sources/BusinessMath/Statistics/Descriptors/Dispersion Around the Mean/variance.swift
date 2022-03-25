//
//  variance.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// When we are working with a subset (sample) of the total number of observations, we use the sum of squared average differences, but divide it by one fewer than the number of observations. If there are fewer than 30 observations in the sample, we use the T-Distribution of the Variance (varianceTDist)

// Equivalent of Excel VAR(xx:xx)
public func varianceS<T: Real>(_ values: [T]) -> T {
//    if values.count < 30 {
//        return varianceTDist(values)
//    }
    let degreesOfFreedom = values.count - 1
    return sumOfSquaredAvgDiff(values)/T(degreesOfFreedom)
}

// MARK: - The variance, when we have the entire population of values and not a sample, is the Sum of Squared Average Difference, averaged over the total number of observations
// Equivalent of Excel VARP(xx:xx)
public func varianceP<T: Real>(_ values: [T]) -> T {
    return sumOfSquaredAvgDiff(values)/T(values.count)
}

public func variance<T: Real>(_ values: [T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return varianceP(values)
        default:
            return varianceS(values)
    }
}

// MARK: - Variance t-dist For samples of under 30 degrees of freedom, the t-distribution provides a more accurate sample compared to the z-distribution (normal distribution), which can overfit
public func varianceTDist<T: Real>(_ values: [T]) -> T {
    if values.count > 30 { return variance(values) }
    return (T(values.count - 1) / T(values.count - 3))
}
