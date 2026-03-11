//
//  nemenyiCD.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates the Nemenyi Critical Distance for post-hoc testing.
///
/// After finding a significant Friedman test result, the Nemenyi test
/// determines which specific pairs of treatments differ significantly.
/// The critical distance (CD) is the minimum difference in average ranks
/// required for significance.
///
/// ## Overview
///
/// Use the Nemenyi post-hoc test when:
/// 1. Friedman's chi-square test is significant
/// 2. You want to know which specific items differ
/// 3. You're comparing all pairs of items
///
/// ## Usage Example
///
/// ```swift
/// // 6 judges ranked 5 items
/// // Friedman test was significant at α = 0.05
/// let cd = nemenyiCD(judges: 6, items: 5, alpha: 0.05)
///
/// // Calculate average ranks for each item
/// let avgRanks: [Double] = [1.5, 2.8, 3.1, 3.9, 4.7]
///
/// // Compare pairs: items differ if |R̄i - R̄j| > CD
/// let diff = abs(avgRanks[0] - avgRanks[4])  // 3.2
/// if Float(diff) > cd {
///     print("Items 1 and 5 are significantly different")
/// }
/// ```
///
/// ## Mathematical Formula
///
/// CD = q_α × √(k(k+1)/(6n))
///
/// where:
/// - q_α = critical value from studentized range distribution
/// - k = number of items
/// - n = number of judges
///
/// ## Critical Values Table
///
/// The function uses tabulated critical values for the studentized
/// range distribution at α = 0.05 and α = 0.10:
///
/// | k | q (α=0.05) | q (α=0.10) |
/// |---|------------|------------|
/// | 2 | 1.960 | 1.645 |
/// | 3 | 2.343 | 2.052 |
/// | 4 | 2.569 | 2.291 |
/// | 5 | 2.728 | 2.459 |
/// | 6 | 2.850 | 2.589 |
/// | 7 | 2.949 | 2.693 |
/// | 8 | 3.031 | 2.780 |
/// | 9 | 3.102 | 2.855 |
/// | 10 | 3.164 | 2.920 |
///
/// - Parameters:
///   - judges: Number of judges (n). Must be at least 2.
///   - items: Number of items (k). Must be between 2 and 10.
///   - alpha: Significance level. Only 0.05 and 0.10 are supported.
///
/// - Returns: The critical distance threshold.
///   Returns NaN if items < 2 or items > 10.
///
/// - Complexity: O(1).
///
/// - Note: The function uses tabulated critical values.
///   For items > 10, consider using asymptotic approximations.
///
/// - SeeAlso: ``friedmanChiSquare(_:)``
public func nemenyiCD(judges: Int, items: Int, alpha: Double) -> Float {
    // Critical values for studentized range distribution
    // Index corresponds to k-2 (k = 2 → index 0)
    let q05: [Float] = [1.960, 2.343, 2.569, 2.728, 2.850, 2.949, 3.031, 3.102, 3.164]
    let q10: [Float] = [1.645, 2.052, 2.291, 2.459, 2.589, 2.693, 2.780, 2.855, 2.920]

    // Validate inputs
    guard items >= 2, items <= 10, judges >= 1 else {
        return Float.nan
    }

    let index = items - 2

    // Select appropriate q value based on alpha
    let q: Float
    if alpha <= 0.05 {
        q = q05[index]
    } else if alpha <= 0.10 {
        q = q10[index]
    } else {
        // For larger alpha, use 0.10 values as closest approximation
        q = q10[index]
    }

    // CD = q × √(k(k+1)/(6n))
    let k = Float(items)
    let n = Float(judges)
    let fraction = (k * (k + 1)) / (6 * n)
    let cd = q * sqrt(fraction)

    return cd
}
