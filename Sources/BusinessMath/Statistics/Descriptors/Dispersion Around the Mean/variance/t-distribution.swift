//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the variance using the t-distribution for small sample sizes, specifically for samples with fewer than 30 degrees of freedom.

 For samples of under 30 degrees of freedom, the t-distribution provides a more accurate sample variance compared to the z-distribution (normal distribution), which can overfit. If there are more than 30 samples, it falls back to using the standard variance calculation.

 - Parameters:
	- values: An array of values for which the variance using the t-distribution is to be calculated.

 - Returns: The variance of the given dataset using the t-distribution for small sample sizes. For larger sample sizes, it returns the usual variance.

 - Note:
   - This function switches to using the t-distribution when the sample size is 30 or less.
   - For sample sizes greater than 30, it calculates the variance using the standard variance function, assumed to be defined elsewhere as `variance(_:)`.

 - Requires:
   - Implementation of the `variance(_:)` function to compute standard variance for larger sample sizes.

 - Example:
   ```swift
   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let tDistVariance = varianceTDist(data)
   print("Variance using t-distribution: \(tDistVariance)")
   ```

 - Important:
   - Ensure that the `values` array contains enough elements to perform a meaningful variance calculation, typically at least two.
 */
public func varianceTDist<T: Real>(_ values: [T]) -> T {
	if values.count > 30 { return variance(values) }
	return (T(values.count - 1) / T(values.count - 3))
}

