//
//  variance.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/**
 Computes the variance for a given set of values, either as a sample variance or as a population variance.

 The function can calculate either the sample variance or the population variance based on the specified population type. By default, it computes the sample variance.

 - Parameters:
	- values: An array of values for which the variance is to be calculated.
	- pop: An enumeration value of type `Population` indicating whether to calculate the sample variance or population variance. Defaults to `.sample`.

 - Returns: The variance of the given dataset, either as a sample variance or population variance.

 - Enum Population:
   - `sample`: Indicates that the function should calculate the sample variance.
   - `population`: Indicates that the function should calculate the population variance.

 - Note:
   - This function uses the `varianceS(_:)` function to compute sample variance and the `varianceP(_:)` function to compute population variance.

 - Requires:
   - Implementation of the `varianceS(_:)` function to compute sample variance.
   - Implementation of the `varianceP(_:)` function to compute population variance.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let sampleVariance = variance(data, .sample)
   let populationVariance = variance(data, .population)
   print("Sample variance: \(sampleVariance)")
   print("Population variance: \(populationVariance)")
   ```

 - Important:
   - Ensure that the `values` array contains enough elements to perform meaningful variance calculations, typically at least two for sample variance.
 */
public func variance<T: Real>(_ values: [T], _ pop: Population = .sample) -> T {
    switch pop {
        case .population:
            return varianceP(values)
        default:
            return varianceS(values)
    }
}

