//
//  correlationCoefficient.swift
//  
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

/// Correlation Coefficient is a measure of linear correlation between two sets of data.
/// - Parameters:
///   - x: An array of values of a single type
///   - y: An array of values of a single type. There must be an equal number of values in array x and array y
///   - population: Whether or not the array represents a sample set of a population or the entire observed population
/// - Returns: Correlation Coefficient is the ratio between the covariance of two variables and the product of their standard deviations; thus it is essentially a normalized measurement of the covariance, such that the result always has a value between −1 and 1.
/// - As with covariance itself, the measure can only reflect a linear correlation of variables, and ignores many other types of relationship or correlation. As a simple example, one would expect the age and height of a sample of teenagers from a high school to have a Pearson correlation coefficient significantly greater than 0, but less than 1 (as 1 would represent an unrealistically perfect correlation).
/// - Pearson's correlation coefficient, when applied to a population, is commonly represented by the Greek letter ρ (rho) and may be referred to as the population correlation coefficient or the population Pearson correlation coefficient.
public func correlationCoefficient<T: Real>(_ x: [T], _ y:[T], _ population: Population = .sample) -> T {
    switch population {
        case .population:
            return correlationCoefficientP(x, y)
        case .sample:
            return correlationCoefficientS(x, y)
    }
}
