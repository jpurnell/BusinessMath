//
//  identricMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

/// Provides the identric mean: https://www.johndcook.com/blog/2024/01/06/integral-representations-of-means/
	
/// Computes the identric mean of two positive numbers.
///
/// The identric mean is a special mean of two numbers, which is defined for positive values.
/// It is used in various mathematical contexts and has specific properties that make it useful in certain conditions.
///
/// - Parameters:
///   - x: The first positive value.
///   - y: The second positive value.
/// - Returns: The identric mean of `x` and `y`.
///
/// - Note: The function computes the identric mean using the formula:
///   \[ M_I(x, y) = \frac{1}{e} \left( \frac{y^y}{x^x} \right)^{\frac{1}{y - x}} \]
///   where \( e \) is the base of the natural logarithm (approximately 2.71828).
///
/// - Example:
///   ```swift
///   let x: Double = 3.0
///   let y: Double = 4.0
///   let result = identricMean(x, y)
///   // result should be the identric mean of x and y
public func identricMean<T: Real>(_ x: T, _ y: T) -> T {
	// Handle the case where x == y
	if x == y {
		return x
	}
	return T.exp((y * T.log(y) - x * T.log(x))/(y - x) - 1)
}

