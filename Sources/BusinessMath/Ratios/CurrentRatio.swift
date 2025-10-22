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
public func currentRatio<T: Real>(currentAssets: T, currentLiabilities: T) -> T {
	guard currentLiabilities > T(0) else {
		return T(0) // Return 0 if current liabilities are zero or negative
	}
	return currentAssets / currentLiabilities
}
