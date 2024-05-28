//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Generates a single random number from a normal (Gaussian) distribution with a specified mean and standard deviation using the Box-Muller transform.

 This function relies on the Box-Muller transform to generate standard normally distributed values and scales them according to the specified mean and standard deviation.

 - Parameters:
	- mean: The mean of the normal distribution. Defaults to 0.
	- stdDev: The standard deviation of the normal distribution. Defaults to 1.

 - Returns: A value distributed according to the normal distribution with the given mean and standard deviation.

 - Note:
   - The function `boxMullerSeed` is used internally to generate the standard normally distributed values.

 - Example:
   ```swift
   let normalValue = boxMuller(mean: 5.0, stdDev: 2.0)
   ```

 - Requires: Appropriate implementation of the function `boxMullerSeed` to generate standard normal values.
 */
public func boxMuller<T: Real>(mean: T = T(0), stdDev: T = T(1)) -> T {
	return (stdDev * boxMullerSeed().z1) + mean
}

/**
 Generates a single random number from a normal (Gaussian) distribution with a specified mean and variance using the Box-Muller transform.

 This function relies on the Box-Muller transform to generate standard normally distributed values and scales them according to the specified mean and variance.

 - Parameters:
	- mean: The mean of the normal distribution. Defaults to 0.
	- variance: The variance of the normal distribution. Defaults to 1.

 - Returns: A value distributed according to the normal distribution with the given mean and variance.

 - Note:
   - The function `boxMullerSeed` is used internally to generate the standard normally distributed values.

 - Example:
   ```swift
   let normalValue = boxMuller(mean: 5.0, stdDev: 2.0)
   ```

 - Requires: Appropriate implementation of the function `boxMullerSeed` to generate standard normal values.
 */
public func boxMuller<T: Real>(mean: T, variance: T) -> T {
	return boxMuller(mean: mean, stdDev: T.sqrt(variance))
}
