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
/// - Throws: `ArrayError.emptyArray` if `values` is empty.
/// - Throws: `BusinessMathError.invalidInput` if `percentile` is outside 0...100.
/// - Throws: `BusinessMathError.dataQuality` if the sorted values are not in ascending order.
///   `sorted()` is only specified when `<` is a strict weak ordering, and a floating-point
///   `nan` is not — `[3, 1, nan, 2, 5, 4].sorted()` is `[1, 3, nan, 2, 4, 5]`, with the
///   *valid* elements out of place. Nearest-rank then indexes that array and returns a
///   finite, plausible value from the wrong rank. `T` is only `Comparable` here, so `isNaN`
///   is unavailable; the postcondition the rank depends on is verified directly instead,
///   which also catches any other `Comparable` whose `<` is not an ordering.
///
/// - Complexity: O(n log n) where n is the number of elements in the `values` array.
///
///     let percentile = 25
///     let values = [1, 2, 3, 4, 5]
///     let result = percentileLocation(percentile, values: values)
///     print(result)

public func PercentileLocation<T: Comparable>(_ percentile: Int, values: [T]) throws -> T {
	guard !values.isEmpty else {
		throw ArrayError.emptyArray
	}
	guard percentile >= 0 && percentile <= 100 else {
		throw BusinessMathError.invalidInput(
			message: "Percentile must be between 0 and 100",
			value: String(percentile),
			expectedRange: "0 to 100"
		)
	}

	let sorted = values.sorted()
	// If this fails, `sorted` is not sorted, and every index taken below names an element that
	// is not at that rank. The caller asked which value sits at a percentile and would have
	// been handed one from somewhere else, finite and plausible, with nothing to say the rank
	// was never established.
	guard zip(sorted, sorted.dropFirst()).allSatisfy({ $0 <= $1 }) else {
		throw BusinessMathError.dataQuality(
			message: "Percentile location requires values that sort into ascending order",
			context: ["count": "\(sorted.count)"])
	}
	let n = sorted.count

	// Safe: guard ensures at least one element
	if percentile <= 0 { return sorted[0] }
	if percentile >= 100 { return sorted[n - 1] }

	let r = Int(ceil(Double(percentile) / 100.0 * Double(n))) // 1-based rank
	return sorted[r - 1] // convert to 0-based index
}
