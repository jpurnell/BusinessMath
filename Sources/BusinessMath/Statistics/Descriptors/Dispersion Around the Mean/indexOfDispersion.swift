//
//  File.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

/**
 Computes the index of dispersion (also known as the variance-to-mean ratio) for a given set of values.

 The index of dispersion is a measure used in statistics to quantify the dispersion (spread) of a probability distribution. It is calculated as the ratio of the variance to the mean of the dataset.

 - Parameters:
	- values: An array of values for which the index of dispersion is to be calculated.

 - Returns: The index of dispersion, calculated as the ratio of the variance to the mean of the values.

 - Note:
   - The mean should not be zero to avoid division by zero errors.

 - Requires:
   - Implementation of the `variance(_:)` and `mean(_:)` functions to compute the necessary statistics for the index of dispersion calculation.

 - Example:
   ```swift
   let data: [Double] = [2.0, 4.0, 6.0, 8.0, 10.0]
   let dispersionIndex = indexOfDispersion(data)
   ```

 - Important:
   - Ensure that the provided `values` array is not empty to perform meaningful statistical computations.
   - Ensure the mean of the dataset is not zero to avoid division by zero errors.
 */

public func indexOfDispersion<T: Real>(_ values: [T]) throws -> T {
	let mean = mean(values)
	guard mean != 0 else { throw BusinessMathError.divisionByZero(context: "Index of Dispersion") }
	return variance(values) / mean
}
