//
//  empiricalCDF.swift
//  BusinessMath
//
//  Created by Justin Purnell on 11/12/24.
//

import Foundation
import Numerics

/// Calculates the empirical cumulative distribution function (eCDF) at a given value.
///
/// The empirical CDF represents the proportion of observations in the dataset that are
/// less than or equal to the specified value. This is a non-parametric estimate of the
/// true cumulative distribution function.
///
/// The empirical CDF is defined as:
/// ```
/// eCDF(x) = (number of observations ≤ x) / (total number of observations)
/// ```
///
/// - Parameters:
///   - value: The value at which to evaluate the empirical CDF
///   - data: An array of observations
/// - Returns: The proportion of observations ≤ value (between 0.0 and 1.0)
///
/// - Note: Returns 0.0 for empty datasets
/// - Note: Returns `nan` when an observation, or `value` itself, cannot be ordered — a
///   `nan` among floating-point data.
///
/// ## Example
///
/// ```swift
/// let data = [1.0, 2.0, 3.0, 4.0, 5.0]
///
/// // What proportion of data is ≤ 3.0?
/// let prob = empiricalCDF(3.0, data: data)  // Returns 0.6 (60%)
///
/// // What proportion of data is ≤ 0.0?
/// let probBelow = empiricalCDF(0.0, data: data)  // Returns 0.0 (0%)
/// ```
///
/// ## Unorderable observations
///
/// Every comparison against a `nan` is false, so such an observation is counted in *neither*
/// tail: ``empiricalCDF(_:data:)`` and ``empiricalComplementaryCDF(_:data:)`` both come back
/// biased low and stop summing to one, with nothing in either answer to say an observation
/// was dropped. Both functions now report `nan` instead, which is what ``median(_:)`` and
/// ``mean(_:)`` already do with the same input.
///
/// ## Related Functions
///
/// - `percentileLocation(_:values:)` - Inverse operation: finds value at given percentile
/// - `normalCDF(_:mean:stdDev:)` - Parametric CDF assuming normal distribution
public func empiricalCDF<T: Comparable>(_ value: T, data: [T]) -> Double {
	guard !data.isEmpty else { return 0.0 }

	let countAtOrBelow = data.filter { $0 <= value }.count
	let countAbove = data.filter { $0 > value }.count
	// The two tails must partition the sample. They do for every pair a `Comparable` can
	// actually order, so a shortfall is the signature of an element no comparison can place —
	// and it is detectable without constraining `T` to `FloatingPoint`. Returning
	// `countAtOrBelow / n` here would report a proportion computed over the observations that
	// happened to compare, which is contract §4: silently dropping a value from an
	// aggregation because it matched no branch.
	guard countAtOrBelow + countAbove == data.count else { return Double.nan }
	return Double(countAtOrBelow) / Double(data.count)
}

/// Calculates the empirical complementary cumulative distribution function (1 - eCDF) at a given value.
///
/// Also known as the survival function, this represents the proportion of observations
/// in the dataset that are strictly greater than the specified value.
///
/// The complementary empirical CDF is defined as:
/// ```
/// 1 - eCDF(x) = (number of observations > x) / (total number of observations)
/// ```
///
/// - Parameters:
///   - value: The value at which to evaluate the complementary eCDF
///   - data: An array of observations
/// - Returns: The proportion of observations > value (between 0.0 and 1.0)
///
/// - Note: Returns 0.0 for empty datasets
/// - Note: Returns `nan` when an observation, or `value` itself, cannot be ordered. See
///   the discussion on ``empiricalCDF(_:data:)``; the two are the same aggregation read
///   from opposite ends and must agree about which observations they could place.
///
/// ## Example
///
/// ```swift
/// let data = [1.0, 2.0, 3.0, 4.0, 5.0]
///
/// // What proportion of data is > 3.0?
/// let prob = empiricalComplementaryCDF(3.0, data: data)  // Returns 0.4 (40%)
/// ```
public func empiricalComplementaryCDF<T: Comparable>(_ value: T, data: [T]) -> Double {
	guard !data.isEmpty else { return 0.0 }

	let countAbove = data.filter { $0 > value }.count
	let countAtOrBelow = data.filter { $0 <= value }.count
	// Same partition test as ``empiricalCDF(_:data:)``, and for the same reason: an
	// observation that lands in neither tail leaves both functions biased low and their sum
	// short of one, with no diagnostic anywhere in either number.
	guard countAbove + countAtOrBelow == data.count else { return Double.nan }
	return Double(countAbove) / Double(data.count)
}

/// Calculates the empirical probability that an observation falls within a specified range.
///
/// Returns the proportion of observations in the dataset that fall strictly between
/// the lower and upper bounds (exclusive on both ends).
///
/// This is equivalent to: `eCDF(upper) - eCDF(lower)`
///
/// - Parameters:
///   - lower: The lower bound (exclusive)
///   - upper: The upper bound (exclusive)
///   - data: An array of observations
/// - Returns: The proportion of observations where lower < observation < upper
///
/// - Note: The function handles reversed arguments automatically (if upper < lower, they are swapped)
/// - Note: Returns 0.0 for empty datasets
/// - Note: Returns `nan` when a bound or an observation cannot be ordered
///
/// ## Example
///
/// ```swift
/// let data = [1.0, 2.0, 3.0, 4.0, 5.0]
///
/// // What proportion of data falls between 2.0 and 4.0 (exclusive)?
/// let prob = empiricalProbabilityBetween(2.0, 4.0, data: data)  // Returns 0.2 (20% - just the value 3.0)
/// ```
public func empiricalProbabilityBetween<T: Comparable>(_ lower: T, _ upper: T, data: [T]) -> Double {
	guard !data.isEmpty else { return 0.0 }

	// The swap is the first casualty of an unorderable bound, not the count. `min(a, b)` is
	// `b < a ? b : a`, so `min(nan, 5)` is `nan` while `min(5, nan)` is `5` — which end of the
	// range survives depends on the argument order the caller happened to use. Settle that
	// before swapping anything.
	let boundsOrderable = (lower <= upper) || (lower > upper)
	guard boundsOrderable else { return Double.nan }

	// Ensure lower <= upper
	let minBound = min(lower, upper)
	let maxBound = max(lower, upper)

	// Unlike the two tails above, "inside the range" has no complement that must add up —
	// an unorderable observation simply fails both halves of the predicate and is counted as
	// outside, indistinguishable from a reading that genuinely sits outside. Trichotomy is
	// the test that separates them: for every value a `Comparable` can place, exactly one of
	// `<=` and `>` holds against a given reference, and both being false is the signature of
	// one it cannot.
	let orderable = data.allSatisfy { ($0 <= minBound) || ($0 > minBound) }
	guard orderable else { return Double.nan }

	let countInRange = data.filter { $0 > minBound && $0 < maxBound }.count
	return Double(countInRange) / Double(data.count)
}
