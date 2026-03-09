//
//  CurrentRatio.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/2025.
//

import Foundation
import Numerics

/// Calculate the current ratio.
///
/// The current ratio measures the ability of a company to cover its short-term
/// liabilities with its short-term assets.
///
/// - Parameters:
///   - currentAssets: The total current assets of the company.
///   - currentLiabilities: The total current liabilities of the company.
///
/// - Returns: The current ratio, defined as current assets divided by current liabilities.
///
/// - Complexity: O(1).
/// - Throws: `BusinessMathError.divisionByZero` if current liabilities is zero or negative.
public func currentRatio<T: Real>(currentAssets: T, currentLiabilities: T) throws -> T {
	guard currentLiabilities > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "Current ratio: current liabilities must be positive"
		)
	}
	return currentAssets / currentLiabilities
}
