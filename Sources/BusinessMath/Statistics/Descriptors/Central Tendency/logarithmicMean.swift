//
//  logarithmicMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

/// Provides the logarithmic mean: https://www.johndcook.com/blog/2024/01/06/integral-representations-of-means/

/// Computes the logarithmic mean of two positive numbers.
///
/// The logarithmic mean is a special type of mean that is particularly useful in various fields such as thermodynamics and fluid mechanics. It is defined for two positive numbers and provides a way to interpolate between the two values using their natural logarithms.
///
/// - Parameters:
///   - x: The first positive value.
///   - y: The second positive value.
/// - Returns: The logarithmic mean of `x` and `y`. If `x` and `y` are equal, the function returns `x` to handle the edge case where the logarithmic difference would be undefined.
///
/// - Note: The function computes the logarithmic mean using the formula:
///   \[ L(x, y) = \frac{y - x}{\ln(y) - \ln(x)} \]
///   where \( \ln \) denotes the natural logarithm.
///
/// - Example:
///   ```swift
///   let x: Double = 3.0
///   let y: Double = 4.0
///   let result = logarithmicMean(x, y)
///   // result should be the logarithmic mean of x and y

public func logarithmicMean<T: Real>(_ x: T, _ y: T) -> T {
	return (y - x) / (T.log(y) - T.log(x))
}
