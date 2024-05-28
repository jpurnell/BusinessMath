//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the sample correlation coefficient (Pearson's correlation coefficient) for two datasets.

 The sample correlation coefficient measures the strength and direction of the linear relationship between two variables in a sample. It is calculated as the covariance of the two variables divided by the product of their sample standard deviations.

 - Parameters:
	- x: An array of values representing the first dataset.
	- y: An array of values representing the second dataset.

 - Returns: The sample correlation coefficient for the two given datasets. If the lengths of `x` and `y` do not match, it returns 0.

 - Note:
   - This function assumes the presence of the `mean(_:)` function for computing the mean of an array.
   - Ensure both input arrays have the same length for meaningful correlation computation.

 - Requires:
   - Implementation of the `mean(_:)` function to compute the mean.

 - Example:
   ```swift
   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let yVals: [Double] = [5.0, 4.0, 3.0, 2.0, 1.0]
   let correlation = correlationCoefficientS(xVals, yVals)
   print("Sample correlation coefficient: \(correlation)")
   ```

 - Important:
   - Ensure that `x` and `y` arrays have the same length.
   - Ensure that both arrays are not empty to perform meaningful calculations.
 */
public func correlationCoefficientS<T: Real>(_ x:[T], _ y:[T]) -> T {
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
	return numerator / (T.sqrt(xDenom) * T.sqrt(yDenom))
}


