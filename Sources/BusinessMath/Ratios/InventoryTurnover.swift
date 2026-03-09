//
//  InventoryTurnover.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/2025.
//

import Foundation
import Numerics

/// Calculate the inventory turnover ratio.
///
/// The inventory turnover measures how many times a company's inventory is sold
/// and replaced over a period.
///
/// - Parameters:
///   - costOfGoodsSold: The total cost of goods sold over the period.
///   - averageInventory: The average inventory during the period.
///
/// - Returns: The inventory turnover ratio, defined as the cost of goods sold
///   divided by average inventory.
///
/// - Complexity: O(1).
/// - Throws: `BusinessMathError.divisionByZero` if average inventory is zero or negative.
public func inventoryTurnover<T: Real>(costOfGoodsSold: T, averageInventory: T) throws -> T {
    guard averageInventory > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "Inventory turnover: average inventory must be positive"
		)
	}
    return costOfGoodsSold / averageInventory
}
