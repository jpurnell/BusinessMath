//
//  EmpiricalIntervals.swift
//  BusinessMath
//
//  Step 7 of the Forecast Evaluation & Diagnostics tier.
//
//  Prediction intervals built from the empirical distribution of out-of-sample backtest
//  residuals at each horizon step. Unlike the parametric in-sample bands on the models,
//  these widen with horizon *as the data actually did out-of-sample* — capturing the
//  regime-shift risk that in-sample residuals hide.
//

import Foundation
import Numerics

public extension BacktestReport {

    /// Builds prediction intervals around a point forecast from the backtest's
    /// out-of-sample residual quantiles.
    ///
    /// For horizon step `k`, the interval is
    /// `[point + Q(α/2), point + Q(1−α/2)]`, where `Q` is the empirical quantile of the
    /// residuals made `k` steps ahead during the backtest and `α = 1 − confidenceLevel`.
    /// Residuals are `actual − forecast`, so adding their quantiles to the point forecast
    /// reconstructs the empirical distribution of the actuals.
    ///
    /// - Parameters:
    ///   - pointForecast: The forecast to bracket (its length drives the output length).
    ///   - confidenceLevel: The interval coverage (e.g. `0.95`), clamped to `[0, 1]`.
    /// - Returns: A ``ForecastWithConfidence`` with empirical lower/upper bounds. Horizon
    ///   steps with no residuals fall back to a zero-width band at the point forecast.
    /// - Throws: rethrows if the empirical quantile estimator rejects a residual sample.
    func empiricalIntervals(
        around pointForecast: TimeSeries<T>,
        confidenceLevel: T
    ) throws -> ForecastWithConfidence<T> {
        let clamped = Swift.min(Swift.max(Double(confidenceLevel), 0.0), 1.0)
        let alphaLow = (1.0 - clamped) / 2.0
        let alphaHigh = 1.0 - alphaLow

        let periods = pointForecast.periods
        let points = pointForecast.valuesArray
        var lowerValues: [T] = []
        var upperValues: [T] = []
        lowerValues.reserveCapacity(points.count)
        upperValues.reserveCapacity(points.count)

        for k in 0..<points.count {
            let point = points[k]
            let bucket = residualBucket(forStep: k)
            guard !bucket.isEmpty else {
                lowerValues.append(point)
                upperValues.append(point)
                continue
            }
            let samples = bucket.map { Double($0) }
            let percentiles = try Percentiles(values: samples)
            let low = T(percentiles.percentile(alphaLow))
            let high = T(percentiles.percentile(alphaHigh))
            lowerValues.append(point + low)
            upperValues.append(point + high)
        }

        return ForecastWithConfidence(
            forecast: pointForecast,
            lowerBound: TimeSeries(periods: periods, values: lowerValues),
            upperBound: TimeSeries(periods: periods, values: upperValues),
            confidenceLevel: confidenceLevel)
    }

    /// Residuals for horizon step `k`, falling back to the last available bucket when a
    /// point forecast extends beyond the backtested horizon.
    private func residualBucket(forStep k: Int) -> [T] {
        if k < residualsByHorizon.count { return residualsByHorizon[k] }
        return residualsByHorizon.last ?? []
    }
}
