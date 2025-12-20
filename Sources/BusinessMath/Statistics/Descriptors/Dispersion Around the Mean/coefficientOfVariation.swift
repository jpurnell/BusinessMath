//
//  coefficientOfVariation.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/**
 Computes the coefficient of variation (cVar) for a given standard deviation and mean.

 The coefficient of variation is a standardized measure of dispersion of a probability distribution or frequency distribution. It is often expressed as a percentage, representing the ratio of the standard deviation to the mean.

 - Parameters:
	- stdDev: The standard deviation of the dataset.
	- mean: The mean of the dataset.

 - Returns: The coefficient of variation as a percentage.

 - Note:
   - The coefficient of variation is undefined when the mean is zero, as it would result in a division by zero.

 - Requires:
   - The use of appropriate `Real` compatible number types for accurate results.

 - Example:
   ```swift
   let stdDev: Double = 15.0
   let mean: Double = 100.0
   let cv = coefficientOfVariation(stdDev, mean)
   print("Coefficient of Variation: \(cv)%")
   ```

 - Important:
   - Ensure that the mean is not zero to avoid division by zero errors.
 */

public func coefficientOfVariation<T: Real>(_ stdDev: T, mean: T) throws -> T {
	guard mean != 0 else { throw BusinessMathError.divisionByZero(context: "Coefficient of Variation") }
    return (stdDev / mean) * T(100)
}


