//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/19/24.
//

import Foundation
import Numerics

/// Computes the cumulative distribution function (CDF) of the exponential distribution.
///
/// The exponential distribution is often used to model the time between independent events that occur at a constant average rate.
/// This function calculates the cumulative probability that an exponentially distributed random variable is less than or equal to a given value `x`
/// for the specified rate parameter `λ`.
///
/// - Parameters:
///   - x: The value at which to evaluate the cumulative distribution function. This must be a non-negative number.
///   - λ: The rate parameter of the exponential distribution. This must be a positive number.
/// - Returns: The cumulative probability `P(X ≤ x)` where `X` is an exponential random variable. Returns `0` if `x` is negative.
///
/// - Note: The function follows the formula for the exponential CDF:
///   \[ F(x; \lambda) = 1 - e^{-\lambda x} \]
///   where `λ` is the rate parameter and `x` is a non-negative number.
///
/// - Example:
///   ```swift
///   let result = exponentialCDF(2.0, λ: 0.5)
///   // result should be the cumulative probability of x = 2 for the exponential distribution with rate parameter λ = 0.5

public func exponentialCDF<T: Real>(_ x: T, λ: T) -> T {
	guard x >= 0 else { return 0 }
	return T(1) - T.exp(T(-1) * λ * x)
}

