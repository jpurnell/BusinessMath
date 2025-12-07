//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import Foundation
import Numerics

/**
 Computes the linear regression equation `y = mx + c` for a given set of x and y values.

 The linear regression function computes the best-fit line that minimizes the sum of squared residuals between the observed values and the values predicted by the line.

 - Parameters:
	- xValues: An array of x-coordinate values.
	- yValues: An array of y-coordinate values.

 - Throws:
   - `ArrayError.mismatchedLengths` if the lengths of `xValues` and `yValues` arrays do not match.
   - `ArrayError.emptyArray` if either `xValues` or `yValues` arrays are empty.

 - Returns: A function `(T) -> T` representing the linear regression equation, where `y = mx + c`.

 - Note:
   - This function assumes that the `slope(_:_:)` and `intercept(_:_:)` functions are defined elsewhere.

 - Requires:
   - Implementation of the `slope(_:_:)` function to calculate the slope of the best-fit line.
   - Implementation of the `intercept(_:_:)` function to calculate the y-intercept of the best-fit line.

 - Example:
   ```swift
   let xVals: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
   let yVals: [Double] = [2.0, 3.0, 5.0, 7.0, 11.0]
   do {
	   let linearFunc = try linearRegression(xVals, yVals)
	   print("Predicted value at x = 6.0: \(linearFunc(6.0))")
   } catch {
	   print("Error in linear regression calculation: \(error)")
   }
   ```

 - Important:
   - Ensure that `xValues` and `yValues` arrays have the same length to produce a meaningful linear regression.
   - Ensure that the arrays are not empty to perform meaningful statistical computations.
 */

public func linearRegression<T: Real>(_ xValues: [T], _ yValues: [T]) throws -> (T) -> T {
	guard xValues.count == yValues.count else { throw ArrayError.mismatchedLengths }
	guard !xValues.isEmpty || !yValues.isEmpty else { throw ArrayError.emptyArray }
	
	let slope = try slope(xValues, yValues)
    let intercept = try! intercept(xValues, yValues)
		//    print("Slope:\t\(slope)")
		//    print("Intercept:\t\(intercept)")
    return { x in intercept + slope * x}
}
