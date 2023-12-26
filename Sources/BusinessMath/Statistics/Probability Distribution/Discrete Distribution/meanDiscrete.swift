//
//  meanDiscrete.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the mean (average) of a discrete probability distribution.
///
/// This function calculates the mean, which is the sum of all the numbers in the dataset divided by the quantity of numbers in the dataset.
///
/// - Parameter distribution: An array of tuples where the first item is a random variable and the second item is its probability.
///                           It should adhere to the `Real` type (a protocol in Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The mean of the given distribution as a `Real` number.
///
/// - Complexity: O(n), where n is the number of elements in the `distribution` array.
///
///     let distribution = [(1.0, 0.1), (2.0, 0.2), (3.0, 0.7)]
///     let result = meanDiscrete(distribution)
///     print(result)
public func meanDiscrete<T: Real>(_ distribution: [(T, T)]) -> T {
    return distribution.map({$0.0 * $0.1}).reduce(T(0), +)
}

