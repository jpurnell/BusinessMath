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
///    - maxIterations: The maximum number of iterations to attempt. Defaults to 1000.
///
/// - Throws: `BusinessMathError.divisionByZero` if the function's derivative is zero.
/// 		  `BusinessMathError.calculationFailed` if the method fails to converge within the maximum iterations.
///
/// - Returns: The value of `x` such that `function(x)` is approximately equal to the `target` within the provided tolerance
///
/// ** Usage Example **
/// ///	```swift
///	let discountRate = 0.1
///	let cashFlows = [-1000, 200, 300, 400, 500]
///	let result = try goalSeek(function: { x in x * x }, target: 4.0, guess: 25, tolerance: 0.0000001, maxIterations: 1000)
///	print(result)  ///	 prints the result
///	```
public func goalSeek<T: Real>(function: @escaping (T) -> T, target: T, guess: T, tolerance: T = T(1) / T(1000000), maxIterations: Int = 1000) throws -> T {
	var x0 = guess
	var iteration = 0
	
	for _ in 0..<maxIterations {
		let f0 = function(x0)
		if abs(f0 - target) < tolerance {
			return x0
		}
		
		let dfx0 = derivative(of: function, at: x0)

		if dfx0 == 0 {
			throw BusinessMathError.divisionByZero(
				context: "Goal Seek at iteration \(iteration): derivative is zero at x=\(x0)"
			)
		}

		x0 = x0 - (f0 - target) / dfx0
		iteration += 1
	}
	throw BusinessMathError.calculationFailed(
		operation: "Goal Seek",
		reason: "Failed to converge to target \(target) within \(maxIterations) iterations",
		suggestions: [
			"Try a different initial guess (current: \(guess))",
			"Increase maxIterations (current: \(maxIterations))",
			"Relax the tolerance (current: \(tolerance))",
			"Check if the function actually has a solution for the target value",
			"Verify the function is continuous near the solution"
		]
	)
}



