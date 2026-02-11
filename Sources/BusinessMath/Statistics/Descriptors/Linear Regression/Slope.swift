//
//  Slope.swift
//
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/// Computes the slope of the best-fit line for a given set of x and y values using linear regression.
///
/// The slope is calculated as part of the linear regression equation `y = mx + c`, where `m` is the slope and `c` is the y-intercept.
///
/// - Parameters:
///	- xValues: An array of x-coordinate values.
///	- yValues: An array of y-coordinate values.
///
/// - Returns: The slope of the best-fit line.
///
/// - Note:
///   - This function assumes that the `average(_:)` function is defined elsewhere, which calculates the mean of an array of values.
///   - The function also assumes the presence of a `multiplyVectors(_:_:)` function to perform element-wise multiplication of two arrays.
///
/// - Requires:
///   - Implementation of the `average(_:)` function to compute the mean of an array of values.
///   - Implementation of the `multiplyVectors(_:_:)` function to perform element-wise multiplication of two arrays.
///
/// - Example:
///   ```swift
///   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let yVals: [Double] = [2.0, 3.0, 5.0, 7.0, 11.0]
///   let slopeValue = slope(xVals, yVals)
///   print("Slope of the best-fit line: \(slopeValue)")
///   ```
///
/// - Important:
///   - Ensure that `xValues` and `yValues` arrays have the same length to produce a meaningful linear regression.
///   - Ensure that the arrays are not empty to avoid division by zero errors in the underlying calculations.
public func slope<T: Real>(_ xValues: [T], _ yValues: [T]) throws -> T {
	guard xValues.count == yValues.count else { throw ArrayError.mismatchedLengths }
	let sum1 = average(try multiplyVectors(yValues, xValues)) - average(xValues) * average(yValues)
	let sum2 = average(try multiplyVectors(xValues, xValues)) - T.pow(average(xValues), T(2))
	return sum1 / sum2
}
