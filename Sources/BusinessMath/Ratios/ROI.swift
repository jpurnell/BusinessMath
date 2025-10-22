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
public func roi<T: Real>(gainFromInvestment: T, costOfInvestment: T) -> T {
	guard costOfInvestment > T(0) else {
		return T(0) // Return 0 if cost of investment is zero or negative
	}
	return gainFromInvestment / costOfInvestment
}
