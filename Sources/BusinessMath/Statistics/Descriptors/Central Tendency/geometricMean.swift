//
//  geometricMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

/// Computes the geometric mean of a dataset.
///
/// The geometric mean is a measure of central tendency, defined as the nth root of the product of n values. It is especially useful for data that grows exponentially and when dealing with percentages, ratios, and normalized data.
///
/// - Parameters:
///   - values: An array of values for which to compute the geometric mean.
/// - Returns: The geometric mean of the dataset. If the dataset is empty, returns 1.
///
/// - Note: The function computes the geometric mean using the formula:
///   \[ G = \left(\prod_{i=1}^{n} x_i\right)^{\frac{1}{n}} \]
///   where \( x_i \) are the values in the dataset and \( n \) is the number of values.
///   The product of the values is computed using `reduce(T(1), *)` and then raised to the power of \(\frac{1}{n}\).
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = geometricMean(values)
///   // result should be the geometric mean of the dataset `values`
///   // result should be approximately 2.605171

public func geometricMean<T: Real>(_ values: [T]) -> T {
    return T.pow(values.reduce(T(1), *), T(1) / T(values.count))
}
