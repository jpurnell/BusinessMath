//
//  QuickRatio.swift
//  BusinessMath
////
//  QuickRatio.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/2025.
//

import Foundation
import Numerics

/// Calculate the quick ratio.
///
/// The quick ratio measures the ability of a company to meet its short-term
/// obligations with its most liquid assets.
///
/// - Parameters:
///   - currentAssets: The total current assets of the company.
///   - inventory: The total inventory of the company.
///   - currentLiabilities: The total current liabilities of the company.
///
/// - Returns: The quick ratio, calculated as (current assets - inventory)
///   divided by current liabilities.
///
/// - Complexity: O(1).
/// - Throws: `BusinessMathError.divisionByZero` if current liabilities is zero or negative.
public func quickRatio<T: Real>(currentAssets: T, inventory: T, currentLiabilities: T) throws -> T {
	guard currentLiabilities > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "Quick ratio: current liabilities must be positive"
		)
	}
	return (currentAssets - inventory) / currentLiabilities
}
