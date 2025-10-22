//
//  InterestCoverage.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Foundation
import Numerics

/// Calculate the interest coverage ratio.
///
/// This ratio measures a company's ability to cover its interest payments
/// with its earnings before interest and taxes (EBIT).
///
/// - Parameters:
///   - earningsBeforeInterestAndTax: The earnings of the company before
///     interest and tax expenses.
///   - interestExpense: The total interest expenses for the period.
///
/// - Returns: The interest coverage ratio, defined as EBIT divided by interest expense.
///
/// - Complexity: O(1).
public func interestCoverage<T: Real>(earningsBeforeInterestAndTax: T, interestExpense: T) -> T {
    guard interestExpense > T(0) else {
        return T(0) // Return 0 if interest expense is zero or negative
    }
    return earningsBeforeInterestAndTax / interestExpense
}
