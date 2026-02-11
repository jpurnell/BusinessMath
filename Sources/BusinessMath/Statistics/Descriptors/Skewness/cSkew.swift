//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Advanced Descriptors
/// Computes the coefficient of skewness based on the mean, median, and standard deviation of a dataset.
///
/// The coefficient of skewness provides a measure of the asymmetry of the probability distribution of a real-valued random variable about its mean.
/// This measure can be especially useful when the median, mean, and standard deviation of the dataset are known.
/// Advanced Descriptors give us a better sense of the "shape" of the overall data, helping us understand if outliers are making our basic descriptors not tell the whole story. Skew helps us identify cases where maybe most results are on one side of the average, but a really big outlier on the other side of the average is changing the numbers (e.g. 999 observations of 1, but one observation of 100,000 makes your average 1,001)
///
/// - Parameters:
///   - mean: The mean (average) of the dataset.
///   - median: The median value of the dataset.
///   - stdDev: The standard deviation of the dataset.
/// - Returns: The coefficient of skewness. A positive value indicates that the data are skewed to the right (longer tail on the right side), a negative value indicates that the data are skewed to the left (longer tail on the left side), and a value of zero indicates that the data are symmetrically distributed.
///
/// - Note: The function uses the formula:
///   \[ \text{coefficient of skewness} = \frac{3 (\text{mean} - \text{median})}{\text{standard deviation}} \]
///
/// - Example:
///   ```swift
///   let mean: Double = 5.0
///   let median: Double = 4.0
///   let stdDev: Double = 1.5
///   let result = coefficientOfSkew(mean: mean, median: median, stdDev: stdDev)
///   // result should be the coefficient of skewness given the mean, median, and standard deviation

public func coefficientOfSkew<T: Real>(mean: T, median: T, stdDev: T) -> T {
    return (T(3) * (mean - median))/stdDev
}

/// Computes the coefficient of skewness for a given set of values.
///
/// The coefficient of skewness measures the asymmetry of the probability distribution of a real-valued random variable about its mean. A skewness value greater than 0 indicates a distribution with a longer right tail, and a value less than 0 indicates a distribution with a longer left tail.
///
/// - Parameters:
///	- values: An array of values for which the coefficient of skewness is to be calculated.
///
/// - Returns: The coefficient of skewness for the given dataset.
///
/// - Note:
///   - The function relies on the calculation of the mean, median, and standard deviation of the provided values, using the `mean(_:)`, `median(_:)`, and `stdDev(_:)` functions respectively.
///
/// - Requires:
///   - Implementation of the `mean(_:)`, `median(_:)`, and `stdDev(_:)` functions to compute the necessary statistics for the skewness calculation.
///
/// - Example:
///   ```swift
///   let data: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let skewness = coefficientOfSkew(data)
///   ```
///
/// - Important:
///   - Ensure that the provided `values` array is not empty to avoid division by zero errors in the underlying statistical computations.
public func coefficientOfSkew<T: Real>(_ values: [T]) throws -> T {
	guard !values.isEmpty else { throw ArrayError.emptyArray }
    return coefficientOfSkew(mean: mean(values), median: median(values), stdDev: stdDev(values))
}
