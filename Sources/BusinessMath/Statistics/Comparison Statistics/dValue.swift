//
//  dValue.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates the D-value (sum of squared deviations from center rank) from a ranking matrix.
///
/// The D-value measures how much the observed rank sums deviate from
/// what would be expected if rankings were completely random.
///
/// ## Overview
///
/// In concordance analysis, the D-value quantifies the spread of
/// rank sums around their expected center. A larger D-value indicates
/// more agreement among judges.
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
/// let d = dValue(rankings)
/// // Rank sums: [4, 8, 12, 16]
/// // center = 4 × (4+1) / 2 = 10
/// // D = (4-10)² + (8-10)² + (12-10)² + (16-10)² = 80.0
///
/// // No agreement
/// let disagreement: [[Double]] = [
///     [1, 2, 3],
///     [2, 3, 1],
///     [3, 1, 2],
/// ]
/// let d2 = dValue(disagreement)
/// // Rank sums: [6, 6, 6], center = 6
/// // D = 0.0 (no deviation from center)
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
/// D = Σ(Ri - center)²
///
/// where:
/// - Ri = rank sum for item i
/// - center = n(m+1)/2 (expected rank sum with random rankings)
/// - n = number of judges (rows)
/// - m = number of items (columns)
///
/// ## Interpretation
///
/// The D-value is related to Kendall's W:
///
/// W = 12D / (n²m(m² - 1))
///
/// - Parameter rankings: A 2D array where rows are judges and columns are items.
///   Each cell contains the rank assigned by that judge to that item.
///
/// - Returns: The sum of squared deviations from center.
///   Returns 0 if the matrix is empty or has only one item.
///
/// - Complexity: O(n × k) where n is judges and k is items.
///
/// - Note: The D-value is always non-negative.
public func dValue<T: Real>(_ rankings: [[T]]) -> T {
    // Validate input
    guard !rankings.isEmpty else { return T(0) }
    guard let firstRow = rankings.first, !firstRow.isEmpty else { return T(0) }

    let judges = rankings.count      // n = number of rows
    let items = firstRow.count       // k = number of columns

    // Compute rank sums (sum each column)
    var rankSums: [T] = Array(repeating: T(0), count: items)
    for row in rankings {
        for (col, rank) in row.enumerated() where col < items {
            rankSums[col] += rank
        }
    }

    // Use the internal function
    return dValueFromRankSums(rankSums: rankSums, judges: judges, items: items)
}

/// Internal function to calculate D-value from pre-computed rank sums.
public func dValueFromRankSums<T: Real>(rankSums: [T], judges: Int, items: Int) -> T {
    guard judges >= 1, items >= 1, !rankSums.isEmpty else {
        return T(0)
    }

    // center = n(m+1)/2
    let center = (T(judges) * (T(items) + T(1))) / T(2)

    // D = Σ(Ri - center)²
    var sumSquaredDeviations = T(0)
    for rankSum in rankSums {
        let deviation = rankSum - center
        sumSquaredDeviations += deviation * deviation
    }

    return sumSquaredDeviations
}
