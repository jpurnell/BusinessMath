//
//  ScaledError.swift
//  BusinessMath
//
//  Step 4 of the Forecast Evaluation & Diagnostics tier.
//  Mean Absolute Scaled Error (Hyndman & Koehler 2006) and the naive scaling factor.
//

import Foundation
import Numerics

/// Mean absolute (seasonal-)naive one-step difference of `values`: the MASE scale.
///
/// `scale = mean(|yₜ − yₜ₋ₘ|)` for `t ≥ m`. Returns `nil` when the series is too short
/// or the scale is zero (a constant / degenerate series), so callers never divide by a
/// meaningless denominator.
func naiveScale<T: BinaryFloatingPoint>(_ values: [T], seasonLength: Int) -> T? {
    let m = Swift.max(seasonLength, 1)
    guard values.count > m else { return nil }
    var sum = T.zero
    var count = 0
    for t in m..<values.count {
        let diff = values[t] - values[t - m]
        sum += abs(diff)
        count += 1
    }
    guard count > 0 else { return nil }
    let scale = sum / T(count)
    return scale > T.zero ? scale : nil
}

public extension TimeSeries where T: BinaryFloatingPoint & Codable {

    /// Mean Absolute Scaled Error of `forecast` against this series (the actuals).
    ///
    /// `MASE = MAE(actual, forecast) / mean(|yₜ − yₜ₋ₘ|)` on `training`. A value `< 1`
    /// means the forecast beats the (seasonal-)naive benchmark; `> 1` means it loses to it.
    ///
    /// - Parameters:
    ///   - forecast: The forecast to score (matched to actuals by period).
    ///   - training: The series the naive scale is computed from (usually the training data).
    ///   - seasonLength: `1` for the plain naive scale, or the season length for the
    ///     seasonal-naive scale. Pass `training.dominantSeasonLength(maxLag:) ?? 1` to
    ///     let the ACF suggest it.
    /// - Returns: The MASE, or `nil` if the naive scale is degenerate (constant training).
    func mase(
        against forecast: TimeSeries<T>,
        training: TimeSeries<T>,
        seasonLength: Int = 1
    ) -> T? {
        guard let scale = naiveScale(training.valuesArray, seasonLength: seasonLength) else {
            return nil
        }
        let numerator = self.forecastError(against: forecast).mae
        return numerator / scale
    }
}
