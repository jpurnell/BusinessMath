//
//  RollingOriginBacktestTests.swift
//  BusinessMath
//
//  RED phase — Step 4 of the Forecast Evaluation & Diagnostics tier.
//  Walk-forward (rolling-origin) out-of-sample evaluation + MASE.
//
//  Reference truth: FPP3 §5.10 (time-series cross-validation), Hyndman & Koehler (2006)
//  for MASE. Leakage is proven observably (see the value assertions below).
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Rolling-origin backtest & MASE")
struct RollingOriginBacktestTests {

    /// Monthly series where value == index (0,1,2,…) — makes leakage observable.
    private func indexSeries(_ n: Int) -> TimeSeries<Double> {
        let periods = (0..<n).map { Period.month(year: 2025, month: 1 + $0) }
        return TimeSeries(periods: periods, values: (0..<n).map(Double.init))
    }
    private func monthly(_ values: [Double]) -> TimeSeries<Double> {
        TimeSeries(periods: (0..<values.count).map { Period.month(year: 2025, month: 1 + $0) }, values: values)
    }

    // MARK: - Fold mechanics

    @Test("Fold count matches (n − initialTrainSize − horizon)/step + 1")
    func foldCount() throws {
        // n=10, i0=5, h=2, step=1 → origins 5,6,7,8 → 4 folds
        let report = try indexSeries(10).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 5, horizon: 2, step: 1))
        #expect(report.foldCount == 4)
        #expect(report.folds.count == 4)
    }

    @Test("Step > 1 spaces the origins")
    func stepSpacing() throws {
        // n=12, i0=4, h=2, step=3 → origins 4,7,10 → 3 folds (10+2<=12)
        let report = try indexSeries(12).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 4, horizon: 2, step: 3))
        #expect(report.folds.map(\.originIndex) == [4, 7, 10])
    }

    // MARK: - Leakage guarantee (observable)

    @Test("No future data leaks into training (naive forecasts last TRAIN value)")
    func noLeakage() throws {
        // value==index; naive at origin o must forecast o-1, never o.
        let report = try indexSeries(10).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 5, horizon: 1, step: 1))
        for fold in report.folds {
            #expect(fold.forecast.valuesArray[0] == Double(fold.originIndex - 1))
            #expect(fold.actual.valuesArray[0] == Double(fold.originIndex))
        }
    }

    @Test("Expanding vs sliding windows differ in training length")
    func windowTypes() throws {
        // Forecaster that reports its training length as the forecast value.
        let lengthReporter = AnyForecaster<Double>(univariate: { history, horizon in
            let lp = history.periods.last ?? Period.month(year: 2025, month: 1)
            return TimeSeries(periods: (1...horizon).map { lp.advanced(by: $0) },
                              values: Array(repeating: Double(history.count), count: horizon))
        })
        let expanding = try indexSeries(10).backtest(
            lengthReporter, config: BacktestConfig(initialTrainSize: 3, horizon: 1, step: 1, window: .expanding))
        // expanding training length at origin o == o
        for fold in expanding.folds {
            #expect(fold.forecast.valuesArray[0] == Double(fold.originIndex))
        }
        let sliding = try indexSeries(10).backtest(
            lengthReporter, config: BacktestConfig(initialTrainSize: 3, horizon: 1, step: 1, window: .sliding(length: 2)))
        // sliding training length is fixed at 2 (clamped to origin)
        for fold in sliding.folds {
            #expect(abs(fold.forecast.valuesArray[0] - 2.0) < 1e-9)
        }
    }

    // MARK: - Aggregate errors (out-of-sample)

    @Test("Aggregate MAE/RMSE pool out-of-sample errors across folds")
    func aggregateErrors() throws {
        // Naive on a perfect +1 ramp: at each origin forecasts o-1, actual o → error 1 always.
        let report = try indexSeries(8).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 4, horizon: 1, step: 1))
        #expect(abs(report.mae - 1.0) < 1e-9)
        #expect(abs(report.rmse - 1.0) < 1e-9)
    }

    @Test("residualsByHorizon has one bucket per horizon step")
    func residualBuckets() throws {
        let report = try indexSeries(10).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 5, horizon: 3, step: 1))
        #expect(report.residualsByHorizon.count == 3)
        // Each horizon bucket has one residual per fold.
        for bucket in report.residualsByHorizon {
            #expect(bucket.count == report.foldCount)
        }
    }

    // MARK: - MASE (standalone)

    @Test("MASE == numeratorMAE / naiveScale")
    func maseValue() throws {
        // actual [10,12,14], forecast [11,11,11] → abs errors [1,1,3], MAE=5/3
        // training [2,4,6,8] seasonLength 1 → scale mean|Δ| = 2 → MASE = (5/3)/2 ≈ 0.8333
        let actual = monthly([10, 12, 14])
        let forecast = monthly([11, 11, 11])
        let training = monthly([2, 4, 6, 8])
        let value = try #require(actual.mase(against: forecast, training: training, seasonLength: 1))
        #expect(abs(value - (5.0 / 3.0) / 2.0) < 1e-9)
    }

    @Test("MASE == 1 when error magnitude equals the naive scale")
    func maseUnity() {
        let actual = monthly([10, 20])
        let forecast = monthly([11, 21])          // errors [1,1] → MAE 1
        let training = monthly([1, 2, 3, 4])      // scale mean|Δ| = 1
        #expect(abs(actual.mase(against: forecast, training: training, seasonLength: 1)! - 1.0) < 1e-9)
    }

    @Test("MASE is nil when the naive scale is zero (constant training)")
    func maseConstantTraining() {
        let actual = monthly([10, 20])
        let forecast = monthly([11, 21])
        let training = monthly([5, 5, 5, 5])      // scale 0
        #expect(actual.mase(against: forecast, training: training, seasonLength: 1) == nil)
    }

    @Test("Backtest reports a MASE using the (auto/explicit) season length")
    func reportMASE() throws {
        let report = try indexSeries(8).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 4, horizon: 1, step: 1, seasonLength: 1))
        // ramp: naive error 1 each step; naive scale of full ramp = 1 → MASE 1
        let value = try #require(report.mase)
        #expect(abs(value - 1.0) < 1e-9)
    }

    // MARK: - Validation

    @Test("Series too short throws")
    func tooShort() {
        #expect(throws: BacktestError.self) {
            _ = try self.indexSeries(4).backtest(
                NaiveForecaster<Double>(),
                config: BacktestConfig(initialTrainSize: 5, horizon: 2, step: 1))
        }
    }

    @Test("Invalid config throws")
    func invalidConfig() {
        #expect(throws: BacktestError.self) {
            _ = try self.indexSeries(10).backtest(
                NaiveForecaster<Double>(),
                config: BacktestConfig(initialTrainSize: 5, horizon: 0, step: 1))
        }
    }
}
