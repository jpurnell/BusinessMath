//
//  BacktestReport.swift
//  BusinessMath
//
//  Step 4 of the Forecast Evaluation & Diagnostics tier.
//  Result and configuration types for rolling-origin (walk-forward) evaluation.
//

import Foundation
import Numerics

// MARK: - Configuration

/// How the training window grows across backtest folds.
public enum BacktestWindow: Sendable, Equatable {
    /// Training grows to include all data before each origin (`[0..<origin]`).
    case expanding
    /// Training is a fixed-length trailing window ending at each origin.
    case sliding(length: Int)
}

/// Configuration for a rolling-origin backtest.
public struct BacktestConfig: Sendable {

    /// Number of observations before the first forecast origin.
    public var initialTrainSize: Int
    /// Number of steps forecast at each origin (`h`, `≥ 1`).
    public var horizon: Int
    /// How many observations origins advance between folds (`≥ 1`).
    public var step: Int
    /// Expanding (default) or fixed-length sliding training window.
    public var window: BacktestWindow
    /// Season length for the report's MASE scale. `nil` ⇒ auto-detect via ACF,
    /// falling back to 1 (non-seasonal).
    public var seasonLength: Int?
    /// Refusal policy (R2). `.lenient` (default) always computes; `.strict` throws on a
    /// noise-like series before any fold runs.
    public var refusal: RefusalPolicy

    /// Creates a backtest configuration.
    public init(
        initialTrainSize: Int,
        horizon: Int,
        step: Int = 1,
        window: BacktestWindow = .expanding,
        seasonLength: Int? = nil,
        refusal: RefusalPolicy = .lenient
    ) {
        self.initialTrainSize = initialTrainSize
        self.horizon = horizon
        self.step = step
        self.window = window
        self.seasonLength = seasonLength
        self.refusal = refusal
    }
}

// MARK: - Errors

/// Errors thrown by the backtest harness.
public enum BacktestError: Error, Sendable {
    /// The series is too short for the requested `initialTrainSize + horizon`.
    case seriesTooShort(required: Int, got: Int)
    /// A configuration value was invalid (non-positive sizes, bad forecaster output).
    case invalidConfig(String)
    /// Refusal (R2): under a `.strict` refusal policy, the series' spectral entropy
    /// exceeded the threshold — it is indistinguishable from noise, so no forecast is
    /// produced rather than returning a plausible-but-wrong one.
    case unforecastableSeries(spectralEntropy: Double, threshold: Double)
}

/// How aggressively the backtest refuses low-signal series (R2 — Fail-Silent).
public enum RefusalPolicy: Sendable, Equatable {
    /// Never refuse — always compute metrics (default; backward-compatible).
    case lenient
    /// Throw ``BacktestError/unforecastableSeries(spectralEntropy:threshold:)`` when the
    /// series' normalized spectral entropy exceeds `maxSpectralEntropy` (0…1).
    case strict(maxSpectralEntropy: Double)
}

// MARK: - Results

/// One forecast origin's out-of-sample result.
public struct BacktestFold<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {
    /// Index into the original series of the first forecast period.
    public let originIndex: Int
    /// The true future values for this fold.
    public let actual: TimeSeries<T>
    /// The forecast produced from data strictly before `originIndex`.
    public let forecast: TimeSeries<T>
    /// Error metrics for this fold.
    public let errors: ForecastErrorMetrics<T>

    public init(originIndex: Int, actual: TimeSeries<T>, forecast: TimeSeries<T>, errors: ForecastErrorMetrics<T>) {
        self.originIndex = originIndex
        self.actual = actual
        self.forecast = forecast
        self.errors = errors
    }
}

/// The result of a rolling-origin backtest.
///
/// All error figures are **out-of-sample** — every forecast was produced from data
/// strictly before the values it is scored against.
public struct BacktestReport<T: Real & Sendable & Codable & BinaryFloatingPoint>: Sendable {
    /// One entry per forecast origin.
    public let folds: [BacktestFold<T>]
    /// Root mean squared error pooled across all folds and horizons.
    public let rmse: T
    /// Mean absolute error pooled across all folds and horizons.
    public let mae: T
    /// Mean absolute percentage error pooled across all folds and horizons.
    public let mape: T
    /// Mean absolute scaled error vs the (seasonal-)naive benchmark; `nil` when the
    /// scale is degenerate (constant series). `< 1` ⇒ the model beats naive.
    public let mase: T?
    /// Per-horizon-step residuals: index `h−1` holds every error made `h` steps ahead.
    /// Raw material for empirical prediction intervals (Step 7).
    public let residualsByHorizon: [[T]]

    /// The number of folds (forecast origins).
    public var foldCount: Int { folds.count }
    /// The forecast horizon used.
    public let horizon: Int

    public init(
        folds: [BacktestFold<T>],
        rmse: T, mae: T, mape: T, mase: T?,
        residualsByHorizon: [[T]],
        horizon: Int
    ) {
        self.folds = folds
        self.rmse = rmse
        self.mae = mae
        self.mape = mape
        self.mase = mase
        self.residualsByHorizon = residualsByHorizon
        self.horizon = horizon
    }
}
