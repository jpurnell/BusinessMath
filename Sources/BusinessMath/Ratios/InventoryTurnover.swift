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
public func inventoryTurnover<T: Real>(costOfGoodsSold: T, averageInventory: T) -> T {
    guard averageInventory > T(0) else { return T(0) } // Handle division by zero
    return costOfGoodsSold / averageInventory
}
