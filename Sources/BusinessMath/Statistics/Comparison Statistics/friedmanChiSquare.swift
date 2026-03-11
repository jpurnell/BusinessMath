//
//  friedmanChiSquare.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates the sum of squared rank sums (sigma).
///
/// This is an intermediate calculation used in Friedman's chi-square test.
///
/// ## Mathematical Formula
///
/// σ = Σ(Ri²)
///
/// where Ri is the rank sum for item i.
///
/// ## Usage Example
///
/// ```swift
/// let rankSums: [Double] = [3, 6, 9]
/// let s = sigma(rankSums: rankSums)
/// // s = 3² + 6² + 9² = 9 + 36 + 81 = 126.0
/// ```
///
/// - Parameter rankSums: Array of rank sums for each item.
///
/// - Returns: The sum of squared rank sums.
///
/// - Complexity: O(k) where k is the number of items.
public func sigma<T: Real>(rankSums: [T]) -> T {
    return rankSums.reduce(T(0)) { sum, rankSum in
        sum + rankSum * rankSum
    }
}

/// Calculates Friedman's chi-square test statistic from a ranking matrix.
///
/// The Friedman test is a non-parametric test for detecting differences
/// across multiple treatments/conditions when the same subjects are
/// measured under each condition.
///
/// ## Overview
///
/// Use the Friedman test when:
/// - Multiple judges rank the same set of items
/// - You want to test if the rankings differ significantly from random
/// - The data doesn't meet parametric assumptions
///
/// ## Usage Example
///
/// ```swift
/// // 4 judges ranking 4 items with perfect agreement
/// let rankings: [[Double]] = [
///     [1, 2, 3, 4],
///     [1, 2, 3, 4],
///     [1, 2, 3, 4],
///     [1, 2, 3, 4],
/// ]
/// let chi2 = friedmanChiSquare(rankings)
/// // chi2 = 12.0 (maximum for this configuration)
///
/// // No agreement
/// let disagreement: [[Double]] = [
///     [1, 2, 3],
///     [2, 3, 1],
///     [3, 1, 2],
/// ]
/// let chi2_none = friedmanChiSquare(disagreement)
/// // chi2_none = 0.0
/// ```
///
/// ## Input Format
///
/// The rankings matrix should be organized as:
/// - **Rows**: Each row represents one judge's rankings
/// - **Columns**: Each column represents one item being ranked
/// - **Values**: The rank assigned by that judge to that item
///
/// ## Mathematical Formula
///
/// χ² = (12 / (nk(k+1))) × Σ(Ri²) - 3n(k+1)
///
/// where:
/// - n = number of judges (rows)
/// - k = number of items (columns)
/// - Ri = rank sum for item i
///
/// ## Relationship with Kendall's W
///
/// The Friedman chi-square and Kendall's W are related:
///
/// χ² = n(k-1)W
///
/// - Parameter rankings: A 2D array where rows are judges and columns are items.
///   Each cell contains the rank assigned by that judge to that item.
///
/// - Returns: The chi-square test statistic.
///   Returns NaN for invalid inputs.
///   Returns 0 when there is no agreement.
///
/// - Complexity: O(n × k) where n is judges and k is items.
///
/// - Note: Compare the result against the chi-square distribution
///   with (k-1) degrees of freedom for significance testing.
///
/// - SeeAlso: ``kendallW(_:)``
public func friedmanChiSquare<T: Real>(_ rankings: [[T]]) -> T {
    // Validate input
    guard !rankings.isEmpty else { return T.nan }
    guard let firstRow = rankings.first, !firstRow.isEmpty else { return T.nan }

    let judges = rankings.count      // n = number of rows
    let items = firstRow.count       // k = number of columns

    // Need at least 2 items
    guard items >= 2 else { return T.nan }

    // Compute rank sums (sum each column)
    var rankSums: [T] = Array(repeating: T(0), count: items)
    for row in rankings {
        for (col, rank) in row.enumerated() where col < items {
            rankSums[col] += rank
        }
    }

    // Use the internal function
    return friedmanChiSquareFromRankSums(rankSums: rankSums, judges: judges, items: items)
}

/// Internal function to calculate Friedman's chi-square from pre-computed rank sums.
public func friedmanChiSquareFromRankSums<T: Real>(rankSums: [T], judges: Int, items: Int) -> T {
    guard items >= 2, judges >= 1, !rankSums.isEmpty else {
        return T.nan
    }

    let n = T(judges)
    let k = T(items)

    // Calculate sum of squared rank sums
    let sigmaValue = sigma(rankSums: rankSums)

    // χ² = (12 / (nk(k+1))) × Σ(Ri²) - 3n(k+1)
    let multiplier = T(12) / (n * k * (k + T(1)))
    let tail = T(3) * n * (k + T(1))

    let chi2 = multiplier * sigmaValue - tail

    // Ensure non-negative result (can be slightly negative due to floating-point errors)
    return max(T(0), chi2)
}
