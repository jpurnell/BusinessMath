//
//  mape.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// Mean Absolute Percentage Error — forecast error expressed as a fraction of actual values.
///
/// Calculated as `mean(|actual - forecast| / |actual|)` over elements where `actual ≠ 0`.
/// The result is a ratio (0.05 = 5%), not a percentage. Scale-independent,
/// making it useful for comparing forecast accuracy across different magnitudes.
///
/// - Parameters:
///   - actual: Observed values. Elements equal to zero are excluded from the calculation.
///   - forecast: Predicted values. Must have the same count as `actual`.
/// - Returns: The MAPE as a ratio, or `NaN` if the arrays are empty, mismatched,
///   or all actual values are zero.
public func mape<T: Real>(_ actual: [T], _ forecast: [T]) -> T {
	guard !actual.isEmpty, actual.count == forecast.count else { return T.nan }
	var sum = T.zero
	var count = 0
	for i in actual.indices {
		guard actual[i] != T.zero else { continue }
		sum += abs((actual[i] - forecast[i]) / actual[i])
		count += 1
	}
	guard count > 0 else { return T.nan }
	return sum / T(count)
}
