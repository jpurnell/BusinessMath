//
//  Baselines.swift
//  BusinessMath
//
//  Step 2 of the Forecast Evaluation & Diagnostics tier.
//
//  Benchmark forecasters. Their whole purpose is to be *beaten*: a sophisticated model
//  is only worth its complexity if it improves on the naive line. They are also the
//  scaling denominator for MASE (mean absolute scaled error).
//

import Foundation
import Numerics

/// Generates `horizon` forecast periods immediately following `lastPeriod`.
private func forecastPeriods(after lastPeriod: Period, horizon: Int) -> [Period] {
    guard horizon > 0 else { return [] }
    return (1...horizon).map { lastPeriod.advanced(by: $0) }
}

// MARK: - Naive

/// Carries the last observed value forward for every horizon step (lag `h = 1`).
///
/// The simplest benchmark and the natural scale for non-seasonal MASE. On a random
/// walk it is the optimal forecast.
public struct NaiveForecaster<Value: Real & Sendable>: Forecaster {

    /// Creates a naive forecaster.
    public init() {}

    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value> {
        guard let lastValue = history.last, let lastPeriod = history.periods.last else {
            throw ForecastError.insufficientData(required: 1, got: history.count)
        }
        let periods = forecastPeriods(after: lastPeriod, horizon: horizon)
        let values = Array(repeating: lastValue, count: periods.count)
        return TimeSeries(periods: periods, values: values)
    }
}

// MARK: - Seasonal Naive

/// Repeats the most recent full season (lag `h = m`, where `m` is the season length).
///
/// The canonical benchmark for seasonal data — and frequently the line sophisticated
/// models fail to beat when seasonality is strong and stable. For horizons longer than
/// one season the last season is cycled.
public struct SeasonalNaiveForecaster<Value: Real & Sendable>: Forecaster {

    /// The number of periods in one seasonal cycle (`≥ 1`).
    public let seasonLength: Int

    /// Creates a seasonal-naive forecaster.
    ///
    /// - Parameter seasonLength: Periods in one season (e.g. 12 for monthly data).
    public init(seasonLength: Int) {
        self.seasonLength = seasonLength
    }

    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value> {
        guard seasonLength >= 1 else {
            throw ForecastError.invalidParameter("seasonLength must be ≥ 1")
        }
        let values = history.valuesArray
        guard values.count >= seasonLength, let lastPeriod = history.periods.last else {
            throw ForecastError.insufficientData(required: seasonLength, got: values.count)
        }
        let periods = forecastPeriods(after: lastPeriod, horizon: horizon)
        let seasonStart = values.count - seasonLength
        var forecastValues: [Value] = []
        forecastValues.reserveCapacity(periods.count)
        for h in 0..<periods.count {
            let offset = h % seasonLength
            forecastValues.append(values[seasonStart + offset])
        }
        return TimeSeries(periods: periods, values: forecastValues)
    }
}

// MARK: - Drift

/// Extends the straight line drawn through the first and last observations.
///
/// Equivalent to naive plus the average per-period change:
/// `ŷ(t+h) = yₙ + h · (yₙ − y₁) / (n − 1)`. On a flat series it reduces to naive.
public struct DriftForecaster<Value: Real & Sendable>: Forecaster {

    /// Creates a drift forecaster.
    public init() {}

    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value> {
        let values = history.valuesArray
        guard values.count >= 2,
              let first = values.first,
              let last = values.last,
              let lastPeriod = history.periods.last else {
            throw ForecastError.insufficientData(required: 2, got: values.count)
        }
        // slope = mean first difference = (last - first) / (n - 1); guarded n ≥ 2.
        let span = Value(values.count - 1)
        let slope = (last - first) / span
        let periods = forecastPeriods(after: lastPeriod, horizon: horizon)
        var forecastValues: [Value] = []
        forecastValues.reserveCapacity(periods.count)
        for h in 1...max(periods.count, 1) where !periods.isEmpty {
            let step = Value(h) * slope
            forecastValues.append(last + step)
        }
        return TimeSeries(periods: periods, values: forecastValues)
    }
}
