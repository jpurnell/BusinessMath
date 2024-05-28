//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// Finds the root of a given function using the Goal Seek method.
///
/// - Parameters:
///    - function: The function for which the root is to be found.
///    - target: The value which the function should equal at the root.
///    - guess: An initial guess for the root.
///    - tolerance: The tolerance within which the result is acceptable. Defaults to `1/1,000,000`.
///    - maxIterations: The maximum number of iterations to attempt. Defaults to 100.
///
/// - Throws: `GoalSeekError.divisionByZero` if the function's derivative is zero, leading to a division by zero.
/// 		  `GoalSeekError.convergenceFailed` if the method fails to converge within the maximum iterations.
///
/// - Returns: The value of `x` such that `function(x)` is approximately equal to the `target` within the provided tolerance
///
/// ** Usage Example **
/// ///	```swift
///	let discountRate = 0.1
///	let cashFlows = [-1000, 200, 300, 400, 500]
///	let result = try goalSeek(function: { x in x * x }, target: 4.0, guess: 25, tolerance: 0.0000001, maxIterations: 100)
///	print(result)  ///	 prints the result
///	```
///


func goalSeek<T: Real>(function: @escaping (T) -> T, target: T, guess: T, tolerance: T = T(1) / T(1000000), maxIterations: Int = 1000) throws -> T {
	var x0 = guess
	var iteration = 0
	
	for _ in 0..<maxIterations {
		let f0 = function(x0)
		if abs(f0 - target) < tolerance {
			return x0
		}
		
		let dfx0 = derivative(of: function, at: x0)
		
		if dfx0 == 0 {
			throw GoalSeekError.divisionByZero
		}
		
		x0 = x0 - (f0 - target) / dfx0
		iteration += 1
	}
	throw GoalSeekError.convergenceFailed
}



