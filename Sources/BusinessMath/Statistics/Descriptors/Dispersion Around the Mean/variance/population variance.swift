//
//  population variance.swift
//
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

// MARK: - The variance, when we have the entire population of values and not a sample, is the Sum of Squared Average Difference, averaged over the total number of observations
///Computes the population variance for a given set of values.
///
/// The population variance is a measure of the dispersion of a set of data points. It is calculated as the sum of squared differences from the mean divided by the number of data points.
///
/// - Parameters:
///	- values: An array of values for which the population variance is to be calculated.
///
/// - Returns: The population variance of the given dataset.
///
/// - Note:
///   - This function uses the formula `σ^2 = Σ((x - μ)^2) / n`, where `n` is the number of data points and `μ` is the mean of the dataset.
///   - The function `sumOfSquaredAvgDiff(_:)` is assumed to be defined elsewhere, which computes the sum of squared differences from the mean.
///
/// - Requires:
///   - Implementation of the `sumOfSquaredAvgDiff(_:)` function to compute the necessary sum of squared differences.
///
/// - Example:
///   ```swift
///   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let populationVariance = varianceP(data)
///   print("Population variance of the data: \(populationVariance)")
///   ```
///
/// - Important:
///   - Ensure that the `values` array is not empty to perform meaningful variance computation.
///   - Equivalent of Excel VARP(xx:xx)

public func varianceP<T: Real>(_ values: [T]) -> T {
	return sumOfSquaredAvgDiff(values)/T(values.count)
}
