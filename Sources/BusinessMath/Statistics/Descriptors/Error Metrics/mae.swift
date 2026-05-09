//
//  mae.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// Mean Absolute Error — the average magnitude of forecast errors.
///
/// Calculated as `mean(|actual - forecast|)`. Lower values indicate
/// better forecast accuracy. Unlike RMSE, MAE does not penalize large
/// errors disproportionately.
///
/// - Parameters:
///   - actual: Observed values.
///   - forecast: Predicted values. Must have the same count as `actual`.
/// - Returns: The MAE, or `NaN` if the arrays are empty or mismatched in length.
public func mae<T: Real>(_ actual: [T], _ forecast: [T]) -> T {
	guard !actual.isEmpty, actual.count == forecast.count else { return T.nan }
	var sum = T.zero
	for i in actual.indices {
		sum += abs(actual[i] - forecast[i])
	}
	return sum / T(actual.count)
}
