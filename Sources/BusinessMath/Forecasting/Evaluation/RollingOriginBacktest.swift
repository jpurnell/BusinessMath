//
//  RollingOriginBacktest.swift
//  BusinessMath
//
//  Step 4 of the Forecast Evaluation & Diagnostics tier.
//
//  Walk-forward (rolling-origin) out-of-sample evaluation. At each origin the forecaster
//  is trained on data strictly before the origin and scored against the true future —
//  the anti-leakage guarantee that makes the accuracy figures honest.
//

import Foundation
import Numerics

public extension TimeSeries where T: BinaryFloatingPoint & Codable {

    /// Evaluates a forecaster out-of-sample via rolling-origin cross-validation.
    ///
    /// For each origin `o` (starting at `initialTrainSize`, advancing by `step`), the
    /// forecaster is trained on the window ending at `o` and asked to forecast `horizon`
    /// steps; those forecasts are scored against the true values at `o..<o+horizon`.
    /// No value at or after an origin ever enters that fold's training window.
    ///
    /// - Parameters:
    ///   - forecaster: Any ``Forecaster`` over the same numeric type.
    ///   - config: Fold geometry (train size, horizon, step, window, season length).
    /// - Returns: A ``BacktestReport`` with per-fold and pooled out-of-sample errors.
    /// - Throws: ``BacktestError`` for invalid configuration or a too-short series;
    ///   rethrows any error the forecaster raises inside a fold (fails loudly rather
    ///   than silently dropping a fold).
    func backtest<F: Forecaster>(
        _ forecaster: F,
        config: BacktestConfig
    ) throws -> BacktestReport<T> where F.Value == T {

        let i0 = config.initialTrainSize
        let horizon = config.horizon
        let step = config.step
        let n = valuesArray.count

        guard i0 >= 1, horizon >= 1, step >= 1 else {
            throw BacktestError.invalidConfig("initialTrainSize, horizon, and step must be ≥ 1")
        }
        if case let .sliding(length) = config.window, length < 1 {
            throw BacktestError.invalidConfig("sliding window length must be ≥ 1")
        }
        guard n >= i0 + horizon else {
            throw BacktestError.seriesTooShort(required: i0 + horizon, got: n)
        }

        let allPeriods = periods
        let allValues = valuesArray

        func slice(_ range: Range<Int>) -> TimeSeries<T> {
            TimeSeries(periods: Array(allPeriods[range]), values: Array(allValues[range]))
        }

        var folds: [BacktestFold<T>] = []
        var residualsByHorizon = [[T]](repeating: [], count: horizon)
        var pooledActual: [T] = []
        var pooledForecast: [T] = []

        var origin = i0
        while origin + horizon <= n {
            let trainStart: Int
            switch config.window {
            case .expanding:
                trainStart = 0
            case .sliding(let length):
                trainStart = Swift.max(0, origin - length)
            }

            let training = slice(trainStart..<origin)
            let forecastSeries = try forecaster.trainedForecast(from: training, horizon: horizon)
            let actualSeries = slice(origin..<(origin + horizon))

            let forecastValues = forecastSeries.valuesArray
            let actualValues = actualSeries.valuesArray
            guard forecastValues.count == horizon else {
                throw BacktestError.invalidConfig(
                    "forecaster returned \(forecastValues.count) values, expected \(horizon)")
            }

            for k in 0..<horizon {
                let residual = actualValues[k] - forecastValues[k]
                residualsByHorizon[k].append(residual)
            }
            pooledActual.append(contentsOf: actualValues)
            pooledForecast.append(contentsOf: forecastValues)

            let foldMape = mape(actualValues, forecastValues)
            let errors = ForecastErrorMetrics(
                rmse: rmse(actualValues, forecastValues),
                mae: mae(actualValues, forecastValues),
                mape: foldMape.isNaN ? T.zero : foldMape,
                count: horizon)
            folds.append(BacktestFold(
                originIndex: origin, actual: actualSeries, forecast: forecastSeries, errors: errors))

            origin += step
        }

        // Pooled out-of-sample aggregates.
        let aggMape = mape(pooledActual, pooledForecast)
        let aggregateMAE = mae(pooledActual, pooledForecast)

        // Resolve the season length (explicit, else ACF-suggested, else non-seasonal).
        let resolvedSeason = config.seasonLength ?? autoSeasonLength(n: n) ?? 1
        let scale = naiveScale(allValues, seasonLength: resolvedSeason)
        let maseValue: T?
        if let scale, scale > T.zero, !pooledActual.isEmpty {
            maseValue = aggregateMAE / scale
        } else {
            maseValue = nil
        }

        return BacktestReport(
            folds: folds,
            rmse: rmse(pooledActual, pooledForecast),
            mae: aggregateMAE,
            mape: aggMape.isNaN ? T.zero : aggMape,
            mase: maseValue,
            residualsByHorizon: residualsByHorizon,
            horizon: horizon)
    }

    /// ACF-suggested season length for MASE when the caller didn't specify one.
    private func autoSeasonLength(n: Int) -> Int? {
        let maxLag = Swift.min(Swift.max(n / 2, 2), n - 1)
        return dominantSeasonLength(maxLag: maxLag)
    }
}
