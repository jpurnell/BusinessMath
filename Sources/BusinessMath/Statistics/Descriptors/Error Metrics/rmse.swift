//
//  rmse.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// Root Mean Squared Error — the square root of the average squared forecast error.
///
/// Calculated as `sqrt(mean((actual - forecast)²))`. RMSE penalizes larger
/// errors more heavily than MAE due to squaring, making it sensitive to outliers.
/// RMSE ≥ MAE always holds, with equality only when all errors are identical.
///
/// - Parameters:
///   - actual: Observed values.
///   - forecast: Predicted values. Must have the same count as `actual`.
/// - Returns: The RMSE, or `NaN` if the arrays are empty or mismatched in length.
public func rmse<T: Real>(_ actual: [T], _ forecast: [T]) -> T {
	guard !actual.isEmpty, actual.count == forecast.count else { return T.nan }
	var sumSq = T.zero
	for i in actual.indices {
		let e = actual[i] - forecast[i]
		sumSq += e * e
	}
	return T.sqrt(sumSq / T(actual.count))
}
