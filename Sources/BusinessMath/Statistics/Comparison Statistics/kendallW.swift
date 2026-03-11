//
//  kendallW.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates Kendall's W coefficient of concordance from a ranking matrix.
///
/// Kendall's W measures the agreement among multiple judges (raters) when
/// ranking multiple items. Values range from 0 (no agreement beyond chance)
/// to 1 (perfect agreement).
///
/// ## Overview
///
/// The coefficient is widely used in:
/// - Wine tasting panels
/// - Academic paper reviews
/// - Consumer preference studies
/// - Any scenario with multiple rankers assessing the same items
///
/// ## Usage Example
///
/// ```swift
/// // 3 judges ranking 4 items with perfect agreement
/// let rankings: [[Double]] = [
///     [1, 2, 3, 4],  // Judge 0
///     [1, 2, 3, 4],  // Judge 1
///     [1, 2, 3, 4],  // Judge 2
/// ]
/// let w = kendallW(rankings)
/// // w = 1.0 (perfect agreement)
///
/// // 3 judges with complete disagreement
/// let disagreement: [[Double]] = [
///     [1, 2, 3],
///     [2, 3, 1],
///     [3, 1, 2],
/// ]
/// let w2 = kendallW(disagreement)
/// // w2 = 0.0 (no agreement)
/// ```
///
/// ## Input Format
///
/// The rankings matrix should be organized as:
/// - **Rows**: Each row represents one judge's rankings
/// - **Columns**: Each column represents one item being ranked
/// - **Values**: The rank assigned by that judge to that item (typically 1 to k)
///
/// ## Mathematical Background
///
/// The formula is: W = 12S / (n²(k³-k))
///
/// where:
/// - S = Σ(Ri - R̄)² (sum of squared deviations from mean rank sum)
/// - n = number of judges (rows)
/// - k = number of items (columns)
/// - Ri = rank sum for item i (sum of column i)
/// - R̄ = mean of rank sums
///
/// ## Statistical Interpretation
///
/// | W Value | Interpretation |
/// |---------|----------------|
/// | 0.0     | No agreement (random ranking) |
/// | 0.1-0.3 | Weak agreement |
/// | 0.3-0.5 | Moderate agreement |
/// | 0.5-0.7 | Good agreement |
/// | 0.7-0.9 | Strong agreement |
/// | 0.9-1.0 | Very strong to perfect agreement |
///
/// - Parameter rankings: A 2D array where rows are judges and columns are items.
///   Each cell contains the rank assigned by that judge to that item.
///
/// - Returns: Kendall's W coefficient in range [0, 1].
///   Returns NaN if the matrix is empty or has fewer than 2 items.
///   Returns 0 if all rank sums are equal (zero variance).
///
/// - Complexity: O(n × k) where n is judges and k is items.
///
/// - SeeAlso: ``friedmanChiSquare(_:)``
/// - SeeAlso: ``fStatistic(kendallW:items:)``
public func kendallW<T: Real>(_ rankings: [[T]]) -> T {
    // Validate input
    guard !rankings.isEmpty else { return T.nan }
    guard let firstRow = rankings.first, !firstRow.isEmpty else { return T.nan }

    let judges = rankings.count      // n = number of rows
    let items = firstRow.count       // k = number of columns

    // Need at least 2 items for concordance to be meaningful
    guard items >= 2 else { return T.nan }

    // Compute rank sums (sum each column)
    var rankSums: [T] = Array(repeating: T(0), count: items)
    for row in rankings {
        for (col, rank) in row.enumerated() where col < items {
            rankSums[col] += rank
        }
    }

    // Calculate using the internal function
    return kendallWFromRankSums(rankSums: rankSums, judges: judges, items: items)
}

/// Internal function to calculate Kendall's W from pre-computed rank sums.
///
/// This is used by Array2D and other internal calculations.
///
/// - Parameters:
///   - rankSums: Array of rank sums for each item.
///   - judges: The number of judges (n).
///   - items: The number of items (k).
///
/// - Returns: Kendall's W coefficient in range [0, 1].
public func kendallWFromRankSums<T: Real>(rankSums: [T], judges: Int, items: Int) -> T {
    guard items >= 2, judges >= 1, !rankSums.isEmpty else {
        return T.nan
    }

    let n = T(judges)
    let k = T(items)

    // Calculate mean of rank sums
    let meanRankSum = rankSums.reduce(T(0), +) / T(rankSums.count)

    // Calculate S = sum of squared deviations from mean
    var s = T(0)
    for rankSum in rankSums {
        let deviation = rankSum - meanRankSum
        s += deviation * deviation
    }

    // If S is essentially zero, there's no agreement variance
    guard abs(s) > T.ulpOfOne else {
        return T(0)
    }

    // W = 12S / (n²(k³-k))
    let denominator = n * n * (k * k * k - k)

    // Guard against division by zero
    guard abs(denominator) > T.ulpOfOne else {
        return T.nan
    }

    let w = (T(12) * s) / denominator

    // Clamp to valid range [0, 1] to handle floating-point errors
    return max(T(0), min(T(1), w))
}
