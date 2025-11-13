//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

// When we are working with a subset (sample) of the total number of observations, we use the sum of squared average differences, but divide it by one fewer than the number of observations. If there are fewer than 30 observations in the sample, we use the T-Distribution of the Variance (varianceTDist)

/**
 Computes the sample variance for a given set of values.

 The sample variance is a measure of the dispersion of a set of data points. It is calculated as the sum of squared differences from the mean divided by the number of degrees of freedom.

 - Parameters:
	- values: An array of values for which the sample variance is to be calculated.

 - Returns: The sample variance of the given dataset.

 - Note:
   - This function uses the formula `s^2 = Σ((x - μ)^2) / (n - 1)`, where `n` is the number of data points and `μ` is the mean of the dataset.
   - The function `sumOfSquaredAvgDiff(_:)` is assumed to be defined elsewhere, which computes the sum of squared differences from the mean.

 - Requires:
   - Implementation of the `sumOfSquaredAvgDiff(_:)` function to compute the necessary sum of squared differences.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let sampleVariance = varianceS(data)
   print("Sample variance of the data: \(sampleVariance)")
   ```

 - Important:
   - Ensure that the `values` array contains at least two elements to perform the sample variance calculation as the formula relies on degrees of freedom (n - 1).
   - Equivalent of Excel VAR(xx:xx)
 */
public func varianceS<T: Real>(_ values: [T]) -> T {
	guard values.count > 1 else {
		return T(0)
	}
	let degreesOfFreedom = values.count - 1
	return sumOfSquaredAvgDiff(values)/T(degreesOfFreedom)
}
