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
/// The geometric mean is a measure of central tendency, defined as the nth root of the product of n values. It is especially useful for data that grows exponentially and when dealing with percentages, ratios, and normalized data. The geometric mean is most often used to calculate the average percentage growth rate over time of some given series.
///
/// - Parameters:
///   - values: An array of values for which to compute the geometric mean.
/// - Returns: The geometric mean of the dataset. If the dataset is empty, returns NaN.
///
/// - Note: The function computes the geometric mean using the logarithmic formula for numerical stability:
///   \[ G = \exp\left(\frac{1}{n}\sum_{i=1}^{n} \ln(x_i)\right) \]
///   This avoids overflow/underflow that would occur with direct multiplication of large datasets.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = geometricMean(values)
///   // result should be the geometric mean of the dataset `values`
///   // result should be approximately 2.605171

public func geometricMean<T: Real>(_ values: [T]) -> T {
    // Empty array returns NaN
    guard !values.isEmpty else {
        return T.nan
    }

    // Single element returns itself (avoids log/exp precision loss)
    if values.count == 1 {
        return values[0]
    }

    // NaN propagates
    if values.contains(where: { $0.isNaN }) {
        return T.nan
    }

    // Infinity propagates
    if values.contains(where: { $0.isInfinite }) {
        return T.infinity
    }

    // Zero in the dataset makes geometric mean zero
    if values.contains(where: { $0 == T(0) }) {
        return T(0)
    }

    // Negative values make geometric mean undefined (NaN)
    if values.contains(where: { $0 < T(0) }) {
        return T.nan
    }

    // Use logarithmic formula to avoid overflow: exp(mean(log(values)))
    let logValues = values.map { T.log($0) }
    let meanLog = mean(logValues)
    return T.exp(meanLog)
}
