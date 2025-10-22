//
//  AssetTurnover.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/2025.
//

import Foundation
import Numerics

/// Calculate the asset turnover ratio.
///
/// The asset turnover ratio measures the efficiency of a company's use of its
/// assets in generating sales revenue.
///
/// - Parameters:
///   - netSales: The net sales during the period.
///   - averageTotalAssets: The average total assets during the period.
///
/// - Returns: The asset turnover ratio, defined as net sales divided by
///   average total assets.
///
/// - Complexity: O(1).
public func assetTurnover<T: Real>(netSales: T, averageTotalAssets: T) -> T {
    guard averageTotalAssets > T(0) else { return T(0) } // Handle division by zero
    return netSales / averageTotalAssets
}
