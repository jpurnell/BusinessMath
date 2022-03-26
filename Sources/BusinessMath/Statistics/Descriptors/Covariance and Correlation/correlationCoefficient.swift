//
//  correlationCoefficient.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

// MARK: - Correlation Coefficient is a measure of linear correlation between two sets of data. It is the ratio between the covariance of two variables and the product of their standard deviations; thus it is essentially a normalized measurement of the covariance, such that the result always has a value between −1 and 1. As with covariance itself, the measure can only reflect a linear correlation of variables, and ignores many other types of relationship or correlation. As a simple example, one would expect the age and height of a sample of teenagers from a high school to have a Pearson correlation coefficient significantly greater than 0, but less than 1 (as 1 would represent an unrealistically perfect correlation).


// Pearson's correlation coefficient, when applied to a population, is commonly represented by the Greek letter ρ (rho) and may be referred to as the population correlation coefficient or the population Pearson correlation coefficient.

func correlationCoefficient<T: Real>(_ x: [T], _ y:[T], _ population: Population = .sample) -> T {
    switch population {
        case .population:
            return correlationCoefficientP(x, y)
        case .sample:
            return correlationCoefficientS(x, y)
    }
}

func correlationCoefficientS<T: Real>(_ x:[T], _ y:[T]) -> T {
    if (x.count == y.count) == false { return T(0) }
    var numerator = T(0)
    var xDenom = T(0)
    var yDenom = T(0)
    let xMean = mean(x)
    let yMean = mean(y)
    for i in 0..<x.count {
        let xSide = (x[i] - xMean)
        let ySide = (y[i] - yMean)
        numerator += xSide * ySide
        xDenom += T.pow(xSide, 2)
        yDenom += T.pow(ySide, 2)
    }
//    print(numerator)
//    print("\(T.sqrt(xDenom) * T.sqrt(yDenom))")
    return numerator / (T.sqrt(xDenom) * T.sqrt(yDenom))
}

public func correlationCoefficientP<T: Real>(_ x: [T], _ y: [T]) -> T {
    let numerator = covarianceP(x, y)
    let denominator = (stdDev(x, .population) * stdDev(y, .population))
//    print(numerator)
//    print(denominator)
    let r = numerator / denominator
    return r
}
