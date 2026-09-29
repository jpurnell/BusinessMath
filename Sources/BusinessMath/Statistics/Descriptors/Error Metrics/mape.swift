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
///
/// - Important: The `NaN` is the answer, not a placeholder to be tidied away. A caller that
///   rewrites it — `mapeValue.isNaN ? 0 : mapeValue` — turns "there was nothing to score"
///   into a **perfect** score on the library's most-compared ranking key. That rewrite
///   existed in ``TimeSeries/forecastError(against:)`` and has been removed.
public func mape<T: Real>(_ actual: [T], _ forecast: [T]) -> T {
	guard !actual.isEmpty, actual.count == forecast.count else { return T.nan }
	var sum = T.zero
	var count = 0
	for i in actual.indices {
		// A `nan` actual is deliberately *not* skipped here: `nan != 0` is true, so it enters
		// the sum and the result is `nan`. Skipping it would score the forecast on whichever
		// periods happened to survive and report that as the series' percentage error.
		guard actual[i] != T.zero else { continue }
		sum += abs((actual[i] - forecast[i]) / actual[i])
		count += 1
	}
	// Every actual was zero, so MAPE's domain is empty. Returning `0` here would be a claim
	// of perfect accuracy about a series no percentage error can be expressed against.
	guard count > 0 else { return T.nan }
	return sum / T(count)
}
