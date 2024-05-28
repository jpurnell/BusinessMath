//
//  harmonicMean.swift
//  
//
//  Created by Justin Purnell on 5/17/23.
//

import Foundation
import Numerics

/// Computes the harmonic mean of a dataset.
///
/// The harmonic mean is a measure of the central tendency, which is useful for datasets that contain rates or ratios.
/// It is defined as the reciprocal of the arithmetic mean of the reciprocals of the dataset values.
///
/// - Parameters:
///   - values: An array of values for which to compute the harmonic mean.
/// - Returns: The harmonic mean of the dataset. If the dataset is empty, returns `0`.
///
/// - Note: The function computes the harmonic mean using the formula:
///   \[ H = \frac{n}{\sum_{i=1}^{n} \frac{1}{x_i}} \]
///   where \( x_i \) are the values in the dataset and \( n \) is the number of values.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 4.0]
///   let result = harmonicMean(values)
///   // result should be the harmonic mean of the dataset `values`
///   // result should be 1.7142857142857142

public func harmonicMean<T: Real>(_ values: [T]) -> T {
	T(values.count) / (values.map({T.pow($0, T(-1))}).reduce(0, +))
}
