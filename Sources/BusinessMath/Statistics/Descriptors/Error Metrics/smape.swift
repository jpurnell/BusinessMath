//
//  smape.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-09-09.
//

import Foundation
import Numerics

/// Symmetric Mean Absolute Percentage Error — forecast error measured against the average
/// magnitude of the actual and the forecast, rather than against the actual alone.
///
/// Calculated as `mean(|actual − forecast| / ((|actual| + |forecast|) / 2))`. The result is
/// a ratio (0.05 = 5%), not a percentage. Unlike ``mape(_:_:)`` it stays finite when an
/// actual is zero, and it is symmetric in its arguments — swapping them leaves the result
/// unchanged, which is the property that names it.
///
/// ## The halved denominator
///
/// Two conventions are in circulation. This one halves the denominator, which puts the
/// result in `[0, 2]`; the other divides by `|actual| + |forecast|` and is bounded by `1`.
/// **This library uses the halved form because that is what Excel uses**, measured rather
/// than chosen: `FORECAST.ETS.STAT` with `statistic_type` 5 returned `1.94306435` on an
/// alternating `+1, −1` series, and the unhalved form cannot exceed `1` by the triangle
/// inequality.
///
/// ## Terms where both values are zero
///
/// A term whose actual *and* forecast are both zero contributes **zero**, not `NaN`: a
/// forecast that predicted nothing and got nothing was not wrong. It still counts toward
/// the mean, so a wholly zero pair of series scores `0`.
///
/// ```swift
/// let actual = [100.0, 0.0, 300.0]
/// let forecast = [110.0, 0.0, 270.0]
/// let error = smape(actual, forecast)   // ≈ 0.0668
/// print(error)
/// ```
///
/// - Parameters:
///   - actual: Observed values.
///   - forecast: Predicted values. Must have the same count as `actual`.
/// - Returns: The SMAPE as a ratio in `[0, 2]`, or `NaN` if the arrays are empty or
///   mismatched in length.
public func smape<T: Real>(_ actual: [T], _ forecast: [T]) -> T {
	guard !actual.isEmpty, actual.count == forecast.count else { return T.nan }
	let two = T(2)
	var sum = T.zero
	for i in actual.indices {
		// The divisor is bound and guarded as a symbol rather than through its operands,
		// because that is what the fp-safety checker tracks — and because the guard is
		// doing real work here: `magnitude == 0` is the both-zero term, which is a
		// meaningful zero contribution rather than an excluded observation.
		let magnitude: T = abs(actual[i]) + abs(forecast[i])
		guard magnitude > T.zero else { continue }
		// `2·|a − f| / (|a| + |f|)` rather than `|a − f| / ((|a| + |f|) / 2)`: one
		// division instead of two, and exactly the same value.
		let deviation: T = abs(actual[i] - forecast[i])
		let numerator: T = two * deviation
		sum += numerator / magnitude
	}
	let count: T = T(actual.count)
	guard count > T.zero else { return T.nan }
	return sum / count
}
