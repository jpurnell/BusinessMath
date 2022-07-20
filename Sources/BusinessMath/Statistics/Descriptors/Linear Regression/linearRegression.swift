//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import Foundation
import Numerics

public func slope<T: Real>(_ xValues: [T], _ yValues: [T]) -> T {
    let sum1 = average(multiplyVectors(yValues, xValues)) - average(xValues) * average(yValues)
    let sum2 = average(multiplyVectors(xValues, xValues)) - T.pow(average(xValues), T(2))
    return sum1 / sum2
}

public func intercept<T: Real>(_ xValues: [T], _ yValues: [T]) -> T {
    return average(yValues) - slope(xValues, yValues) * average(xValues)
}

public func linearRegression<T: Real>(_ xValues: [T], _ yValues: [T]) -> (T) -> T {
    let slope = slope(xValues, yValues)
    print("Slope:\t\(slope)")
    let intercept = intercept(xValues, yValues)
    print("Intercept:\t\(intercept)")
    return { x in intercept + slope * x}
}
