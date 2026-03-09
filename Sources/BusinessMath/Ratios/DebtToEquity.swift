//
//  DebtToEquity.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Foundation
import Numerics

/// Calculate the debt to equity ratio.
///
/// This ratio indicates the relative proportion of shareholders' equity and
/// debt used to finance a company's assets.
///
/// - Parameters:
///   - totalLiabilities: The total amount of liabilities for the company.
///   - shareholderEquity: The total equity capital invested by shareholders.
///
/// - Returns: The debt to equity ratio, defined as total liabilities divided by
///   shareholder equity.
///
/// - Complexity: O(1).
/// - Throws: `BusinessMathError.divisionByZero` if shareholder equity is zero or negative.
public func debtToEquity<T: Real>(totalLiabilities: T, shareholderEquity: T) throws -> T {
    guard shareholderEquity > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "Debt to equity: shareholder equity must be positive"
		)
    }
    return totalLiabilities / shareholderEquity
}
