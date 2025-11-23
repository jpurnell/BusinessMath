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
	precondition(!values.isEmpty, "values must not be empty")
	precondition(percentile >= 0 && percentile <= 100, "percentile must be between 0 and 100")

	let sorted = values.sorted()
	let n = sorted.count

	if percentile <= 0 { return sorted.first! }
	if percentile >= 100 { return sorted.last! }

	let r = Int(ceil(Double(percentile) / 100.0 * Double(n))) // 1-based rank
	return sorted[r - 1] // convert to 0-based index
}
