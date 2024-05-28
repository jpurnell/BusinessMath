//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the sample standard deviation for a given set of values.

 The sample standard deviation is a measure of the dispersion of a set of data points from their mean. It is computed as the square root of the sample variance.

 - Parameters:
	- values: An array of values for which the sample standard deviation is to be calculated.

 - Returns: The sample standard deviation of the given dataset.

 - Note:
   - This function uses the `varianceS(_:)` function to compute the sample variance.

 - Requires:
   - Implementation of the `varianceS(_:)` function to compute the sample variance.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let sampleStandardDeviation = stdDevS(data)
   print("Sample standard deviation: \(sampleStandardDeviation)")
   ```

 - Important:
   - Ensure that the `values` array contains enough elements (typically at least two) to perform meaningful standard deviation calculations.
   - Equivalent of Excel STDEV(xx:xx)
 */

public func stdDevS<T: Real>(_ values: [T]) -> T {
	return T.sqrt(varianceS(values))
}
