//
//  covariance.swift
//
//
//  Created by Justin Purnell on 3/24/22.
//

import Foundation
import Numerics

/// Computes the covariance for two datasets, either as sample covariance or population covariance.
///
/// Covariance measures how much two random variables change together. The function can calculate either the sample covariance or the population covariance based on the specified population type. By default, it computes the sample covariance.
///
/// - Parameters:
///	- x: An array of values representing the first dataset.
///	- y: An array of values representing the second dataset.
///	- pop: An enumeration value of type `Population` indicating whether to calculate the sample covariance or population covariance. Defaults to `.sample`.
///
/// - Returns: The covariance of the two given datasets, either as sample covariance or population covariance.
///
/// - Enum Population:
///   - `sample`: Indicates that the function should calculate the sample covariance.
///   - `population`: Indicates that the function should calculate the population covariance.
///
/// - Note:
///   - This function uses the `covarianceS(_:_:)` function to compute sample covariance and the `covarianceP(_:_:)` function to compute population covariance.
///   - Ensure both input arrays have the same length for meaningful covariance computation.
///
/// - Requires:
///   - Implementation of the `covarianceS(_:_:)` function to compute sample covariance.
///   - Implementation of the `covarianceP(_:_:)` function to compute population covariance.
///
/// - Example:
///   ```swift
///   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let yVals: [Double] = [5.0, 4.0, 3.0, 2.0, 1.0]
///   let sampleCovariance = covariance(xVals, yVals, .sample)
///   let populationCovariance = covariance(xVals, yVals, .population)
///   print("Sample covariance: \(sampleCovariance)")
///   print("Population covariance: \(populationCovariance)")
///   ```
///
/// - Important:
///   - Ensure that `x` and `y` arrays have the same length.
///   - Ensure that both arrays are not empty to perform meaningful calculations.
public func covariance<T: Real>(_ x: [T], _ y:[T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return covarianceP(x, y)
        default:
            return covarianceS(x, y)
    }
}


