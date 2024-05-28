//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the population covariance for two datasets.

 Population covariance is a measure of how much two variables change together, evaluated across the entire population.

 - Parameters:
	- x: An array of values representing the first dataset.
	- y: An array of values representing the second dataset.

 - Returns: The population covariance for the two given datasets. If the lengths of `x` and `y` do not match, it returns 0.

 - Note:
   - This function assumes the presence of the `mean(_:)` function for computing the mean of an array.
   - Ensure both input arrays have the same length for meaningful covariance computation.

 - Requires:
   - Implementation of the `mean(_:)` function to compute the mean.

 - Example:
   ```swift
   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let yVals: [Double] = [5.0, 4.0, 3.0, 2.0, 1.0]
   let populationCovariance = covarianceP(xVals, yVals)
   print("Population covariance: \(populationCovariance)")
   ```

 - Important:
   - Ensure that `x` and `y` arrays have the same length.
   - Ensure that both arrays are not empty to perform meaningful calculations.
 */
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

