//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Generates a logistic distribution value based on the specified mean and standard deviation.

 The logistic distribution is useful for modeling growth and logistic regression. It's similar to the normal distribution but has heavier tails.

 - Parameters:
	- p: A probability value between 0 and 1 (exclusive) for which the logistic distribution value is to be computed.
	- mean: The mean of the logistic distribution. Defaults to 0.
	- stdDev: The standard deviation of the logistic distribution. Defaults to 1.

 - Returns: A value distributed according to the logistic distribution based on the specified mean and standard deviation.

 - Note:
   - The input parameter `p` should be in the open interval (0, 1). Values outside this range will result in mathematical errors.
   - The constant `magicNumber` is derived as `sqrt(3) / π` which is used to scale the standard deviation.

 - Requires: The use of appropriate `Real` compatible number types for accurate results.
 */

func distributionLogistic<T: Real>(_ p: T = distributionUniform(), _ mean: T = 0, _ stdDev: T = 1) -> T {
	let magicNumber = T.sqrt(3) / T.pi
	return mean + magicNumber * stdDev * T.log(p / (1 - p))
}
