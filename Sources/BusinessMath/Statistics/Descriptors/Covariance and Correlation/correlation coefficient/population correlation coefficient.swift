//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the population correlation coefficient (Pearson's correlation coefficient) for two datasets.

 The population correlation coefficient measures the strength and direction of the linear relationship between two variables. It is calculated as the covariance of the two variables divided by the product of their population standard deviations.

 - Parameters:
	- x: An array of values representing the first dataset.
	- y: An array of values representing the second dataset.

 - Returns: The population correlation coefficient for the two given datasets.

 - Note:
   - This function assumes the presence of the `covarianceP(_:_:)` and `stdDev(_:_:)` functions for computing the population covariance and population standard deviation, respectively.
   - Ensure both input arrays have the same length for a meaningful correlation computation.

 - Requires:
   - Implementation of the `covarianceP(_:_:)` function to compute the population covariance.
   - Implementation of the `stdDev(_:_:)` function to compute the population standard deviation.

 - Example:
   ```swift
   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let yVals: [Double] = [5.0, 4.0, 3.0, 2.0, 1.0]
   let correlation = correlationCoefficientP(xVals, yVals)
   print("Population correlation coefficient: \(correlation)")
   ```

 - Important:
   - Ensure that `x` and `y` arrays have the same length.
   - Ensure that both arrays are not empty to perform meaningful calculations.
 */
public func correlationCoefficientP<T: Real>(_ x: [T], _ y: [T]) -> T {
	let numerator = covarianceP(x, y)
	let denominator = (stdDev(x, .population) * stdDev(y, .population))
	let r = numerator / denominator
	return r
}

