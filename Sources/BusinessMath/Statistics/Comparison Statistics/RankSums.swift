//
//  RankSums.swift
//  BusinessMath
//
//  The reduction that `dValue`, `friedmanChiSquare` and `kendallW` each opened with.
//

import Foundation
import Numerics

/// Reduces a judges × items ranking matrix to one rank sum per item.
///
/// Every rank statistic in this directory starts the same way: check the matrix is not
/// empty, take the number of judges from the row count and the number of items from the
/// first row, then sum each column. All three carried their own copy of those twenty lines,
/// comments included, and nothing compared them.
///
/// ## What this does not decide
///
/// The three callers disagree, deliberately, about what to do when the input is unusable,
/// so this function reports the failure and lets each keep its own answer:
///
/// - `kendallW` and `friedmanChiSquare` return `T.nan`, which a caller can detect.
/// - `dValue` returns `T(0)`, which sits inside the statistic's own range and is
///   indistinguishable from a matrix of perfectly tied ranks.
///
/// That inconsistency is older than this function and is left as it was found. Changing it
/// changes what those functions return.
///
/// The minimum item count is also left to the caller. Kendall's W and Friedman's χ² both
/// need at least two items to have a comparison to make; `dValue` is defined for one.
///
/// ## Ragged rows
///
/// A row longer than the first contributes only its first `items` entries, and a row shorter
/// contributes only what it has. This is the behaviour the three copies already had — the
/// `where col < items` guard was in every one of them — and it means a ragged matrix is
/// silently reduced rather than refused. Combined with the absent check that each row is a
/// permutation, that is how these statistics come to be computed on input that is not a
/// ranking at all; see `RankStatisticsSharedPathTests` for what it costs.
///
/// - Parameter rankings: A judges × items matrix, one row per judge.
///
/// - Returns: The per-item rank sums with the judge and item counts, or `nil` when the
///   matrix has no rows or its first row has no entries.
///
/// - Complexity: O(n × k) for n judges and k items.
internal func rankSums<T: Real>(from rankings: [[T]]) -> (sums: [T], judges: Int, items: Int)? {
	guard !rankings.isEmpty else { return nil }
	guard let firstRow = rankings.first, !firstRow.isEmpty else { return nil }

	let judges = rankings.count      // n = number of rows
	let items = firstRow.count       // k = number of columns

	var sums: [T] = Array(repeating: T(0), count: items)
	for row in rankings {
		for (column, rank) in row.enumerated() where column < items {
			sums[column] += rank
		}
	}
	return (sums, judges, items)
}
