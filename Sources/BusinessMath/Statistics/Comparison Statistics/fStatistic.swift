//
//  fStatistic.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates the F-statistic derived from Kendall's W coefficient.
///
/// The F-statistic transforms Kendall's W into a value that can be
/// compared against the F-distribution for hypothesis testing.
///
/// ## Overview
///
/// While Kendall's W provides a measure of agreement, the F-statistic
/// allows formal hypothesis testing:
/// - H0: Rankings are random (no agreement)
/// - H1: Rankings show significant agreement
///
/// ## Usage Example
///
/// ```swift
/// let w: Double = 0.8  // Strong agreement
/// let items = 5
/// let f = fStatistic(kendallW: w, items: items)
/// // f = (5-1) × 0.8 / (1-0.8) = 4 × 0.8 / 0.2 = 16.0
/// ```
///
/// ## Mathematical Formula
///
/// F = (m-1) × W / (1-W)
///
/// where:
/// - m = number of items
/// - W = Kendall's W coefficient
///
/// ## Degrees of Freedom
///
/// The resulting F-statistic has:
/// - Numerator df: m - 1
/// - Denominator df: n(m - 1)
///
/// where n is the number of judges.
///
/// - Parameters:
///   - w: Kendall's W coefficient (must be in [0, 1)).
///   - items: Number of items (m). Must be at least 2.
///
/// - Returns: The F-statistic value.
///   Returns 0 when W = 0.
///   Returns infinity when W approaches 1.
///
/// - Complexity: O(1).
///
/// - SeeAlso: ``kendallW(_:)``
public func fStatistic<T: Real>(kendallW w: T, items: Int) -> T {
    guard items >= 2 else {
        return T.nan
    }

    let m = T(items)

    // F = (m-1) × W / (1-W)
    // When W = 0, F = 0
    // When W → 1, F → ∞
    let numerator = (m - T(1)) * w
    let denominator = T(1) - w

    // Guard against division by zero when W = 1
    guard abs(denominator) > T.ulpOfOne else {
        return T.infinity
    }

    return numerator / denominator
}
