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
    func symmetricBand() throws {
        let r = report(residuals: [[-2, -1, 0, 1, 2]], horizon: 1)
        let ci = try r.empiricalIntervals(around: series([10]), confidenceLevel: 0.95)
        let lo = ci.lowerBound.valuesArray[0]
        let hi = ci.upperBound.valuesArray[0]
        #expect(abs((lo + hi) - 20.0) < 1e-9)   // symmetric about 10
        #expect(hi > lo)                          // positive width
    }

    @Test("Interval widens with forecast horizon when later-step errors are larger")
    func widensWithHorizon() throws {
        let r = report(residuals: [[-1, 0, 1], [-3, 0, 3]], horizon: 2)
        let ci = try r.empiricalIntervals(around: series([10, 10]), confidenceLevel: 0.95)
        let width0 = ci.upperBound.valuesArray[0] - ci.lowerBound.valuesArray[0]
        let width1 = ci.upperBound.valuesArray[1] - ci.lowerBound.valuesArray[1]
        #expect(width1 > width0)
    }

    @Test("Higher confidence level gives a wider interval")
    func higherConfidenceWider() throws {
        let r = report(residuals: [[-2, -1, 0, 1, 2]], horizon: 1)
        let narrow = try r.empiricalIntervals(around: series([10]), confidenceLevel: 0.80)
        let wide = try r.empiricalIntervals(around: series([10]), confidenceLevel: 0.99)
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
        let ci = try bt.empiricalIntervals(around: point, confidenceLevel: 0.90)
        #expect(ci.forecast.count == 3)
        for k in 0..<3 {
            #expect(ci.lowerBound.valuesArray[k] <= ci.upperBound.valuesArray[k])
        }
        #expect(abs(ci.confidenceLevel - 0.90) < 1e-9)
    }

    // MARK: - Calibration

    /// The property these intervals exist to have, and the one nothing here measured.
    ///
    /// The tests above check the *shape* of an interval — that it is symmetric about the
    /// point forecast, that it widens with horizon, that 99% is wider than 80%. Every one
    /// of those passes for an interval of the wrong size. A band twice too wide is
    /// symmetric, widens, and orders correctly by confidence level; it is simply not an
    /// 80% interval.
    ///
    /// Calibration is the claim the number 0.80 actually makes: **over repeated draws, the
    /// interval contains the truth about 80% of the time.** It is the same shape of gap as
    /// the antithetic standard-error defect — a reported uncertainty that nothing measures
    /// against realised spread.
    ///
    /// The construction here tests the interval machinery rather than any forecaster. The
    /// residual buckets are a seeded sample from a known distribution; the interval is
    /// built from their quantiles; and coverage is measured against *fresh* draws from the
    /// same distribution. If the quantile arithmetic is right, coverage lands on the
    /// nominal level to within sampling error.
    ///
    /// The bound is the binomial standard error, not a guess: with `n` fresh draws at a
    /// nominal level `p`, the standard error of the observed proportion is
    /// `sqrt(p(1-p)/n)`, and three of those is a 99.7% envelope. At n = 4000 and p = 0.8
    /// that is about 0.019, so the test allows roughly 0.781 to 0.819. A tolerance chosen
    /// by eye would either pass a miscalibrated interval or flake on a correct one.
    @Test("An 80% interval contains about 80% of fresh draws, within binomial error",
          arguments: [0.80, 0.90, 0.95])
    func intervalsAreCalibrated(nominal: Double) throws {
        var rng = DeterministicRNG(seed: 20260914)

        // The residual sample the interval is built from.
        let residualCount = 2_000
        var residuals: [Double] = []
        residuals.reserveCapacity(residualCount)
        for _ in 0..<(residualCount / 2) {
            let (a, b): (Double, Double) = boxMullerSeed(using: &rng)
            residuals.append(a)
            residuals.append(b)
        }

        let backtest = report(residuals: [residuals], horizon: 1)
        let interval = try backtest.empiricalIntervals(around: series([0.0]),
                                                       confidenceLevel: nominal)
        let lower: Double = interval.lowerBound.valuesArray[0]
        let upper: Double = interval.upperBound.valuesArray[0]
        #expect(upper > lower, "degenerate interval [\(lower), \(upper)]")

        // Fresh draws from the same distribution the residuals came from.
        let trials = 4_000
        var covered = 0
        for _ in 0..<(trials / 2) {
            let (a, b): (Double, Double) = boxMullerSeed(using: &rng)
            if a >= lower && a <= upper { covered += 1 }
            if b >= lower && b <= upper { covered += 1 }
        }

        let coverage: Double = Double(covered) / Double(trials)
        let standardError: Double = (nominal * (1.0 - nominal) / Double(trials)).squareRoot()
        let allowed: Double = 3.0 * standardError
        #expect(abs(coverage - nominal) < allowed,
                "nominal \(nominal), observed coverage \(coverage), allowed +/- \(allowed)")
    }
}
