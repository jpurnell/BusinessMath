//
//  Forecaster.swift
//  BusinessMath
//
//  Step 1 of the Forecast Evaluation & Diagnostics tier.
//
//  Defines the single model-agnostic abstraction that lets one evaluation harness
//  (backtesting, baselines, empirical intervals, forecastability) drive every
//  forecaster — trend models, Holt-Winters, moving averages, and naive baselines —
//  through one uniform call.
//

import Foundation
import Numerics

// MARK: - ForecastRegressors (exogenous-readiness seam)

/// Optional exogenous regressors that accompany a forecast.
///
/// In the current release this is **always `nil`** — no shipped forecaster reads it.
/// It exists so that adding exogenous / driver-based forecasting (an "ARIMAX"-style
/// model) in a later phase requires **no** change to the ``Forecaster`` protocol or to
/// any existing call site. A future model would read ``historical`` (drivers aligned to
/// the training window) and ``future`` (drivers known ahead of time that span the
/// forecast horizon, e.g. calendar effects, planned promotions, published rates).
public struct ForecastRegressors<Value: Real & Sendable>: Sendable {

    /// Driver series aligned to the training history.
    public let historical: [TimeSeries<Value>]

    /// Driver series covering the forecast horizon (must be known ahead of time).
    public let future: [TimeSeries<Value>]

    /// Creates a set of exogenous regressors.
    ///
    /// - Parameters:
    ///   - historical: Driver series aligned to the training history.
    ///   - future: Driver series covering the forecast horizon.
    public init(historical: [TimeSeries<Value>], future: [TimeSeries<Value>]) {
        self.historical = historical
        self.future = future
    }
}

// MARK: - Forecaster

/// Anything that can be trained on history and produce an *h*-step-ahead forecast.
///
/// `Forecaster` is the keystone of the evaluation tier: because every model conforms to
/// it, a single backtesting harness can drive them all. Each call trains on a *fresh*
/// window, so conforming types must **not** carry state between calls.
///
/// Conformers implement the three-argument requirement; almost all callers use the
/// two-argument convenience overload (which forwards `exogenous: nil`).
///
/// ```swift
/// let forecast = try LinearTrend<Double>().trainedForecast(from: history, horizon: 12)
/// ```
public protocol Forecaster<Value>: Sendable {

    /// The numeric type the forecaster operates on.
    associatedtype Value: Real & Sendable

    /// Trains on `history` (optionally with exogenous drivers) and forecasts `horizon`
    /// periods immediately following the history.
    ///
    /// - Parameters:
    ///   - history: The training series.
    ///   - exogenous: Optional exogenous drivers. Univariate forecasters ignore this;
    ///     in the current release it is always `nil`.
    ///   - horizon: The number of future periods to forecast (`≥ 1`).
    /// - Returns: A forecast series of length `horizon` following `history`.
    /// - Throws: ``ForecastError`` on insufficient or invalid data.
    func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value>
}

public extension Forecaster {

    /// Univariate convenience: trains and forecasts without exogenous drivers.
    ///
    /// Forwards `exogenous: nil` to the primary requirement. This is the method the
    /// backtester and virtually all current callers use.
    ///
    /// - Parameters:
    ///   - history: The training series.
    ///   - horizon: The number of future periods to forecast (`≥ 1`).
    /// - Returns: A forecast series of length `horizon` following `history`.
    /// - Throws: ``ForecastError`` on insufficient or invalid data.
    func trainedForecast(
        from history: TimeSeries<Value>,
        horizon: Int
    ) throws -> TimeSeries<Value> {
        try trainedForecast(from: history, exogenous: nil, horizon: horizon)
    }
}

// MARK: - AnyForecaster (closure adapter)

/// A type-erased forecaster backed by a closure.
///
/// Wrap any `(history, horizon) -> forecast` function as a ``Forecaster`` without
/// declaring a new type — useful for ad-hoc models and tests.
public struct AnyForecaster<Value: Real & Sendable>: Forecaster {

    private let body: @Sendable (TimeSeries<Value>, ForecastRegressors<Value>?, Int) throws -> TimeSeries<Value>

    /// Wraps an exogenous-aware closure.
    ///
    /// - Parameter body: `(history, exogenous, horizon) -> forecast`.
    public init(
        _ body: @escaping @Sendable (TimeSeries<Value>, ForecastRegressors<Value>?, Int) throws -> TimeSeries<Value>
    ) {
        self.body = body
    }

    /// Wraps a univariate closure, ignoring any supplied exogenous input.
    ///
    /// - Parameter body: `(history, horizon) -> forecast`.
    public init(
        univariate body: @escaping @Sendable (TimeSeries<Value>, Int) throws -> TimeSeries<Value>
    ) {
        self.body = { history, _, horizon in try body(history, horizon) }
    }

    /// Trains on `history` and forecasts `horizon` steps via the wrapped closure.
    public func trainedForecast(
        from history: TimeSeries<Value>,
        exogenous: ForecastRegressors<Value>?,
        horizon: Int
    ) throws -> TimeSeries<Value> {
        try body(history, exogenous, horizon)
    }
}

// MARK: - Trend model conformances

private extension TrendModel {
    /// Shared fit-then-project implementation for the trend model family.
    func trendForecast(from history: TimeSeries<Value>, horizon: Int) throws -> TimeSeries<Value> {
        var model = self
        try model.fit(to: history)
        guard let forecast = try model.project(periods: horizon) else {
            throw ForecastError.modelNotTrained
        }
        return forecast
    }
}

extension LinearTrend: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        try trendForecast(from: history, horizon: horizon)
    }
}

extension ExponentialTrend: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        try trendForecast(from: history, horizon: horizon)
    }
}

extension LogisticTrend: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        try trendForecast(from: history, horizon: horizon)
    }
}

extension CustomTrend: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        try trendForecast(from: history, horizon: horizon)
    }
}

// MARK: - Holt-Winters & Moving-Average conformances

extension HoltWintersModel: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        try forecast(timeSeries: history, periods: horizon)
    }
}

extension MovingAverageModel: Forecaster {
    /// Trains on `history` and forecasts `horizon` steps. See ``Forecaster``.
    public func trainedForecast(from history: TimeSeries<T>, exogenous: ForecastRegressors<T>?, horizon: Int) throws -> TimeSeries<T> {
        var model = self
        try model.train(on: history)
        guard let forecast = model.predict(periods: horizon) else {
            throw ForecastError.modelNotTrained
        }
        return forecast
    }
}
