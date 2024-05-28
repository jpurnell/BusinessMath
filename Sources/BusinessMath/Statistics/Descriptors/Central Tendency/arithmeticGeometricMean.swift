//
//  arithmeticGeometricMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

/// Computes the Arithmetic-Geometric Mean (AGM) of a dataset.
///
/// The arithmetic-geometric mean (AGM) is a mathematical constant that arises in various contexts of number theory and analysis. It is defined as the common limit of two sequences, one arithmetic and one geometric, that start from a common pair of positive numbers.
///
/// - Parameters:
///   - x: An array of values for which to compute the arithmetic-geometric mean.
///   - tolerance: The number of iterations for achieving the desired precision. Defaults to `10000`.
/// - Returns: The arithmetic-geometric mean of the dataset.
///
/// - Note: The function uses an iterative algorithm to compute the AGM with specific tolerance:
///   1. Initialize `tempX` with the arithmetic mean of the dataset and `tempY` with the geometric mean of the dataset.
///   2. Iterate by updating `tempX` and `tempY` until the absolute difference between `tempX` and `tempY` is less than the specified tolerance.
///   3. Return the final value of `tempX` or `tempY` (they should be very close).
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 3.0, 5.0, 7.0, 9.0]
///   let result = arithmeticGeometricMean(values)
///   // result should be the arithmetic-geometric mean of the dataset `values`

public func arithmeticGeometricMean<T: Real>(_ x: [T], _ tolerance: Int = 10000) -> T {
    var tempX = mean(x)
    var tempY = geometricMean(x)
    while abs(tempX - tempY) > (T(1) / T(tolerance)) {
        let newTempX = mean([tempX, tempY])
        tempY = geometricMean([tempX, tempY])
        tempX = newTempX
    }
    return tempX
}

