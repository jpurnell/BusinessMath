//
//  Katz's Statistic.swift
//  
//
//  Created by Justin Purnell on 1/19/24.
//

import Foundation
import Numerics

// From Katz L (1965) United treatment of a broad class of discrete probability distributions. in Proceedings of the International Symposium on Discrete Distributions. Montreal

/// Computes Katz's Statistic for a dataset.
///
/// Katz's Statistic is used to measure the relative variability of a dataset. It utilizes both the variance and the mean of the dataset to provide an indication of the dataset's dispersion relative to its mean.
///
/// - Parameters:
///   - values: An array of values for which to compute Katz's Statistic.
/// - Returns: Katz's Statistic for the dataset. Returns `0` if the dataset is empty or the mean is zero to avoid division by zero.
///
/// - Note: The function computes Katz's Statistic using the formula:
///   \[ K = \sqrt{\frac{n}{2}} \frac{\text{Var}(X) - \bar{X}}{\bar{X}} \]
///   where \( n \) is the number of values, \( \text{Var}(X) \) is the variance of the values, and \( \bar{X} \) is the mean of the values.
///
/// - Example:
///   ```swift
///   let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
///   let result = katzsStatistic(values)
///   // result should be Katz's Statistic for the dataset `values`

public func katzsStatistic<T: Real>(_ values: [T]) -> T {
	return T.sqrt(T(values.count) / T(2)) * (variance(values) - mean(values)) / mean(values)
}
