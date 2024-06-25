//
//  exponentialPDF.swift
//  
//
//  Created by Justin Purnell on 5/19/24.
//

import Foundation
import Numerics


/// Computes the value of the exponential distribution's probability density function (PDF).
///
/// The exponential distribution is often used to model the time between independent events that occur at a constant average rate.
/// This function calculates the probability density at a given point `x` for an exponential distribution with the specified rate parameter `λ`.
///
/// - Parameters:
///   - x: The value at which to evaluate the probability density function. This must be a non-negative number.
///   - λ: The rate parameter of the exponential distribution. This must be a positive number.
/// - Returns: The value of the exponential probability density function at `x`. Returns `0` if `x` is negative.
///
/// - Note: The function follows the formula for the exponential PDF:
///   \[ f(x; \lambda) = \lambda e^{-\lambda x} \]
///   where `λ` is the rate parameter and `x` is a non-negative number.
///
/// - Example:
///   ```swift
///   let result = exponentialPDF(2.0, λ: 0.5)
///   // result should be the probability density of x = 2 for the exponential distribution with rate parameter λ = 0.5

public func exponentialPDF<T: Real>(_ x: T, λ: T) -> T {
	guard x >= 0 else { return 0 }
	return λ * T.exp(T(-1) * λ * x)
}
