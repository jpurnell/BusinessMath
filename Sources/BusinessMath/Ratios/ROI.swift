//
//  ROI.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/2025.
//

import Foundation
import Numerics

/// Calculate the Return on Investment (ROI).
///
/// ROI measures the return generated on investment relative to its cost.
///
/// - Parameters:
///   - gainFromInvestment: The total gain from the investment.
///   - costOfInvestment: The total cost of the investment.
///
/// - Returns: The ROI, defined as (gain from investment - cost of investment)
///   divided by the cost of investment.
///
/// - Complexity: O(1).
/// - Throws: `BusinessMathError.divisionByZero` if cost of investment is zero or negative.
public func roi<T: Real>(gainFromInvestment: T, costOfInvestment: T) throws -> T {
	guard costOfInvestment > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "Return on investment: cost of investment must be positive"
		)
	}
	return gainFromInvestment / costOfInvestment
}
