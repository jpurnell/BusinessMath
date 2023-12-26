//
//  percentileLocation.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the value at a given percentile for an array of values.
///
/// The percentile of a value is the percent that this value is greater than. The percentile calculation used in this function is nearest-rank method. Rank nearest to the selected percentile is used instead of interpolation.
///
/// - Parameters:
///     - percentile: Desired percentile.
///     - values: An array of elements that conform to the `Comparable` protocol (every element can be compared for equality with all the other elements).
///
/// - Returns: The value located at the given percentile.
///
/// - Precondition: `percentile` should be between 0 and 100 (inclusive) and `values` should not be empty.
///
/// - Complexity: O(n log n) where n is the number of elements in the `values` array.
///
///     let percentile = 25
///     let values = [1, 2, 3, 4, 5]
///     let result = percentileLocation(percentile, values: values)
///     print(result)
public func PercentileLocation<T: Comparable>(_ percentile: Int, values: [T]) -> T {
    return values.sorted()[(values.count + 1)*(percentile / 100)]
}
