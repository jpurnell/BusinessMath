//
//  EmpiricalIntervalsTests.swift
//  BusinessMath
//
//  RED phase — Step 7 of the Forecast Evaluation & Diagnostics tier.
//  Prediction intervals from out-of-sample backtest residual quantiles — the honest
//  replacement for the in-sample parametric bands.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Empirical prediction intervals")
struct EmpiricalIntervalsTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        let start = Period.month(year: 2020, month: 1)
        return TimeSeries(periods: (0..<values.count).map { start.advanced(by: $0) }, values: values)
    }

    /// A report with hand-chosen residual buckets (folds not needed for interval math).
    private func report(residuals: [[Double]], horizon: Int) -> BacktestReport<Double> {
        BacktestReport(folds: [], rmse: 0, mae: 0, mape: 0, mase: nil,
                       residualsByHorizon: residuals, horizon: horizon)
    }

    @Test("Symmetric residuals produce a band symmetric about the point forecast")
    func symmetricBand() {
        let r = report(residuals: [[-2, -1, 0, 1, 2]], horizon: 1)
        let ci = r.empiricalIntervals(around: series([10]), confidenceLevel: 0.95)
        let lo = ci.lowerBound.valuesArray[0]
        let hi = ci.upperBound.valuesArray[0]
        #expect(abs((lo + hi) - 20.0) < 1e-9)   // symmetric about 10
        #expect(hi > lo)                          // positive width
    }

    @Test("Interval widens with forecast horizon when later-step errors are larger")
    func widensWithHorizon() {
        let r = report(residuals: [[-1, 0, 1], [-3, 0, 3]], horizon: 2)
        let ci = r.empiricalIntervals(around: series([10, 10]), confidenceLevel: 0.95)
        let width0 = ci.upperBound.valuesArray[0] - ci.lowerBound.valuesArray[0]
        let width1 = ci.upperBound.valuesArray[1] - ci.lowerBound.valuesArray[1]
        #expect(width1 > width0)
    }

    @Test("Higher confidence level gives a wider interval")
    func higherConfidenceWider() {
        let r = report(residuals: [[-2, -1, 0, 1, 2]], horizon: 1)
        let narrow = r.empiricalIntervals(around: series([10]), confidenceLevel: 0.80)
        let wide = r.empiricalIntervals(around: series([10]), confidenceLevel: 0.99)
        let wNarrow = narrow.upperBound.valuesArray[0] - narrow.lowerBound.valuesArray[0]
        let wWide = wide.upperBound.valuesArray[0] - wide.lowerBound.valuesArray[0]
        #expect(wWide > wNarrow)
    }

    @Test("End-to-end: intervals from a real backtest bound the point forecast order")
    func endToEnd() throws {
        let sine = series((0..<48).map { 10.0 * Foundation.sin(2.0 * .pi * Double($0) / 12.0) })
        let bt = try sine.backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 24, horizon: 3, step: 3))
        let point = try NaiveForecaster<Double>().trainedForecast(from: sine, horizon: 3)
        let ci = bt.empiricalIntervals(around: point, confidenceLevel: 0.90)
        #expect(ci.forecast.count == 3)
        for k in 0..<3 {
            #expect(ci.lowerBound.valuesArray[k] <= ci.upperBound.valuesArray[k])
        }
        #expect(ci.confidenceLevel == 0.90)
    }
}
