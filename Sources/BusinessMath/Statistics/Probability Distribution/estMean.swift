//
//  estMean.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the estimated mean of an array of given probabilities.
///
/// The function calculates the estimated mean which is the sum of all probabilities in the array divided by the count of the probabilities. Mean is a measure of central tendency which gives the average value.
///
/// - Parameter x: The array of probabilities. Each probability should adhere to the `Real` protocol (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: The estimated mean of the given probabilities.
///
/// - Precondition: The `x` array should not be empty.
/// - Complexity: O(n), where n is the number of elements in the `x` array.
///
///     let probabilities = [0.1, 0.2, 0.7]
///     let result = estMean(probabilities: probabilities)
///     print(result) // Prints "0.333"
///
/// Use this function when you need to find the average probability in an array of probabilities.
public func estMean<T: Real>(probabilities x: [T]) -> T {
    return x.reduce(T(0), +) / T(x.count)
}
