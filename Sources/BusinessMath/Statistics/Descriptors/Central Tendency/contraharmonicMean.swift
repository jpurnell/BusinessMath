//
//  contraharmonicMean.swift
//  
//
//  Created by Justin Purnell on 1/6/24.
//

import Foundation
import Numerics

///Provides the contraharmonic mean, i.e. the ratio of the sum of squares to the sum: https://www.johndcook.com/blog/2023/05/20/contraharmonic-mean/

public func contraharmonicMean<T: Real>(_ x: T, _ y: T) -> T {
	return (T.pow(x, T(2)) + T.pow(y, T(2))) / (x + y)
}

/// Computes the contraharmonic mean of a dataset.
///
/// The contraharmonic mean is a type of average, computed as the ratio of the sum of the squares of the values to the sum of the values.
///
/// - Parameters:
///   - values: An array of values for which to compute the contraharmonic mean.
/// - Returns: The contraharmonic mean of the dataset.
///
/// - Note: The function computes the contraharmonic mean using the formula:
///   \[ C = \frac{\sum_{i=1}^{n} x_i^2}{\sum_{i=1}^{n} x_i} \]
///   where \( x_i \) are the values in the dataset and \( n \) is the number of values.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = contraharmonicMean(values)
///   // result should be the contraharmonic mean of the dataset `values`

public func contraharmonicMean<T: Real>(_ values: [T]) -> T {
	return values.map({T.pow($0, T(2))}).reduce(0, +) / values.reduce(0, +)
}

