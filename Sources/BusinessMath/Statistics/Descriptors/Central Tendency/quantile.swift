//
//  quantile.swift
//  BusinessMath
//
//  The canonical empirical quantile for the library.
//

import Foundation
import Numerics

/// The empirical quantile of a sorted sample, using linear interpolation
/// between order statistics (type 7).
///
/// This is the single canonical empirical quantile in BusinessMath. Every
/// component that reports a percentile of raw sample data — `Percentiles`,
/// `FinancialSimulation.percentile(_:metric:)`, `ProjectionResults.percentile(_:)` —
/// delegates here, so they cannot drift apart.
///
/// ## Interpolation rule
///
/// Type 7 is the default in R (`quantile(x, p, type = 7)`) and NumPy
/// (`np.quantile(x, p, method = "linear")`). For a sample of `n` sorted
/// observations `x[0] ... x[n-1]`:
///
/// ```
/// h = (n - 1) * p
/// Q(p) = x[floor(h)] + (h - floor(h)) * (x[floor(h) + 1] - x[floor(h)])
/// ```
///
/// So `Q(0)` is the minimum, `Q(1)` is the maximum, and `Q(0.5)` is the
/// ordinary median for both odd and even `n`. When `h` lands exactly on an
/// index the corresponding order statistic is returned unmodified, with no
/// floating-point interpolation error.
///
/// ## Input must already be sorted
///
/// `sorted` is **required** to be in ascending order. This function does not
/// sort, and does not check: sorting is O(n log n) and callers that compute
/// many quantiles from one sample should pay it once. Passing unsorted input
/// produces a meaningless number rather than an error. Sort first:
///
/// ```swift
/// let q90 = quantile(sorted: sample.sorted(), p: 0.90)
/// ```
///
/// ## Behaviour at the edges
///
/// This function is total — it never traps and never throws.
///
/// - An empty sample returns `nan`. There is no quantile of no data, and this
///   matches ``median(_:)``, which also returns `nan` for an empty array.
/// - A single observation returns that observation for every `p`, including
///   values outside `[0, 1]`.
/// - `p` outside `[0, 1]` is clamped: `p <= 0` returns the minimum and
///   `p >= 1` returns the maximum. Infinities clamp the same way.
/// - A `nan` value of `p` returns `nan`.
/// - `nan` values *inside* `sorted` are not detected; sort order is undefined
///   in their presence, so screen them out before calling.
///
/// - Parameters:
///   - sorted: The sample, in ascending order.
///   - p: The quantile probability, normally in `[0, 1]` (0.9 means the 90th percentile).
///
/// - Returns: The interpolated quantile, or `nan` for an empty sample.
///
/// - Complexity: O(1).
///
/// ## Example
///
/// ```swift
/// let sample = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
/// quantile(sorted: sample, p: 0.25)  // 3.25
/// quantile(sorted: sample, p: 0.50)  // 5.5
/// quantile(sorted: sample, p: 0.90)  // 9.1
/// ```
public func quantile<T: Real & BinaryFloatingPoint>(sorted: [T], p: T) -> T {
	let n = sorted.count
	guard n > 0 else { return T.nan }
	guard !p.isNaN else { return T.nan }
	guard n > 1 else { return sorted[0] }

	// Clamp rather than trap: callers routinely pass computed confidence
	// levels, and an out-of-range level means "the extreme", not "crash".
	let clamped = Swift.min(Swift.max(p, T.zero), T(1))

	let position = clamped * T(n - 1)
	let lowerPosition = position.rounded(.down)
	let lowerIndex = Int(lowerPosition)

	// clamped <= 1 puts lowerIndex in 0...n-1; at the top there is no
	// neighbour to interpolate towards.
	guard lowerIndex < n - 1 else { return sorted[n - 1] }

	let fraction = position - lowerPosition
	let lower = sorted[lowerIndex]
	let upper = sorted[lowerIndex + 1]
	return lower + fraction * (upper - lower)
}
