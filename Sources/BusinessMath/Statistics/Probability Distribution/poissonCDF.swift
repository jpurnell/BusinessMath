//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) of the Poisson distribution.
///
/// The Poisson distribution is commonly used to model the number of events occurring within a fixed interval of time or space.
/// This function calculates the cumulative probability that the number of events will be less than or equal to a given value.
///
/// - Parameters:
///   - x: The number of occurrences for which the CDF is to be calculated. This must be a non-negative number.
///   - µ: The average number of occurrences in the given interval (mean of the Poisson distribution). This must be a non-negative number.
/// - Returns: The cumulative probability `P(X ≤ x)` where `X` is a Poisson random variable.
///
/// - Note: The input `x` is cast to a `Double` and then floored to obtain the integer part for calculations. The function sums the probabilities
///   for values from `0` to `floor(x)` to obtain the cumulative distribution function. It uses the exponential function and the power function to
///   calculate each term in the sum and the factorial function to normalize the probability.
///
/// - Example:
///   ```swift
///

public func poissonCDF<T: Real>(_ x: T, µ: T) -> T {
	guard x >= 0 else { return T(0) }
	let dx: Double = x as! Double
	let floor: Int = Int(floor(dx))
	return T.exp(-1 * µ) * (0...floor).map({T.pow(µ, T($0)) / T($0.factorial())}).reduce(T(0), +)
}
