//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// Computes the numerical derivative of a function at a given point.
///
///
/// - Parameters:
///	- function: The function for which the derivative is to be computed.
///	- x: The point at which the derivative is to be calculated.
///	- h: The step size used for computing the derivative. Defaults to `1/1,000,000`.
///
/// - Returns: The numerical derivative of the function at the specified point.

func derivative<T: Real>(of function: @escaping (T) -> T, at x: T, h: T = T(1) / T(1000000)) -> T {
	return ((function(x + h) - function(x)) / h)
}
