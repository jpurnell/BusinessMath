//
//  multiply.swift
//
//
//  Created by Justin Purnell on 10/19/22.
//

import Foundation
import Numerics

/// Multiplies two vectors element-wise.
///
/// This function takes two arrays of the same length and returns a new array where each element is the product of the corresponding elements in the input arrays.
///
/// - Parameters:
///	- x: An array of values.
///	- y: An array of values, must be of the same length as `x`.
///
/// - Returns: An array containing the element-wise products of the input arrays.
///
/// - Throws:
///   - `ArrayError.mismatchedLengths` if the lengths of `x` and `y` arrays do not match.
///
/// - Note:
///   - Both `x` and `y` must have the same length for the element-wise multiplication to be valid.
///
/// - Example:
///   ```swift
///   let vector1: [Double] = [1.0, 2.0, 3.0]
///   let vector2: [Double] = [4.0, 5.0, 6.0]
///   let result = multiplyVectors(vector1, vector2)
///   print("Element-wise product: \(result)")
///   ```
///
/// - Important:
///   - Ensure that both input arrays, `x` and `y`, have the same length to avoid errors.
public func multiplyVectors<T: Real>(_ x: [T], _ y: [T]) throws -> [T] {
	guard x.count == y.count else { throw ArrayError.mismatchedLengths }
    return zip(x, y).map(*)
}
