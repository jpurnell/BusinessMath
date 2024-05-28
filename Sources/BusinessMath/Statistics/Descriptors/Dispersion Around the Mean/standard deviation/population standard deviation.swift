//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the population standard deviation for a given set of values.

 The population standard deviation is a measure of the dispersion of a set of data points from their mean. It is computed as the square root of the population variance.

 - Parameters:
	- values: An array of values for which the population standard deviation is to be calculated.

 - Returns: The population standard deviation of the given dataset.

 - Note:
   - This function uses the `varianceP(_:)` function to compute the population variance.

 - Requires:
   - Implementation of the `varianceP(_:)` function to compute the population variance.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let populationStandardDeviation = stdDevP(data)
   print("Population standard deviation: \(populationStandardDeviation)")
   ```

 - Important:
   - Ensure that the `values` array contains enough elements to perform meaningful standard deviation calculations.
 */
public func stdDevP<T: Real>(_ values: [T]) -> T {
	return T.sqrt(varianceP(values))
}

