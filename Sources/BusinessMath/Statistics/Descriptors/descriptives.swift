//
//  descriptives.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/**
 Computes various descriptive statistics for a given set of values.

 This function calculates the mean, standard deviation, skewness, and coefficient of variation for the provided dataset.

 - Parameters:
	- values: An array of values for which the descriptive statistics are to be calculated.

 - Throws:
	- `ArrayError.emptyArray` if the input array `values` is empty.

 - Returns: A tuple containing the mean, standard deviation, skewness, and coefficient of variation of the given dataset.
   - `mean`: The average of the dataset.
   - `stdDev`: The standard deviation of the dataset.
   - `skew`: The skewness of the dataset.
   - `cVar`: The coefficient of variation of the dataset.

 - Note:
   - Ensure the presence of the `mean(_:)`, `stdDev(_:)`, `coefficientOfSkew(_:)`, and `coefficientOfVariation(_:_:)` functions for computing the necessary statistics.

 - Requires:
   - Implementation of the `mean(_:)` function to compute the mean.
   - Implementation of the `stdDev(_:)` function to compute the standard deviation.
   - Implementation of the `coefficientOfSkew(_:)` function to compute the skewness.
   - Implementation of the `coefficientOfVariation(_:_:)` function to compute the coefficient of variation.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   do {
	   let stats = try descriptives(data)
	   print("Mean: \(stats.mean)")
	   print("Standard Deviation: \(stats.stdDev)")
	   print("Skewness: \(stats.skew)")
	   print("Coefficient of Variation: \(stats.cVar)")
   } catch {
	   print("Error computing descriptive statistics: \(error)")
   }
   ```

 - Important:
   - Ensure that the `values` array is not empty to perform meaningful calculations.
 */
public func descriptives<T: Real>(_ values: [T]) throws -> (mean: T, stdDev: T, skew: T, cVar: T) {
	guard !values.isEmpty else { throw ArrayError.emptyArray }
    let mu = mean(values)
    let stDev = stdDev(values)
    let skew = try coefficientOfSkew(values)
    let coVar = try coefficientOfVariation(stDev, mean: mu)
    return (mu, stDev, skew, coVar)
}

extension Array where Element: Real {
    public var descriptiveStatistics: String {  let desc = try! descriptives(self.map({$0 as! Double})); return "µ:\(desc.mean)\t∂:\(desc.stdDev)\tsk:\(desc.skew)\tCv:\(desc.cVar)"}
}
