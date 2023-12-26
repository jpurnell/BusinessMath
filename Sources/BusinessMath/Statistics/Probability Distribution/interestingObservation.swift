//
//  interestingObservation.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics
// What we care about is when an observation is above or below our particular confidence interval for a given range

/// Determines whether the observation is considered interesting based on the given values and confidence interval.
///
/// An observation is considered interesting if it falls outside the range defined by the lower and upper bounds of the calculated confidence interval.
///
/// - Parameters:
///     - x: The observation to be evaluated.
///     - values: An array of sample data. Each element should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///     - ci: The confidence level for the calculated confidence interval.
///
/// - Returns: `True` if the observation is interesting (i.e., lies outside the calculated confidence interval), and `False` otherwise.
///
/// - Precondition: `ci` has to be a value between `0` and `1` (inclusive), and `values` should not be empty.
/// - Complexity: O(n), where n is the number of elements in the `values` array.
///
///     let x = 2.0
///     let values = [1.0, 2.0, 3.0, 4.0, 5.0]
///     let ci = 0.95 // 95% confidence level
///     let result = interestingObservation(observation: x, values: values, confidenceInterval: ci)
///     print(result) 
public func interestingObservation<T: Real>(observation x: T, values: [T], confidenceInterval ci: T) -> Bool {
    let ciRange = confidenceInterval(ci: ci, values: values)
    if x <= ciRange.low || x >= ciRange.high {
        return true
    }
    return false
}
