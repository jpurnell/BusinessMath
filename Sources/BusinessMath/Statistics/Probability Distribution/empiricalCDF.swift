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
/// ## Related Functions
///
/// - `percentileLocation(_:values:)` - Inverse operation: finds value at given percentile
/// - `normalCDF(_:mean:stdDev:)` - Parametric CDF assuming normal distribution
public func empiricalCDF<T: Comparable>(_ value: T, data: [T]) -> Double {
	guard !data.isEmpty else { return 0.0 }

	let countAtOrBelow = data.filter { $0 <= value }.count
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

	// Ensure lower <= upper
	let minBound = min(lower, upper)
	let maxBound = max(lower, upper)

	let countInRange = data.filter { $0 > minBound && $0 < maxBound }.count
	return Double(countInRange) / Double(data.count)
}
