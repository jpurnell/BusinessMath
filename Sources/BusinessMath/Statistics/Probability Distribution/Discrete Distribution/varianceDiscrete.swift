//
//  varianceDiscrete.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the variance of a discrete probability distribution.
///
/// This function calculates the variance - a statistical measurement of the spread between numbers in a data set.
/// Variance measures how far each number in the set is from the mean (average) and thus from every other number in the set.
/// A variance value of zero indicates that all values within a set are identical, while a high variance indicates that the data is very spread out around the mean.
///
/// - Parameter distribution: An array of tuples where the first item is a random variable and the second item is its probability.
///                           It should adhere to the `Real` type (a protocol in Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The variance of the given distribution as a `Real` number.
///
/// - Complexity: O(n), where n is the number of elements in the `distribution` array.
///
///     let distribution = [(1.0, 0.1), (2.0, 0.2), (3.0, 0.7)]
///     let result = varianceDiscrete(distribution)
///     print(result)
public func varianceDiscrete<T: Real>(_ distribution: [(T, T)]) -> T {
    let mean = meanDiscrete(distribution)
    return distribution.map({ ($0.0 - mean) * ($0.0 - mean) * $0.1}).reduce(0, +)
}
