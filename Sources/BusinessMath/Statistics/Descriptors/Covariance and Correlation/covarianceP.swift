//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the population covariance between two datasets.
///
/// Covariance is a measure of the joint variability of two random variables. If the greater values of one variable correspond with the greater values of the other variable, and the same holds for the lesser values, the covariance is positive. In the opposite cases, the covariance is negative. A covariance of zero indicates that the variables are uncorrelated.
///
/// - Parameters:
///   - x: An array of values representing the first dataset.
///   - y: An array of values representing the second dataset.
/// - Returns: The population covariance of the two datasets. Returns `0` if the datasets have different lengths or if the length is zero.
///
/// - Note: The function computes the population covariance using the following formula:
///   \[ \text{Cov}(X, Y) = \frac{1}{n} \sum_{i=1}^{n} (x_i - \bar{x})(y_i - \bar{y}) \]
///   where \( n \) is the number of values, \( \bar{x} \) is the mean of \( x \), and \( \bar{y} \) is the mean of \( y \).
///
/// - Example:
///   ```swift
///   let xValues: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let yValues: [Double] = [2.0, 4.0, 6.0, 8.0, 10.0]
///   let result = covariancePopulation(x: xValues, y: yValues)
///   // result should be the population covariance of the datasets `xValues` and `yValues`

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
