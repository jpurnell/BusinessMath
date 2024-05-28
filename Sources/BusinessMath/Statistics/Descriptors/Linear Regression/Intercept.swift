//
//  File.swift
//  
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

/**
 Computes the y- of the best-fit line for a given set of x and y values.

 The y- is calculated as part of the linear regression equation `y = mx + c`, where `m` is the slope and `c` is the y-
.

 - Parameters:
	- xValues: An array of x-coordinate values.
	- yValues: An array of y-coordinate values.

 - Returns: The y- of the best-fit line.

 - Note:
   - This function assumes that the `slope(_:_:)` function is defined elsewhere, which calculates the slope of the best-fit line using the given x and y values.
   - The function also assumes the presence of an `average(_:)` function to compute the mean of an array of values.

 - Requires:
   - Implementation of the `slope(_:_:)` function to calculate the slope of the best-fit line.
   - Implementation of the `average(_:)` function to compute the mean of an array of values.

 - Example:
   ```swift
   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let yVals: [Double] = [2.0, 3.0, 5.0, 7.0, 11.0]
   let
Value =
(xVals, yVals)
 print("Y- of the best-fit line: \(Value)")
   ```

 - Important:
   - Ensure that `xValues` and `yValues` arrays have the same length to produce a meaningful linear regression.
   - Ensure that the arrays are not empty to avoid division by zero errors in the underlying calculations.
 */

public func intercept<T: Real>(_ xValues: [T], _ yValues: [T]) throws -> T {
	guard xValues.count == yValues.count else { throw ArrayError.mismatchedLengths }
	guard !xValues.isEmpty || !yValues.isEmpty else { throw ArrayError.emptyArray }
	return try average(yValues) - slope(xValues, yValues) * average(xValues)
}
